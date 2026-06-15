# stack-S3

S3 replication demo: a primary bucket in `us-east-1` that replicates to **two** destinations simultaneously — a same-account bucket in `us-east-2` (cross-region) and a separate-account bucket (cross-account). Each concern lives in its own file.

---

## Architecture Overview

```
us-east-1 (primary account)
├── Main bucket              ← primary storage, object-locked, versioned
└── Logging bucket           ← receives S3 server access logs from main bucket

us-east-2 (primary account, alias provider)
└── Region replica bucket    ← cross-region replication target

us-east-1 (replica account, alias provider)
└── Account replica bucket   ← cross-account replication target
```

All encryption is SSE-S3 (AES256). Replication runs as two parallel rules off the same source bucket.

Bucket naming: `tf-{RUNNER}-{ORGANIZATION}-{bucket_usage}-bucket` for the main bucket, with `tf-replica-...` prefixes on the destinations.

---

## Providers ([provider.tf](../provider.tf))

Three AWS providers, all assuming an IAM role:

| Alias | Region | Account | Used for |
|---|---|---|---|
| (default) | `us-east-1` | `ACCOUNT_ID` | Main bucket, logging bucket, IAM, replication config |
| `aws.us-east-2` | `us-east-2` | `ACCOUNT_ID` | Cross-region replica bucket |
| `aws.test-account` | `us-east-1` | `REPLICA_ACCOUNT_ID` | Cross-account replica bucket |

Default tags are applied at the provider level so every resource inherits `ManagedBy`, `Environment`, `CreatedBy`, and `Organization` without per-resource boilerplate.

---

## Buckets

### Main Bucket ([main.tf](../main.tf))

The primary storage bucket. `object_lock_enabled = true` is set at creation — this can only be enabled at bucket creation time, not after. It's the prerequisite for the GOVERNANCE retention policy in [security.tf](../security.tf).

### Logging Bucket ([main.tf](../main.tf))

A dedicated bucket for S3 server access logs. Keeping logs in a separate bucket means log writes don't appear in the logs themselves, and the logging bucket can have its own independent access controls.

### Region Replica Bucket ([replica_region.tf](../replica_region.tf))

Lives in `us-east-2` under the same account. Has versioning enabled (required for replication) and the same public-access block as the main bucket. No bucket policy needed — same-account replication uses the source's IAM role permissions.

### Account Replica Bucket ([replica_account.tf](../replica_account.tf))

Lives in a separate AWS account. Has versioning, SSE-S3 encryption, and a public-access block. Unlike the region replica, this bucket **does** need a bucket policy granting the source account's replication role write permissions — cross-account access requires an explicit grant on the destination side.

---

## Security Controls ([security.tf](../security.tf))

### Public Access Block

All four flags are `true`:

| Setting | What it prevents |
|---|---|
| `block_public_acls` | ACLs that make objects or buckets publicly readable |
| `block_public_policy` | Bucket policies that allow public access |
| `ignore_public_acls` | Ignores any public ACLs already on the bucket |
| `restrict_public_buckets` | Blocks all public/cross-account access via policy unless from authorized AWS principals |

These act as a safety net on top of bucket policies and ACLs.

### Versioning

Every write creates a new version rather than overwriting. Required for cross-region/cross-account replication and for object lock.

### Object Lock — GOVERNANCE Mode (5 days)

Objects cannot be deleted or overwritten for 5 days. GOVERNANCE mode lets users with the `s3:BypassGovernanceRetention` permission override it — useful for demo workflows where you may need to clean up. COMPLIANCE mode (not used here) is absolute and cannot be overridden by anyone, including root.

---

## Encryption

No customer-managed KMS keys. All buckets use SSE-S3 (AES256):
- The main bucket relies on the **default SSE-S3** that AWS automatically applies to every new bucket (since January 2023).
- The two replica buckets declare `aws_s3_bucket_server_side_encryption_configuration` with `sse_algorithm = "AES256"` explicitly.

This choice keeps replication simple: no per-region/per-account KMS keys to provision, no `kms:Decrypt`/`kms:GenerateDataKey` grants on the replication IAM role, no `source_selection_criteria` or `encryption_configuration` blocks in the replication config.

---

## Lifecycle Management ([lifecycle.tf](../lifecycle.tf))

