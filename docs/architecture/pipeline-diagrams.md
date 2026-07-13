# Pipeline architecture diagrams

Visual reference for the Music Streaming ETL platform (`dev`, `ap-southeast-1`).
Data flows **raw → clean → analytics** across S3 zones, driven by Lambda + Glue,
and is consumed through Athena, Redshift Serverless, and (opt-in) QuickSight.
Names shown are the deployed `music-etl-dev-*` resources.

## Components diagram

How the AWS services are wired together, grouped by responsibility.

```mermaid
flowchart LR
    %% ---------- Ingestion ----------
    subgraph ingest["Ingestion"]
        PROD["Event producers"]
        KDS["Kinesis Data Streams<br/>music-etl-dev-events"]
        FH["Amazon Data Firehose<br/>music-etl-dev-raw-delivery"]
        BATCH["Batch source<br/>Kaggle files + manifest.json"]
    end

    %% ---------- Data lake (S3) ----------
    subgraph lake["Data lake — S3 (SSE-KMS, versioned, TLS-only)"]
        RAW["raw/"]
        CLEAN["clean/"]
        ANALYTICS["analytics/"]
        QUAR["quarantine/"]
        ARES["athena-results/"]
        GA["glue-assets bucket<br/>scripts + quality library"]
    end

    %% ---------- Orchestration + ETL ----------
    subgraph etl["Orchestration & ETL"]
        S3EVT["S3 event notification<br/>prefix raw/ · suffix manifest.json"]
        VAL["Lambda validator<br/>manifest-validator"]
        DLQ["SQS DLQ<br/>manifest-dlq"]
        R2C["Glue job<br/>raw-to-clean"]
        EB["EventBridge rule<br/>Glue Job State Change = SUCCEEDED"]
        ORCH["Lambda orchestrator<br/>glue-orchestrator"]
        C2A["Glue job<br/>clean-to-analytics"]
        QLIB["Quality library<br/>required-column check · dedup on event_id"]
    end

    %% ---------- Analytics + consumption ----------
    subgraph consume["Analytics & consumption"]
        CATALOG["Glue Data Catalog<br/>music_raw · music_clean · music_analytics"]
        ATHENA["Athena workgroup<br/>bytes-scanned cap"]
        REDSHIFT["Redshift Serverless<br/>MERGE into analytics.fact_stream"]
        QS["QuickSight (opt-in)<br/>SPICE · private VPC connection"]
    end

    %% ---------- Cross-cutting ----------
    subgraph govern["Governance & observability"]
        LF["Lake Formation<br/>analytics-reader = analytics only, raw denied"]
        CW["CloudWatch<br/>log groups · alarms · dashboard"]
    end

    %% Ingestion edges
    PROD --> KDS
    KDS --> FH
    FH -->|"raw/source=kinesis/"| RAW
    BATCH -->|"upload + manifest"| RAW

    %% Batch trigger + validation
    RAW -. "manifest.json created" .-> S3EVT
    S3EVT --> VAL
    VAL -->|"glue.start_job_run"| R2C
    VAL -. "on failure" .-> DLQ

    %% raw-to-clean
    RAW --> R2C
    R2C -->|"valid rows"| CLEAN
    R2C -->|"invalid rows"| QUAR
    QLIB -. "used by" .-> R2C
    QLIB -. "used by" .-> C2A

    %% chaining raw-to-clean -> clean-to-analytics
    R2C -. "SUCCEEDED" .-> EB
    EB --> ORCH
    ORCH -->|"glue.start_job_run"| C2A
    CLEAN --> C2A
    C2A -->|"BI models"| ANALYTICS

    %% glue assets
    GA -. "scripts + libs" .-> R2C
    GA -. "scripts + libs" .-> C2A

    %% consumption
    ANALYTICS --> CATALOG
    ATHENA --> CATALOG
    ATHENA --> ARES
    REDSHIFT -->|"read Parquet"| ANALYTICS
    QS --> REDSHIFT

    %% governance + observability
    LF -. "governs" .-> CATALOG
    CW -. "monitors" .-> VAL
    CW -. "monitors" .-> R2C
    CW -. "monitors" .-> C2A
    CW -. "monitors" .-> REDSHIFT

    classDef store fill:#e8f0fe,stroke:#4877c9,color:#1a2b4a;
    classDef compute fill:#eafaf1,stroke:#3fa66a,color:#123524;
    classDef gov fill:#fdf3e7,stroke:#d08a2c,color:#4a2f10;
    class RAW,CLEAN,ANALYTICS,QUAR,ARES,GA store;
    class VAL,R2C,C2A,ORCH,ATHENA,REDSHIFT,QS compute;
    class LF,CW,DLQ gov;
```

## Sequence diagram

End-to-end processing for a batch partition, plus the parallel streaming path
and downstream consumption.

