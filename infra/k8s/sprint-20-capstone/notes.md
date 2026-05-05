# Sprint 20 — Act 2 Capstone — Notes

## Overview
Full Runmatic stack assembled into a single unified K8s manifest directory.
12 files, applied in order, bring up all 5 services with correct dependencies.

## Phase 1 — Clear the Slate
**Starting state check:**
- `kubectl delete all --all -n default` cleared all running resources
- 3 PVCs survived: `postgres-data-runmatic-postgres-0/1/2` (orphaned from earlier multi-replica experiments)
- Decision: keep all PVCs — StatefulSet will rebind to `-0` and existing runbook data survives
- metrics-server: `0/1` Ready — flagged for fix before HPA proof

**Key insight:** `kubectl delete all` does NOT delete PVCs. PersistentVolumeClaims are intentionally excluded from broad delete operations — Kubernetes protects storage from accidental deletion.

## Phase 2 — Assembly
**Capstone directory:** `infra/k8s/sprint-20-capstone/`

Vela assembled 12 files from previous sprint folders, applying two fixes:
1. `256M` → `256Mi` in worker-deployment.yaml (correct SI unit for mebibytes)
2. Ingress path: `/v2/api(/|$)(.*)` → `/api(/|$)(.*)` (removed erroneous `v2` prefix from Sprint 18)
3. Split into two separate Ingress objects (api + frontend) — clean separation of routing concerns

**Apply command:**
```bash
kubectl apply -f infra/k8s/sprint-20-capstone/
```

All 6 pods reached `Running` within ~45 seconds. Postgres was last due to StatefulSet initialisation.

**PVC reuse confirmed:** The `postgres-data-runmatic-postgres-0` PVC was rebound automatically. The demo user (`demo@runmatic.dev`) and all 4 seed runbooks were present without re-seeding.

## Phase 3 — Four Proofs

### Proof 1 — Self-Healing
```bash
kubectl delete pod -l app=runmatic-api
kubectl get pods -w
```
Both API pods replaced in under 2 seconds. The Deployment controller detected the missing pods and scheduled replacements immediately. New pods had new names (`m54sh`, `gsjmv`) but identical specs.

### Proof 2 — Ingress + Data Persistence
- Opened `http://runmatic.local` — UI loaded
- Created runbook titled "test for proof 2"
- Verified in postgres: `SELECT id, title FROM runbooks ORDER BY created_at DESC` showed 5 rows (4 seed + 1 new)
- Bonus discovery: demo user already existed in DB (PVC preserved data from previous session)

### Proof 3 — Manual Scaling
```bash
kubectl scale deployment/runmatic-worker --replicas=3
kubectl get pods -w   # 2 new worker pods: ContainerCreating → Running in 1s
kubectl scale deployment/runmatic-worker --replicas=1
kubectl get pods -w   # 2 pods: Running → Terminating → Completed
```
Full pod lifecycle visible in a single `kubectl get pods -w` output.

### Proof 4 — HPA
metrics-server needed the `--kubelet-insecure-tls` patch reapplied after cluster restart.
Once running:
```bash
kubectl run load --image=busybox --restart=Never -- sh -c "while true; do wget -q -O- http://api-service:8000/health; done"
kubectl get hpa -w
```
HPA progression:
- `cpu: 1%/50%` → `cpu: 200%/50%` (load pod running)
- Replicas: `1` → `3` (scale-up triggered by ceil(1 * 200/50) = 4, capped at maxReplicas=3)

## Phase 4 — Architecture Questions

**Q1: StatefulSet vs Deployment for Runmatic**
Vela's answer: API is stateless — every pod is identical and interchangeable, reads from postgres and redis, owns no data. Postgres needs StatefulSet for two guarantees: (1) stable pod name so the PVC claim name is predictable, (2) always connects to the same PVC so data survives pod replacement.

**Q2: What happens if the postgres PVC is deleted**
Vela's answer: Pod crashes when the mounted volume disappears. StatefulSet creates a new PVC (new name), which binds to a fresh empty PV. Postgres initialises from scratch. All data permanently gone. No recovery without external backup (pg_dump). reclaimPolicy:Delete also destroys the underlying storage.

**Q3: HPA not scaling despite 100% CPU**
Vela's answer:
- Cause 1: Metrics Server not returning data → HPA shows `<unknown>/50%` → diagnose with `kubectl describe hpa` (FailedGetResourceMetric event) and `kubectl top pods`
- Cause 2: Resource requests set too high → new pods unschedulable → diagnose with `kubectl describe hpa` (ScalingLimited) and `kubectl get events | grep FailedScheduling`

## Key Takeaways
1. `kubectl delete all` intentionally spares PVCs — storage is protected from broad deletes
2. StatefulSet's two core guarantees: stable network identity + stable storage binding
3. HPA requires metrics-server, resource requests (denominator), and schedulable capacity — remove any one and the loop breaks
4. Readiness probes are the missing piece in this capstone's YAML — needed before Act 3 rolling deployments
5. Numbered manifest files (01-, 02-...) make apply order explicit and readable
