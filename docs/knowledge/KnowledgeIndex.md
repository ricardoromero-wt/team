# Knowledge Index

> Read the index at session start. Read individual files when the trigger conditions are met.

## Always Loaded

These govern every decision — read before starting any task.

| Domain | File | Why always loaded |
|--------|------|-------------------|
| Subagent dispatch index | [`subagent-briefs/README.md`](./subagent-briefs/README.md) | Routing card for picking the right brief; every dispatch starts here |

## Triggered by Content

| Domain | File | Read When |
|--------|------|-----------|
| Nest API dispatch | [`subagent-briefs/nest-api-brief.md`](./subagent-briefs/nest-api-brief.md) | Dispatching work in `apps/aqm-api` or any other `apps/*-api` Nest HTTP service |
| Next.js web dispatch | [`subagent-briefs/next-web-brief.md`](./subagent-briefs/next-web-brief.md) | Dispatching work in `apps/aqm-web` or any other `apps/*-web` Next.js app |
| Nest worker dispatch | [`subagent-briefs/nest-worker-brief.md`](./subagent-briefs/nest-worker-brief.md) | Dispatching work in `apps/vcon-worker` or any other Cloud Run worker |
| Cloud Function dispatch | [`subagent-briefs/cloud-function-brief.md`](./subagent-briefs/cloud-function-brief.md) | Dispatching work in `firebase/functions/typescript` or `firebase/functions/python`, including Cloud Scheduler triggers |
| vcon-ingestion Cloud Function dispatch | [`subagent-briefs/vcon-cloud-function-brief.md`](./subagent-briefs/vcon-cloud-function-brief.md) | Dispatching work in `vcon-ingestion/{rawdata-to-transcript,transcript-to-vcon,vcon-to-vstore}` (GCP Cloud Functions 2nd gen, GCS-triggered) |
| vcon-ingestion orchestrator dispatch | [`subagent-briefs/vcon-orchestrator-brief.md`](./subagent-briefs/vcon-orchestrator-brief.md) | Dispatching work in `vcon-ingestion/orchestrator/*` (Flask Cloud Run services + `batch-monitor` Pub/Sub daemon) |
| vcon-ingestion webapp dispatch | [`subagent-briefs/vcon-ingestion-webapp-brief.md`](./subagent-briefs/vcon-ingestion-webapp-brief.md) | Dispatching work in `vcon-ingestion/ingestion-webapp/{backend,frontend}` (Express + React 19 CRA) |
| vcon-store dispatch | [`subagent-briefs/vcon-store-brief.md`](./subagent-briefs/vcon-store-brief.md) | Dispatching work in `vcon-store/` (FastAPI + Poetry + multi-backend storage adapters) |

<!-- Future additions Team will likely make as it grows:
     | Cross-stack conventions | `cross-stack-conventions.md` | Mission 2 — proposing a convention across surfaces |
     | Backend flow specs | `flow-specs/<flow-name>.md` | Touching a service involved in a documented end-to-end flow |
     | NestJS gotchas | `nestjs-gotchas.md` | Dispatch involves NestJS DI scope, decorators, or module boundaries |
-->

Knowledge base entries (solved problems) live in `docs/solutions/` across these categories: architecture | debugging | integration | tooling | performance | subagent-design | nestjs | python-react. Search there when a problem resembles something previously encountered.