```mermaid
sequenceDiagram
    autonumber
    participant PR as Producer
    participant KDS as Kinesis
    participant FH as Data Firehose
    participant S3 as S3 data lake
    participant VAL as Validator Lambda
    participant DLQ as SQS DLQ
    participant R2C as Glue raw-to-clean
    participant EB as EventBridge
    participant ORC as Orchestrator Lambda
    participant C2A as Glue clean-to-analytics
    participant CAT as Glue Catalog / Lake Formation
    participant ATH as Athena
    participant RS as Redshift Serverless
    participant QS as QuickSight

    Note over PR,S3: Streaming ingestion (continuous)
    PR->>KDS: put event records
    KDS->>FH: source records
    FH->>S3: deliver GZIP to raw/source=kinesis/
    Note right of FH: delivery errors → quarantine/source=kinesis/errors/

    Note over PR,VAL: Batch ingestion + validation
    PR->>S3: upload partition files + manifest.json to raw/
    S3->>VAL: s3:ObjectCreated (raw/ *manifest.json)
    alt manifest key shape valid
        VAL->>R2C: glue.start_job_run(raw-to-clean)
    else invalid / error
        VAL-->>DLQ: send message for replay
    end

    Note over R2C,S3: raw → clean
    R2C->>S3: read raw partition
    R2C->>R2C: validate required columns, dedup on event_id
    R2C->>S3: write canonical Parquet to clean/
    R2C->>S3: write invalid rows to quarantine/

    Note over R2C,C2A: Orchestrated chaining
    R2C-->>EB: Glue Job State Change = SUCCEEDED
    EB->>ORC: invoke on matched event
    ORC->>C2A: glue.start_job_run(clean-to-analytics)
    Note right of ORC: skips if a run is already in progress

    Note over C2A,S3: clean → analytics
    C2A->>S3: read clean/
    C2A->>S3: write fact_stream + dim_* Parquet to analytics/
    C2A->>CAT: register / update partitions

    Note over ATH,QS: Consumption (governed by Lake Formation)
    ATH->>CAT: resolve tables (SELECT on analytics only)
    ATH->>S3: scan analytics/ (results → athena-results/)
    RS->>S3: read analytics/ Parquet
    RS->>RS: idempotent MERGE into analytics.fact_stream
    QS->>RS: refresh SPICE via private VPC connection
```

## Flow diagram

The data's journey from ingestion to insight, with the decision points that route
records to `clean/`, `quarantine/`, or the DLQ.

```mermaid
flowchart TD
    START(["Music streaming event generated"]) --> ING{"Ingestion path?"}

    %% Streaming path
    ING -->|Streaming| KDS["Publish to Kinesis Data Streams"]
    KDS --> FHD["Data Firehose buffers + GZIP"]
    FHD --> RAWK["Write to raw/source=kinesis/"]
    RAWK --> RAWZONE

    %% Batch path
    ING -->|Batch| UP["Upload partition files + manifest.json to raw/"]
    UP --> RAWZONE[("raw/ zone — immutable")]
    UP --> EVT["S3 ObjectCreated event on manifest.json"]

    %% Validation
    EVT --> VAL{"Manifest key shape valid?"}
    VAL -->|No| DLQ[("SQS DLQ — replay after fix")]
    VAL -->|Yes| STARTR2C["Validator calls glue.start_job_run"]
    STARTR2C --> R2C["Glue raw-to-clean reads raw partition"]

    %% Quality gate
    R2C --> REQ{"Required columns present + valid?"}
    REQ -->|No| QUAR[("quarantine/ — invalid rows + metadata")]
    REQ -->|Yes| DEDUP["Dedup on event_id"]
    DEDUP --> CLEAN[("clean/ — canonical Parquet")]

    %% Orchestrated chaining
    CLEAN --> R2CDONE{"raw-to-clean SUCCEEDED?"}
    R2CDONE -->|No| ALARM["CloudWatch alarm — investigate"]
    R2CDONE -->|Yes| EB["EventBridge: Glue Job State Change"]
    EB --> ORCH{"clean-to-analytics already running?"}
    ORCH -->|Yes| SKIP["Skip — existing run covers clean zone"]
    ORCH -->|No| C2A["Glue clean-to-analytics reads clean/"]

    %% Analytics build
    C2A --> MODELS["Build fact_stream + dim_artist/dim_track + daily metrics"]
    MODELS --> ANALYTICS[("analytics/ — BI-ready Parquet")]
    ANALYTICS --> CAT["Register partitions in Glue Catalog"]

    %% Consumption
    CAT --> CONSUME{"Consumption"}
    CONSUME -->|Athena| ATH["Query via workgroup — scan cap + Lake Formation"]
    CONSUME -->|Redshift| RS["Idempotent MERGE into analytics.fact_stream"]
    CONSUME -->|QuickSight opt-in| QS["Refresh SPICE via private VPC connection"]
    ATH --> ENDN(["Insights & dashboards"])
    RS --> ENDN
    QS --> ENDN

    classDef store fill:#e8f0fe,stroke:#4877c9,color:#1a2b4a;
    classDef bad fill:#fdecea,stroke:#c0392b,color:#4a1512;
    class RAWZONE,CLEAN,ANALYTICS store;
    class DLQ,QUAR,ALARM bad;
```

## Legend

- **Solid arrows** — data movement or a synchronous call (e.g. `start_job_run`).
- **Dotted arrows** — an event/trigger or a governance/monitoring relationship.
- **Diamonds** (flow diagram) — decision points; red nodes are fault paths
  (`quarantine/`, DLQ, alarm) that never mutate `raw/`.
- **quarantine/** receives both record-level rejections (from Glue) and Data Firehose
  delivery errors; raw data is never mutated.
- Streaming (Kinesis → Data Firehose) and batch (manifest → validator) are independent
  ingestion paths that converge in `raw/` and share the same downstream Glue jobs.
- QuickSight is opt-in (`quicksight_enabled = false` by default); the rest of the
  stack is always deployed.

> Source of truth is Terraform under `terraform/`; update these diagrams when the
> module wiring, orchestration, or data zones change.
