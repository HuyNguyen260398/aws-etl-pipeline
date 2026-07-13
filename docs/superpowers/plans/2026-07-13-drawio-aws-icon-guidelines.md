# Draw.io AWS Icon Guidelines Rework — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Regenerate `docs/architecture/aws-etl-pipeline.drawio` so it complies with the AWS Architecture Icons guidelines (release 23-2026.04.28) using icons embedded from the local 04302026 asset package.

**Architecture:** A one-shot Python generator script (run from a temp dir, not committed) base64-embeds the official SVGs and emits the complete draw.io XML: AWS Cloud group → Region group → service icons + separate 12pt Arial labels, a generic group for cross-cutting services, open-arrow orthogonal edges, and numbered callouts. A companion check script asserts structure before commit.

**Tech Stack:** Python 3 stdlib only (`base64`, `xml.sax.saxutils`, `xml.etree`), `xmllint` for XML validity. No new project dependencies.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-13-drawio-aws-icon-guidelines-design.md` (approved, Approach A).
- Icon package root: `/Users/huyng/ws/aws-architecture/Icon-package` (machine-local; scripts take it as a constant).
- Architecture content is unchanged: same services, same 19 edges, same edge annotations.
- Only `docs/architecture/aws-etl-pipeline.drawio` is committed. Generator/check scripts stay in a temp dir.
- Labels: 12pt Arial, `#000000`. Naming: "Amazon Data Firehose" (not Kinesis Data Firehose); QuickSight uses the `Arch_Amazon-Quick_48` icon but keeps the label "Amazon QuickSight (opt-in)".
- Icons embedded as base64 SVG data-URIs, 48px, unmodified (`aspect=fixed`).
- Do NOT touch the pre-existing uncommitted change in the repo (`plan/infrastructure-aws-etl-1.md` move) — commit only the diagram file.

---

### Task 1: Generate, verify, and commit the new diagram

**Files:**
- Modify: `docs/architecture/aws-etl-pipeline.drawio` (fully regenerated)
- Temp (not committed): `$TMP/gen_diagram.py`, `$TMP/check_diagram.py` where `TMP` is any scratch directory

**Interfaces:**
- Consumes: icon SVGs from the package paths listed in the spec's icon manifest.
- Produces: the committed `.drawio` file. No code interfaces.

- [ ] **Step 1: Write the generator script** to `$TMP/gen_diagram.py`:

