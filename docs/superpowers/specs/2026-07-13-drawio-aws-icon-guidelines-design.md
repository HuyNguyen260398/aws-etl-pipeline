# Design: Guideline-compliant rework of `docs/architecture/aws-etl-pipeline.drawio`

**Date:** 2026-07-13
**Status:** Approved (Approach A)

## Goal

Update the draw.io architecture diagram to comply with the official AWS Architecture
Icons guidelines (deck release 23-2026.04.28, light background) and use the icons from
the local asset package at `/Users/huyng/ws/aws-architecture/Icon-package`
(release 04302026). The architecture content — services, edges, edge labels — does not
change; only presentation, structure, and naming do.

## Source material

- Guidelines deck: `/Users/huyng/ws/aws-architecture/Microsoft-PPTx-toolkits/AWS-Architecture-Icons-Deck_For-Light-BG_04282026.pptx` (guidance on slides 11–18, groups on 25–26)
- Icon package: `/Users/huyng/ws/aws-architecture/Icon-package/`
  - `Architecture-Service-Icons_04302026/<category>/48/*.svg` — service icons
  - `Resource-Icons_04302026/**/*_48.svg` — resource + general resource icons
  - `Architecture-Group-Icons_04302026/*_32.svg` — group header icons

## Binding guideline rules applied

1. **Groups give the diagram its structure.** Outer **AWS Cloud** group (dark
   `#232F3E` solid frame, AWS Cloud group icon top-left), containing a **Region**
   group (`ap-southeast-1`, dashed teal `#00A4A6` frame, Region group icon), which
   contains all AWS services. A **generic group** (dashed grey) inside the Region
   holds the cross-cutting security/governance/observability services. Nested groups
   keep a visible buffer on all sides.
2. **External actors sit outside the AWS Cloud group:** streaming producers
   (general resource icon `Res_Client`) and the batch source (`Res_Server`).
3. **Official icons, unmodified, at fixed size** — 48px service icons embedded as
   base64 SVG data-URIs (`aspect=fixed`, no restyling, no recoloring, no rotation).
4. **Current (04/2026) service naming**, full name on first use, max two lines, no
   mid-word breaks, `AWS`/`Amazon` on the same line as the first word:
   - Kinesis Data Firehose → **Amazon Data Firehose**
   - QuickSight icon is now `Arch_Amazon-Quick_48` (Quick Suite rebrand); label kept
     as "Amazon QuickSight (opt-in)" to match project terminology.
5. **Labels:** 12pt Arial, black (`#000000`), placed under the icon.
6. **Arrows:** straight orthogonal lines with **open arrowheads**, consistent weight
   and color (dark); dashed variants only for event/notification edges (S3 event
   trigger, Glue SUCCEEDED event, failure → DLQ). Existing edge annotations
   (`start_job_run`, `MERGE (idempotent)`, etc.) are retained at a smaller size.
7. **Numbered callouts 1–8** (black circles, bold white numerals, uniform size)
   marking the pipeline order: 1 stream ingest, 2 batch/raw landing, 3 validate,
   4 raw-to-clean (+ quarantine), 5 SUCCEEDED event, 6 orchestrate, 7
   clean-to-analytics, 8 consumption (Athena/Redshift/QuickSight).

## Icon manifest

| Diagram node | Icon file (in package) |
| --- | --- |
| Streaming producers | `Res_General-Icons/Res_48_Light/Res_Client_48_Light.svg` |
| Batch source | `Res_General-Icons/Res_48_Light/Res_Server_48_Light.svg` |
| Kinesis Data Streams | `Arch_Analytics/48/Arch_Amazon-Kinesis-Data-Streams_48.svg` |
| Amazon Data Firehose | `Arch_Analytics/48/Arch_Amazon-Data-Firehose_48.svg` |
| S3 raw/clean/analytics/quarantine | `Arch_Storage/48/Arch_Amazon-Simple-Storage-Service_48.svg` |
| Validator / Orchestrator Lambda | `Arch_Compute/48/Arch_AWS-Lambda_48.svg` |
| SQS DLQ | `Arch_Application-Integration/48/Arch_Amazon-Simple-Queue-Service_48.svg` |
| Glue raw-to-clean / clean-to-analytics | `Arch_Analytics/48/Arch_AWS-Glue_48.svg` |
| EventBridge | `Arch_Application-Integration/48/Arch_Amazon-EventBridge_48.svg` |
| Glue Data Catalog | `Res_Analytics/Res_AWS-Glue_Data-Catalog_48.svg` (resource icon) |
| Athena | `Arch_Analytics/48/Arch_Amazon-Athena_48.svg` |
| Redshift Serverless | `Arch_Analytics/48/Arch_Amazon-Redshift_48.svg` |
| QuickSight (opt-in) | `Arch_Business-Applications/48/Arch_Amazon-Quick_48.svg` |
| IAM | `Arch_Security-Identity/48/Arch_AWS-Identity-and-Access-Management_48.svg` |
| KMS | `Arch_Security-Identity/48/Arch_AWS-Key-Management-Service_48.svg` |
| Secrets Manager | `Arch_Security-Identity/48/Arch_AWS-Secrets-Manager_48.svg` |
| Lake Formation | `Arch_Analytics/48/Arch_AWS-Lake-Formation_48.svg` |
| CloudWatch | `Arch_Management-Tools/48/Arch_Amazon-CloudWatch_48.svg` |
| VPC + S3 gateway endpoint | `Arch_Networking-Content-Delivery/48/Arch_Amazon-Virtual-Private-Cloud_48.svg` |
| AWS Cloud group header | `Architecture-Group-Icons_04302026/AWS-Cloud_32.svg` |
| Region group header | `Architecture-Group-Icons_04302026/Region_32.svg` |

## Approach (A — approved)

Rewrite the `.drawio` XML in place at `docs/architecture/aws-etl-pipeline.drawio`
(same single page). Icons are embedded as `image;...image=data:image/svg+xml,<base64>`
vertices so the file is fully self-contained and renders identically for anyone who
opens it, with no dependency on the local icon package or draw.io's bundled shape
libraries. Group containers are plain styled rectangles matching the official group
specs, with the 32px group icon embedded in the top-left corner and the label beside it.

Rejected alternative (B): keep draw.io built-in `mxgraph.aws4` shapes and fix only
structure/labels/arrows — lighter file, but uses older icon designs and does not use
the requested icon package.

## Verification

- File opens cleanly in draw.io (valid XML; `xmllint` passes).
- Visual check of an exported PNG/render: no overlapping nodes or labels, groups
  properly nested with buffers, arrows orthogonal, callouts ordered left→right.
- All icons visibly match the 04/2026 designs (spot-check Data Firehose and Quick).