Two rules on the main bucket:

1. **Glacier transition at 30 days** — Objects are moved to S3 Glacier after 30 days. Cheaper for cold storage; retrieval takes minutes to hours.
2. **Noncurrent version expiry at 90 days** — With versioning on, deleted or overwritten objects become "noncurrent" rather than disappearing. This rule permanently removes noncurrent versions after 90 days to prevent unbounded storage growth.

---

## Access Logging ([logging.tf](../logging.tf))

S3 server access logging writes a record of every request to the main bucket into the logging bucket under the `log/` prefix. Records include requester, operation, object key, response status, and bytes transferred.

`partition_date_source = "EventTime"` organizes logs by the actual event timestamp rather than delivery time — more accurate for time-range queries.

---

## Bucket Policies ([policies.tf](../policies.tf))

Only one bucket policy lives here now: the logging bucket grants `logging.s3.amazonaws.com` write access, scoped to the current account via the `aws:SourceAccount` condition. This prevents log delivery from any other account being accepted.

The main bucket has **no** bucket policy — the IAM role assumed by the provider already has the access it needs, and the public-access block guarantees nothing leaks.

---

## Replication

Three files implement replication: the IAM role and rules ([replication.tf](../replication.tf)), the destination bucket in `us-east-2` ([replica_region.tf](../replica_region.tf)), and the destination bucket in a separate account ([replica_account.tf](../replica_account.tf)).

### IAM Role ([replication.tf](../replication.tf))

A single role (`{ORGANIZATION}-s3-replication-role`) trusted by `s3.amazonaws.com`, with a three-statement policy:

| Statement | Purpose |
|---|---|
| `AllowSourceBucketRead` | List the source bucket and read its replication config |
| `AllowSourceObjectRead` | Read versioned object data, ACLs, tags, retention, and legal-hold metadata |
| `AllowReplicaWrite` | Write to both replica buckets, including delete markers, tags, and ownership override |

No KMS statements — the destinations use SSE-S3, so the replication role doesn't need to touch KMS at all.

### Rule 1: Cross-Region (same account)

Replicates to `region_replication_bucket` in `us-east-2`. Same account, so no `account` field, no `access_control_translation`, no destination bucket policy.

### Rule 2: Cross-Account (different account, same region)

Replicates to `account_replication_bucket` in `REPLICA_ACCOUNT_ID`. Two cross-account extras are required:

- `account = var.REPLICA_ACCOUNT_ID` — tells S3 the destination is in a different account
- `access_control_translation { owner = "Destination" }` — flips object ownership to the destination account on replication. Without this, replicated objects retain the source account as owner and the destination account can't manage them

Both rules have `delete_marker_replication` enabled so deletions in the source are mirrored to the destinations.

---

## Variables ([vars.tf](../vars.tf), [terraform.tfvars](../terraform.tfvars))

| Variable | Default | Notes |
|---|---|---|
| `ACCOUNT_ID` | — | Required. Primary account ID — the provider assumes a role here. |
| `REPLICA_ACCOUNT_ID` | — | Required. Account where the cross-account replica lives. |
| `AWS_REGION` | `us-east-1` | Primary region. |
| `REPLICA_ROLE_NAME` | `Engineer` | IAM role assumed in the replica account. |
| `ROLE_NAME` | — | Required. IAM role assumed in the primary account. |
| `RUNNER` | — | Required. Used in bucket naming. |
| `ORGANIZATION` | — | Required. Used in bucket naming and the IAM role name. |
| `bucket_usage` | `general` | Appended to the main and replica bucket names. |
| `ENVIRONMENT` | `Development` | Default tag. |
| `ManagedBy` | `terraform` | Default tag. |

---

## Caveats

- `force_destroy = true` on every bucket. Intentional for the demo — `terraform destroy` will wipe non-empty buckets. Remove this on any bucket holding data you can't lose.
- Cross-account replication assumes the role `arn:aws:iam::${REPLICA_ACCOUNT_ID}:role/${REPLICA_ROLE_NAME}` already exists in the destination account and trusts the principal running Terraform. There's no IAM setup for the destination account in this stack.
- Object Lock with GOVERNANCE provides soft deletion protection. For real immutability (compliance, legal hold), switch to COMPLIANCE mode and extend the retention period.
