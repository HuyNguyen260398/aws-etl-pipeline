# Access matrix

| Role | Trust boundary | Intended responsibility |
|---|---|---|
| Lambda | `lambda.amazonaws.com` | Validate raw manifests and start Glue jobs. |
| Firehose | `firehose.amazonaws.com` | Deliver Kinesis records only to the raw prefix. |
| Glue | `glue.amazonaws.com` | Transform governed lake data and write clean/analytics/quarantine prefixes. |
| Redshift | `redshift.amazonaws.com` | Read analytics data and load warehouse tables. |
| Analytics reader | Configured trusted principal | Query Lake Formation analytics metadata and tables only. |

Lake Formation registers the encrypted data-lake bucket, catalogs raw, clean, and analytics databases, and grants the analytics reader `DESCRIBE` plus `SELECT` only on analytics tables. Raw and clean database permissions are intentionally absent for that role.
