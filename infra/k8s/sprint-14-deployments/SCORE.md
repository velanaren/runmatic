# Sprint 14 — Pods & Deployments
**Score:** 18/20  (Concept: 9/10 | Execution: 9/10 | Speed: +0)
**Date:** 2026-04-23
**Duration:** Approx 45 min (10 min of forced wait from progressDeadlineExceeded)

---

## What You Got Right

**The "contract" mental model.** Framing a Deployment as a contract for desired state is precise and interview-ready. It immediately captures why Deployments exist — not just "run a container" but "maintain this state, always."

**Reconciliation loop explained correctly.** You named both the mechanism (K8s compares desired vs actual continuously) and both failure modes (pod crash and node failure). That's the full picture.

**Proactive maxSurge/maxUnavailable analysis.** Before triggering the rolling update you checked the strategy parameters and predicted the pod count behaviour during the rollout. That's what a senior SRE does — reason about the constraints before pulling the trigger, not after.

**Full failure path observed.** You waited for `progressDeadlineExceeded` (600s) and watched the pod go Terminating after `rollout undo`. Most people run `rollout undo` the moment they see the error. You observed the full timeout first.

---

## What You Missed

**The three-layer hierarchy.** In your Phase 4 explanation you described the Deployment watching pods directly. The actual chain is: Deployment → ReplicaSet → Pods. The Deployment manages ReplicaSets; the ReplicaSet manages pods. You saw this live (`kubectl get rs` showed `runmatic-api-5ffc7d7657`), but it didn't appear in the verbal explanation. In an interview, naming ReplicaSet as the intermediate layer distinguishes a practitioner from someone who read a tutorial.

**No readiness or liveness probes.** The pods show `1/1 Ready` because the process started — not because the application is healthy. Without probes, K8s cannot distinguish "process running" from "app ready to serve traffic." A pod with a crashed DB connection shows identical status to a healthy one. This becomes critical in Sprint 15 when the Service starts routing traffic to pods.

**progressDeadlineExceeded does not auto-rollback.** You correctly ran `rollout undo` manually — but worth making this explicit: K8s marks the Deployment as degraded and surfaces the error, but it does not automatically revert. The fix is always a human (or a CD pipeline) action.

---

## Carry Forward

In Sprint 15 your `DATABASE_URL` points to `postgres:5432`. That hostname doesn't exist in K8s — no Service has been created for postgres yet. The API pods show Running because the process started, but the app cannot connect to the database. Sprint 15 creates a ClusterIP Service for postgres, which registers the DNS name `postgres` inside the cluster. The moment that Service exists, your current Deployment will connect successfully without any change to the pod spec.

---

## What This Teaches About Production Systems

Rolling updates with maxUnavailable: 0 are the production default for stateless services — you accept slightly more capacity cost (maxSurge pods) in exchange for zero downtime. But that guarantee only holds if your readiness probe is honest. A pod that passes its readiness probe while serving 500s is worse than a pod that stays Unready — traffic routes to it anyway. The `progressDeadlineExceeded` timeout exists precisely to catch this: if new pods never become Ready, the rollout stalls, the old pods survive, and you get a deployment failure instead of a silent production incident. Watching the full 10-minute timeout today means you understand why that parameter exists.

---

## Bonus Challenge
Unlocked: Yes (18/20)
Attempted: Yes
Result: 10/10

**Scenario:** Resource requests set to cpu: 4000m, memory: 8Gi. Both pods stuck in Pending.

**Diagnosis (5/5):** Correct sequence — describe pod surfaced "Insufficient memory" in Events,
describe node exposed allocatable: 3.7Gi vs requested: 8Gi per pod. Manual math proved not
even one pod could schedule. Named the scheduler as the failure point (scheduling happens before
kubelet, before the app — no logs to read because the pod never landed on a node).

**Fix (5/5):** Reverted requests to 100m CPU / 128Mi memory, limits to 200m / 256Mi.
Applied cleanly. Both pods Running in 2 seconds. pod-template-hash returned to original
`5ffc7d7657` — identical pod template spec produces identical hash.

**Key insight added:** Requests are the scheduler's guarantee. The scheduler allocates based
on claimed requests, not actual usage. Limits can be overcommitted; requests cannot.
A node at 6% actual CPU can still reject a pod if its request capacity is already claimed.
