# Sprint 20 — Act 2 Capstone
**Score:** 26/30  (Architecture: 9/10 | Execution: 10/10 | YAML Quality: 7/10)
**Date:** 2026-05-05
**Duration:** Approx 35 min

---

## What You Got Right

**PVC deletion consequence chain** — You traced exactly what happens: pod crashes when the volume disappears, StatefulSet controller creates a new PVC, a fresh empty PV is bound, postgres initialises from scratch, all data is permanently gone. You even called out `reclaimPolicy: Delete` destroying the underlying storage. That's a senior-level answer — most people stop at "data is lost."

**StatefulSet identity reasoning** — You named both guarantees that matter for Runmatic: stable pod name (runmatic-postgres-0 always comes back as runmatic-postgres-0) and stable PVC binding (always connects to the same volume). You framed it correctly as a binding between pod identity and storage — not just "it has persistent data."

**HPA diagnosis commands** — Both causes came with exact diagnostic paths: `kubectl describe hpa` for FailedGetResourceMetric events, `kubectl top pods` for missing metrics, `kubectl get events | grep FailedScheduling` for unschedulable pods. Diagnosis-first thinking.

## What You Missed

**StatefulSet ordered startup/shutdown** — StatefulSets also guarantee ordered creation (postgres-0 before postgres-1) and ordered termination (postgres-1 before postgres-0). For a single-replica postgres this doesn't matter today, but in a multi-replica cluster setup it's the reason read replicas don't race the primary to initialise.

**HPA Cause 2 framing** — The more common production failure isn't "resource requests too high" — it's "resource requests missing entirely." HPA calculates utilisation as `current_usage / request`. If requests are absent, the denominator is undefined and the HPA shows `<unknown>/50%`. "Requests too high causing unschedulable pods" is real but rarer. Worth knowing the distinction.

**Readiness probes missing from all deployments** — None of the capstone manifests have `readinessProbe` defined. K8s marks a pod Ready the moment the container starts — not when the app is actually ready to serve traffic. During a rolling update, the new API pod can receive requests before it's connected to postgres, causing a brief window of 500s. Every deployment in a production cluster needs a readiness probe.

**No resource limits on postgres** — The StatefulSet has no `resources` block. Postgres has no memory ceiling. On a shared cluster, an unconstrained postgres can consume all available memory, causing OOM kills on other pods. A conservative `limits.memory: 512Mi` prevents that.

## Carry Forward

Readiness probes before Act 3's first deployment sprint. The pattern is simple for the API:
```yaml
readinessProbe:
  httpGet:
    path: /health
    port: 8000
  initialDelaySeconds: 5
  periodSeconds: 10
```
Sprint 21 (GitHub Actions CI) will build images and trigger deployments — rolling updates without readiness probes create exactly the failure mode CI is supposed to prevent.

## What This Teaches About Production Systems

A Kubernetes cluster with no readiness probes is a system that technically self-heals but injures users during every recovery. The scheduler brings pods back. The load balancer routes to them. But if the pod starts before its dependencies are ready, the first 10 seconds of traffic hits an app with no database connection. Readiness probes are the contract between your app and the scheduler: "Don't send me traffic until I say I'm ready." Without them, K8s is self-healing at the infrastructure layer while silently breaking at the application layer — the worst kind of failure because it looks healthy in `kubectl get pods`.

## Act 2 Capstone Result
Score: 26/30 ✅ — Act 3 Platform Engineering unlocked
Unlock threshold: 24/30
Act 3 starts: Sprint 21 — GitHub Actions CI
