# stack-S3

This stack provisions a production-grade S3 setup across two AWS accounts and two regions. It goes well beyond a basic bucket — encryption, access controls, versioning, lifecycle management, event notifications, cross-account replication, access logging, and CloudTrail audit trails are all configured here. Each concern lives in its own file rather than one monolithic config.

---

## Architecture Overview

```
us-east-1 (primary account)
├── Main bucket              ← primary storage, KMS encrypted, object locked
├── Logging bucket           ← receives access logs from main bucket
├── CloudTrail logs bucket   ← stores object-level audit events
└── SNS Topic                ← publishes on any ObjectCreated event

us-east-2 (replica account)
└── Replica bucket           ← cross-account replication target, separate KMS key
```

All bucket names follow the convention:
`tf-{ROLE_NAME}-{RUNNER}-{ORGANIZATION}-{purpose}-bucket`

---

## Buckets

### Main Bucket (`main.tf`)

The primary storage bucket. Object lock is enabled at bucket creation — this cannot be added after the fact, which is why it's set in the `aws_s3_bucket` resource itself rather than a separate configuration block. Object lock is the prerequisite for the GOVERNANCE retention policy configured in `security.tf`.

### Logging Bucket

A dedicated bucket for S3 server access logs. Keeping logs in a separate bucket means the log writes themselves don't appear in the logs, and the logging bucket can have its own independent lifecycle and access controls.

### Notification Bucket

Created to serve as a secondary event target. The actual event notification (to SNS) is configured off the main bucket — this bucket exists as a scoped receiver for any notification-related objects.

### CloudTrail Logs Bucket (`cloudtrail.tf`)

A dedicated bucket for CloudTrail to write audit events into. The bucket policy explicitly grants the CloudTrail service principal:
- `s3:GetBucketAcl` — CloudTrail checks ACL before writing
- `s3:PutObject` — restricted to the `AWSLogs/{account_id}/*` path with `bucket-owner-full-control` ACL condition

The ACL condition ensures the account that owns the bucket retains full control over every log file written, even if CloudTrail were to write from a different context.

---

## Encryption (`encryption.tf`)

Every object in the main bucket is encrypted at rest using AWS KMS with a customer-managed key (CMK).

- **10-day deletion window**: If the key is scheduled for deletion, there's a 10-day grace period to cancel it. KMS keys can't be immediately deleted.
- **Key rotation enabled**: AWS automatically rotates the underlying key material annually. The key ID and alias stay the same — existing objects remain readable.
- **`bucket_key_enabled = true`**: Reduces KMS API calls (and therefore cost) by generating a bucket-level data key that's used to encrypt individual objects, rather than calling KMS per-object.

The KMS alias is `alias/{RUNNER}-{ORGANIZATION}-bucket-key`, which gives you a human-readable reference to the key without needing to track the raw key ID.

The replica bucket in `us-east-2` has its own separate KMS key — cross-region replication requires the destination key to live in the destination region.

---

## Security Controls (`security.tf`)

### Public Access Block

All four public access controls are set to `true`:

| Setting | What it prevents |
|---|---|
| `block_public_acls` | ACLs that make objects or buckets publicly readable |
| `block_public_policy` | Bucket policies that allow public access |
| `ignore_public_acls` | Ignores any public ACLs already on the bucket |
| `restrict_public_buckets` | Restricts access to only AWS services and authorized accounts |

These settings exist independently of bucket policies and ACLs — they act as a safety net that takes precedence.

### Versioning

Every write creates a new version rather than overwriting. This gives you point-in-time recovery and is also a prerequisite for cross-region replication and object lock.

### Object Lock — GOVERNANCE Mode (5 days)

Objects cannot be deleted or overwritten for the default retention period of 5 days. GOVERNANCE mode is less strict than COMPLIANCE mode — users with the `s3:BypassGovernanceRetention` permission can override it. COMPLIANCE mode, by contrast, is absolute: no one can delete a locked object, including root.

This is a reasonable setting for a non-regulated workload where you want deletion protection but still need an emergency override path.

---

## Lifecycle Management (`lifecycle.tf`)

Two rules run on the main bucket:

1. **Glacier transition at 30 days** — Objects are moved to S3 Glacier after 30 days. Glacier is significantly cheaper for data you rarely access. Retrieval takes minutes to hours, so only move data here if you can tolerate that latency.

2. **Noncurrent version expiry at 90 days** — With versioning on, deleted or overwritten objects become "noncurrent" rather than disappearing. This rule permanently removes noncurrent versions after 90 days, preventing unbounded storage growth.

---

## Access Logging (`logging.tf`)

Server access logging writes a record of every request made to the main bucket into the logging bucket under the `log/` prefix. Logs include the requester, operation, object key, response status, and bytes transferred.

The `EventTime` partition date source means logs are organized by the actual event timestamp rather than when they were delivered — more accurate for querying by time range.

---

## Event Notifications (`notifications.tf`)

An SNS topic (`s3-event-notification-topic`) receives a message whenever any object is created in the main bucket (`s3:ObjectCreated:*` covers PUT, POST, COPY, and multipart upload completion).