```python
#!/usr/bin/env python3
"""Generate docs/architecture/aws-etl-pipeline.drawio per the 04/2026 AWS icon guidelines."""
import base64
from xml.sax.saxutils import escape, quoteattr

PKG = "/Users/huyng/ws/aws-architecture/Icon-package"
ARCH = f"{PKG}/Architecture-Service-Icons_04302026"
RES = f"{PKG}/Resource-Icons_04302026"
GRP = f"{PKG}/Architecture-Group-Icons_04302026"
OUT = "/Users/huyng/ws/aws-etl-pipeline/docs/architecture/aws-etl-pipeline.drawio"

def b64(path):
    with open(path, "rb") as f:
        return base64.b64encode(f.read()).decode()

def icon_style(path):
    return f"image;html=1;aspect=fixed;image=data:image/svg+xml,{b64(path)};"

TEXT = ("text;html=1;align=center;verticalAlign=top;fontFamily=Arial;"
        "fontSize=12;fontColor=#000000;whiteSpace=wrap;")
GTITLE = ("text;html=1;align=left;verticalAlign=middle;fontFamily=Arial;"
          "fontSize=12;fontStyle=1;fontColor=#000000;")
EDGE = ("edgeStyle=orthogonalEdgeStyle;rounded=0;html=1;endArrow=open;endFill=0;"
        "endSize=8;strokeColor=#232F3E;strokeWidth=1.5;fontFamily=Arial;"
        "fontSize=10;fontColor=#000000;")
EDGE_DASH = EDGE + "dashed=1;"
CALLOUT = ("ellipse;fillColor=#000000;strokeColor=none;fontColor=#FFFFFF;"
           "fontStyle=1;fontFamily=Arial;fontSize=12;html=1;resizable=0;")

# id: (svg path, label, icon x, icon y)   -- icons are 48x48
NODES = {
    "stream_src": (f"{RES}/Res_General-Icons/Res_48_Light/Res_Client_48_Light.svg",
                   "Streaming producers", 60, 200),
    "batch_src":  (f"{RES}/Res_General-Icons/Res_48_Light/Res_Server_48_Light.svg",
                   "Batch source (files + manifest.json)", 60, 420),
    "kds":        (f"{ARCH}/Arch_Analytics/48/Arch_Amazon-Kinesis-Data-Streams_48.svg",
                   "Amazon Kinesis Data Streams", 300, 200),
    "fh":         (f"{ARCH}/Arch_Analytics/48/Arch_Amazon-Data-Firehose_48.svg",
                   "Amazon Data Firehose", 450, 200),
    "s3_raw":     (f"{ARCH}/Arch_Storage/48/Arch_Amazon-Simple-Storage-Service_48.svg",
                   "Amazon S3 raw/", 600, 340),
    "s3_clean":   (f"{ARCH}/Arch_Storage/48/Arch_Amazon-Simple-Storage-Service_48.svg",
                   "Amazon S3 clean/", 890, 200),
    "s3_analytics": (f"{ARCH}/Arch_Storage/48/Arch_Amazon-Simple-Storage-Service_48.svg",
                   "Amazon S3 analytics/", 1190, 340),
    "s3_quar":    (f"{ARCH}/Arch_Storage/48/Arch_Amazon-Simple-Storage-Service_48.svg",
                   "Amazon S3 quarantine/", 750, 480),
    "validator":  (f"{ARCH}/Arch_Compute/48/Arch_AWS-Lambda_48.svg",
                   "AWS Lambda validator", 600, 480),
    "dlq":        (f"{ARCH}/Arch_Application-Integration/48/Arch_Amazon-Simple-Queue-Service_48.svg",
                   "Amazon SQS DLQ", 450, 480),
    "glue_r2c":   (f"{ARCH}/Arch_Analytics/48/Arch_AWS-Glue_48.svg",
                   "AWS Glue raw-to-clean", 750, 340),
    "eventbridge": (f"{ARCH}/Arch_Application-Integration/48/Arch_Amazon-EventBridge_48.svg",
                   "Amazon EventBridge (job SUCCEEDED)", 890, 480),
    "orch":       (f"{ARCH}/Arch_Compute/48/Arch_AWS-Lambda_48.svg",
                   "AWS Lambda orchestrator", 1040, 480),
    "glue_c2a":   (f"{ARCH}/Arch_Analytics/48/Arch_AWS-Glue_48.svg",
                   "AWS Glue clean-to-analytics", 1040, 200),
    "catalog":    (f"{RES}/Res_Analytics/Res_AWS-Glue_Data-Catalog_48.svg",
                   "AWS Glue Data Catalog", 1190, 480),
    "athena":     (f"{ARCH}/Arch_Analytics/48/Arch_Amazon-Athena_48.svg",
                   "Amazon Athena", 1360, 230),
    "redshift":   (f"{ARCH}/Arch_Analytics/48/Arch_Amazon-Redshift_48.svg",
                   "Amazon Redshift Serverless", 1360, 410),
    "quicksight": (f"{ARCH}/Arch_Business-Applications/48/Arch_Amazon-Quick_48.svg",
                   "Amazon QuickSight (opt-in)", 1510, 410),
    "iam":        (f"{ARCH}/Arch_Security-Identity/48/Arch_AWS-Identity-and-Access-Management_48.svg",
                   "AWS IAM", 300, 706),
    "kms":        (f"{ARCH}/Arch_Security-Identity/48/Arch_AWS-Key-Management-Service_48.svg",
                   "AWS Key Management Service", 480, 706),
    "secrets":    (f"{ARCH}/Arch_Security-Identity/48/Arch_AWS-Secrets-Manager_48.svg",
                   "AWS Secrets Manager", 660, 706),
    "lakeformation": (f"{ARCH}/Arch_Analytics/48/Arch_AWS-Lake-Formation_48.svg",
                   "AWS Lake Formation", 840, 706),
    "cloudwatch": (f"{ARCH}/Arch_Management-Tools/48/Arch_Amazon-CloudWatch_48.svg",
                   "Amazon CloudWatch", 1020, 706),
    "vpc":        (f"{ARCH}/Arch_Networking-Content-Delivery/48/Arch_Amazon-Virtual-Private-Cloud_48.svg",
                   "Amazon VPC (S3 gateway endpoint)", 1200, 706),
}

# id, source, target, label, dashed, extra style hints (exit/entry points)
EDGES = [
    ("e_ss_kds", "stream_src", "kds", "", 0, "exitX=1;exitY=0.5;entryX=0;entryY=0.5;"),
    ("e_kds_fh", "kds", "fh", "", 0, "exitX=1;exitY=0.5;entryX=0;entryY=0.5;"),
    ("e_fh_raw", "fh", "s3_raw", "raw/source=kinesis/", 0, "exitX=0.5;exitY=1;entryX=0;entryY=0.5;"),
    ("e_batch_raw", "batch_src", "s3_raw", "upload + manifest", 0, "exitX=1;exitY=0.5;entryX=0;entryY=0.75;"),
    ("e_raw_val", "s3_raw", "validator", "s3:ObjectCreated manifest.json", 1, "exitX=0.5;exitY=1;entryX=0.5;entryY=0;"),
    ("e_val_r2c", "validator", "glue_r2c", "start_job_run", 0, "exitX=1;exitY=0.25;entryX=0.25;entryY=1;"),
    ("e_val_dlq", "validator", "dlq", "on failure", 1, "exitX=0;exitY=0.5;entryX=1;entryY=0.5;"),
    ("e_raw_r2c", "s3_raw", "glue_r2c", "read", 0, "exitX=1;exitY=0.5;entryX=0;entryY=0.5;"),
    ("e_r2c_clean", "glue_r2c", "s3_clean", "valid rows", 0, "exitX=1;exitY=0.25;entryX=0;entryY=0.5;"),
    ("e_r2c_quar", "glue_r2c", "s3_quar", "invalid rows", 1, "exitX=0.5;exitY=1;entryX=0.5;entryY=0;"),
    ("e_r2c_eb", "glue_r2c", "eventbridge", "SUCCEEDED", 1, "exitX=0.75;exitY=1;entryX=0;entryY=0.5;"),
    ("e_eb_orch", "eventbridge", "orch", "", 0, "exitX=1;exitY=0.5;entryX=0;entryY=0.5;"),
    ("e_orch_c2a", "orch", "glue_c2a", "start_job_run", 0, "exitX=0.5;exitY=0;entryX=0.5;entryY=1;"),
    ("e_clean_c2a", "s3_clean", "glue_c2a", "read", 0, "exitX=1;exitY=0.5;entryX=0;entryY=0.5;"),
    ("e_c2a_analytics", "glue_c2a", "s3_analytics", "BI models", 0, "exitX=1;exitY=0.5;entryX=0.5;entryY=0;"),
    ("e_analytics_catalog", "s3_analytics", "catalog", "register partitions", 1, "exitX=0.5;exitY=1;entryX=0.5;entryY=0;"),
    ("e_analytics_athena", "s3_analytics", "athena", "scan", 0, "exitX=1;exitY=0.25;entryX=0;entryY=0.5;"),
    ("e_analytics_redshift", "s3_analytics", "redshift", "MERGE (idempotent)", 0, "exitX=1;exitY=0.75;entryX=0;entryY=0.5;"),
    ("e_redshift_qs", "redshift", "quicksight", "SPICE refresh", 0, "exitX=1;exitY=0.5;entryX=0;entryY=0.5;"),
]

CALLOUTS = [  # number, x, y (24x24 black circles, white bold numerals)
    (1, 280, 180), (2, 580, 320), (3, 580, 460), (4, 730, 320),
    (5, 870, 460), (6, 1020, 460), (7, 1020, 180), (8, 1340, 210),
]

cells = []

def vertex(cid, value, style, x, y, w, h):
    cells.append(
        f'<mxCell id="{cid}" value={quoteattr(value)} style={quoteattr(style)} '
        f'vertex="1" parent="1"><mxGeometry x="{x}" y="{y}" width="{w}" height="{h}" '
        f'as="geometry" /></mxCell>')

def edge(cid, value, style, src, dst):
    cells.append(
        f'<mxCell id="{cid}" value={quoteattr(value)} style={quoteattr(style)} '
        f'edge="1" parent="1" source="{src}" target="{dst}">'
        f'<mxGeometry relative="1" as="geometry" /></mxCell>')

# Title
vertex("title", "AWS ETL Pipeline — Reference Architecture (raw → clean → analytics)",
       "text;html=1;align=left;verticalAlign=middle;fontFamily=Arial;fontSize=18;"
       "fontStyle=1;fontColor=#000000;", 40, 20, 900, 30)

# Groups (background rectangles first so everything renders on top of them)
vertex("grp_cloud", "", "rounded=0;fillColor=none;strokeColor=#232F3E;html=1;",
       200, 80, 1540, 760)
vertex("grp_cloud_icon", "", icon_style(f"{GRP}/AWS-Cloud_32.svg"), 200, 80, 32, 32)
vertex("grp_cloud_lbl", "AWS Cloud", GTITLE, 240, 82, 200, 28)
vertex("grp_region", "", "rounded=0;fillColor=none;strokeColor=#00A4A6;dashed=1;html=1;",
       240, 140, 1460, 500)
vertex("grp_region_icon", "", icon_style(f"{GRP}/Region_32.svg"), 240, 140, 32, 32)
vertex("grp_region_lbl", "Region (ap-southeast-1)", GTITLE, 280, 142, 300, 28)
vertex("grp_xcut", "", "rounded=0;fillColor=none;strokeColor=#7D8998;dashed=1;html=1;",
       240, 680, 1460, 140)
vertex("grp_xcut_lbl", "Security, governance & observability", GTITLE, 252, 682, 400, 24)

# Icons + separate labels (labels: 110 wide, centered under the 48px icon)
for cid, (path, label, x, y) in NODES.items():
    vertex(cid, "", icon_style(path), x, y, 48, 48)
    vertex(f"{cid}_lbl", label, TEXT, x - 31, y + 52, 110, 34)

# Numbered callouts
for n, x, y in CALLOUTS:
    vertex(f"callout_{n}", str(n), CALLOUT, x, y, 24, 24)

# Edges
for cid, src, dst, label, dashed, hints in EDGES:
    edge(cid, label, (EDGE_DASH if dashed else EDGE) + hints, src, dst)

body = "\n        ".join(cells)
xml = f'''<mxfile host="app.diagrams.net" agent="claude-code" version="24.0.0">
  <diagram id="aws-etl-pipeline" name="AWS ETL Pipeline">
    <mxGraphModel dx="1400" dy="850" grid="1" gridSize="10" guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" pageScale="1" pageWidth="1780" pageHeight="880" math="0" shadow="0">
      <root>
        <mxCell id="0" />
        <mxCell id="1" parent="0" />
        {body}
      </root>
    </mxGraphModel>
  </diagram>
</mxfile>
'''
with open(OUT, "w") as f:
    f.write(xml)
print(f"wrote {OUT} ({len(xml)} bytes, {len(cells)} cells)")
```

- [ ] **Step 2: Run the generator**

Run: `python3 $TMP/gen_diagram.py`
Expected: `wrote .../docs/architecture/aws-etl-pipeline.drawio (<N> bytes, 84 cells)` — 84 = 1 title + 8 group cells (incl. 2 group icons + 3 group labels) + 24×2 node icon+label + 8 callouts + 19 edges.

- [ ] **Step 3: Validate XML**

Run: `xmllint --noout /Users/huyng/ws/aws-etl-pipeline/docs/architecture/aws-etl-pipeline.drawio && echo VALID`
Expected: `VALID` (no output from xmllint).

- [ ] **Step 4: Write the structural check script** to `$TMP/check_diagram.py`:

```python
#!/usr/bin/env python3
"""Assert the regenerated drawio complies with the spec's structural rules."""
import xml.etree.ElementTree as ET

F = "/Users/huyng/ws/aws-etl-pipeline/docs/architecture/aws-etl-pipeline.drawio"
root = ET.parse(F).getroot()
cells = root.findall(".//mxCell")
styles = {c.get("id"): (c.get("style") or "") for c in cells}

icons = [i for i, s in styles.items() if s.startswith("image;")]
assert len(icons) == 26, f"expected 26 embedded icons, got {len(icons)}"
assert all("data:image/svg+xml," in styles[i] for i in icons), "non-embedded icon found"

edges = [c for c in cells if c.get("edge") == "1"]
assert len(edges) == 19, f"expected 19 edges, got {len(edges)}"
assert all("endArrow=open" in (c.get("style") or "") for c in edges), "edge without open arrowhead"
assert all("strokeColor=#232F3E" in (c.get("style") or "") for c in edges), "edge with off-palette color"

labels = [i for i, s in styles.items() if i.endswith("_lbl") and i not in
          ("grp_cloud_lbl", "grp_region_lbl", "grp_xcut_lbl")]
assert len(labels) == 24, f"expected 24 icon labels, got {len(labels)}"
for i in labels:
    assert "fontFamily=Arial" in styles[i] and "fontSize=12" in styles[i] \
        and "fontColor=#000000" in styles[i], f"label {i} violates 12pt Arial black"

# naming rules
values = {c.get("id"): (c.get("value") or "") for c in cells}
assert values["fh_lbl"] == "Amazon Data Firehose", "Firehose not renamed"
assert "Kinesis Data Firehose" not in " ".join(values.values()), "stale Firehose naming"

# no icon-on-icon overlap (48px boxes must not intersect)
geoms = []
for c in cells:
    if c.get("id") in icons and not c.get("id", "").startswith("grp_"):
        g = c.find("mxGeometry")
        geoms.append((c.get("id"), float(g.get("x")), float(g.get("y"))))
for a in range(len(geoms)):
    for b in range(a + 1, len(geoms)):
        _, ax, ay = geoms[a]; _, bx, by = geoms[b]
        assert abs(ax - bx) >= 48 or abs(ay - by) >= 48, \
            f"icons overlap: {geoms[a][0]} vs {geoms[b][0]}"

callouts = [i for i in styles if i.startswith("callout_")]
assert len(callouts) == 8, f"expected 8 callouts, got {len(callouts)}"
print("ALL CHECKS PASS")
```

- [ ] **Step 5: Run the check script**

Run: `python3 $TMP/check_diagram.py`
Expected: `ALL CHECKS PASS`. If an assertion fails, fix the generator (not the output file) and rerun Steps 2–5.

- [ ] **Step 6: Commit the diagram only**

```bash
cd /Users/huyng/ws/aws-etl-pipeline
git add docs/architecture/aws-etl-pipeline.drawio
git commit -m "docs: rework drawio diagram to 04/2026 AWS icon guidelines"
```

Verify with `git status --short` that the pre-existing `plan/` move is still uncommitted and untouched.

- [ ] **Step 7: Visual QA by the user**

Ask the user to open `docs/architecture/aws-etl-pipeline.drawio` in draw.io (app.diagrams.net or the desktop app) and confirm: icons render as the 04/2026 designs, groups nest with visible buffers, arrows are orthogonal open-head, callouts 1–8 read in flow order, no overlapping labels. Any layout nudges can be made directly in draw.io afterwards.