The SNS topic policy restricts publishers to the S3 service, and only allows publishes that originate from the main bucket's ARN — this prevents other S3 buckets from publishing to the same topic unintentionally.

Downstream consumers (Lambda, SQS, HTTP endpoints) can subscribe to this topic to act on new objects.

---

## Static Object Uploads (`objects.tf`)

Four static files are uploaded from the local `assets/` directory at apply time:

| Path | Content Type |
|---|---|
| `index.html` | `text/html` |
| `error.html` | `text/html` |
| `config/app-config.json` | `application/json` |
| `data/reference.csv` | `text/csv` |

`source_hash = filemd5(...)` triggers a re-upload when the local file content changes, which is how Terraform detects object drift without relying on ETags. ETags are disabled here because KMS-encrypted objects use a different checksum algorithm than the MD5 that ETags expect — comparing them would always show a diff.

---

## Cross-Account Replication (`replica.tf`)

Objects in the main bucket are replicated to a bucket in a separate AWS account (`REPLICA_ACCOUNT_ID`) in `us-east-2`.

**Replication requires:**
- Versioning enabled on both source and destination (handled in `security.tf` and `replica.tf`)
- An IAM role that S3 can assume to perform the copy
- KMS permissions to decrypt the source object and re-encrypt at the destination

The IAM role (`{ORGANIZATION}-s3-replication-role`) has a scoped policy with five distinct permission sets:

| Statement | Purpose |
|---|---|
| `AllowSourceBucketRead` | Read replication config and list the source bucket |
| `AllowSourceObjectRead` | Read versioned object data, ACL, and tags |
| `AllowReplicaWrite` | Write replicated objects and tags to the replica bucket |
| `AllowSourceKMSDecrypt` | Decrypt source objects using the primary KMS key |
| `AllowReplicaKMSEncrypt` | Re-encrypt at destination using the replica KMS key |

**Access control translation** (`owner = "Destination"`) overrides the object owner to the destination account. Without this, objects replicated cross-account retain the source account as owner, which means the destination account can't manage them.

The replica bucket has the same public access block configuration as the main bucket.

---

## CloudTrail Audit Logging (`cloudtrail.tf`)

A CloudTrail trail named `s3-object-level-trail` records data events on the main bucket. Unlike management events (which track API calls like `CreateBucket` or `PutBucketPolicy`), data events track individual object operations.

The advanced event selector captures:
- `GetObject` — who read what, and when
- `PutObject` — who wrote what
- `DeleteObject` — who deleted what

Scope is limited to `aws_s3_bucket.bucket.arn/*` — only objects in the main bucket are logged, not the logging or CloudTrail buckets themselves (which would create recursive noise).

**`is_multi_region_trail = true`**: The trail captures events across all regions, not just `us-east-1`. This matters if the same AWS account has S3 activity in other regions.

**`enable_log_file_validation = true`**: CloudTrail generates a digest file for each log batch and signs it. You can use the AWS CLI to verify whether log files were modified or deleted after delivery — useful for forensic integrity.

---

## Outputs

| Output | Value |
|---|---|
| `bucket_id` | Name of the main bucket — use as a reference in other stacks |
| `bucket_arn` | ARN — use in IAM policies to grant access to this specific bucket |
| `bucket_regional_domain_name` | Regional endpoint — use as a CloudFront origin |
| `kms_key_arn` | ARN of the encryption key — required if another service needs to read encrypted objects |
| `logging_bucket_id` | Name of the logging bucket |
| `notification_topic_arn` | ARN of the SNS topic — use to subscribe consumers |
| `website_endpoint` | Static website URL if website hosting is enabled |

---

## Variables

| Variable | Default | Notes |
|---|---|---|
| `ACCOUNT_ID` | — | Required. AWS account ID for the primary provider's assumed role. |
| `REPLICA_ACCOUNT_ID` | — | Required. AWS account ID where the replica bucket lives. |
| `AWS_REGION` | `us-east-1` | Primary region. |
| `REPLICA_ROLE_NAME` | `Engineer` | IAM role name assumed in the replica account. |
| `ROLE_NAME` | — | Required. Used in bucket naming. |
| `RUNNER` | — | Required. Used in bucket naming and KMS alias. |
| `ORGANIZATION` | — | Required. Used in bucket naming, KMS alias, and IAM resource names. |
| `bucket_usage` | `general` | Appended to the main and replica bucket names to indicate purpose. |
| `ENVIRONMENT` | `Development` | Applied as a default tag across all resources via provider. |
| `ManagedBy` | `terraform` | Applied as a default tag. |

---

## Caveats

- All buckets have `force_destroy = true`, which allows `terraform destroy` to delete non-empty buckets. This is intentional for dev/test workflows but is dangerous in production — remove this flag on any bucket holding data you can't afford to lose.
- The replication role and policy are created in the primary account but operate cross-account. Ensure the replica account's trust relationships allow the primary account's replication role to write to the replica bucket.
- Object lock with GOVERNANCE mode provides soft deletion protection. If your use case requires immutability guarantees (compliance, legal hold), switch to COMPLIANCE mode and extend the retention period accordingly.
