# Sprint 17 — Persistent Volumes & PVCs
**Score:** 17/20  (Concept: 7/10 | Execution: 9/10 | Speed: +1)
**Date:** 2026-04-29
**Duration:** Approx 35 min

---

## What You Got Right

1. **PV/PVC split and matching mechanism.** The hotel room analogy nailed the core abstraction: PVs are provisioned storage, PVCs are requests, the cluster matches them. Correctly identified pending state when no match exists.

2. **StatefulSet identity in practice.** You scaled to 3, observed three distinct PVCs created with pod-specific names, scaled back to 1, confirmed PVCs remained with `Used By: <none>`, then scaled back up and verified the same volumes reattached to the same pod names. You ran the full proof without prompting.

3. **Correct YAML construction after review.** All three issues (spec nesting, `clusterIP` case, template indent) were identified and fixed. The final file was clean — headless service and StatefulSet together, ConfigMap and Secret refs matching Sprint 16 names, correct mountPath for PostgreSQL, correct StorageClass for Docker Desktop.

---

## What You Missed

1. **Lifecycle decoupling absent from the verbal explanation.** You proved it in Phase 3 — PVCs survive pod deletion by design — but didn't say it in your 3-sentence answer. In production, this matters: orphaned PVCs accumulate storage cost silently. The sentence that signals you understand the tradeoff: "Deleting the pod doesn't delete the storage — that's intentional, but someone has to clean up orphaned PVCs manually."

2. **StatefulSet identity binding not articulated.** The hotel analogy has the guest getting any available double room on return. In a StatefulSet, `postgres-0` always gets `postgres-data-postgres-0` specifically — by naming convention, permanently. A Deployment would get any matching PVC. This is the exact reason databases need StatefulSets. You proved the behavior; you didn't state the rule.

---

## Carry Forward

StatefulSet identity binding: same pod name always reattaches to the same PVC. `postgres-0` → `postgres-data-postgres-0`. Always. This is what makes databases safe in K8s. In Sprint 20 Capstone, one mandatory question is: "Why is postgres a StatefulSet and the API a Deployment?" The answer is here — storage identity, not just pod identity.

---

## What This Teaches About Production Systems

PVC orphan accumulation is a real cost driver on cloud Kubernetes. On EKS with gp3 EBS volumes, each 1Gi PVC costs roughly $0.08/month — trivial per PVC, catastrophic at scale. A team running 50 StatefulSets with frequent scale operations can accumulate hundreds of orphaned PVCs invisibly. No alert fires. No pod crashes. The storage just sits there, billed monthly. Production operators add PVC audits to their runbooks: `kubectl get pvc -A | grep '<none>'` as a scheduled check. You built the mental model for that today.

---

## Bonus Challenge
Unlocked: Yes (17/20)
Attempted: Yes
Result:    7/10 — Correctly identified reclaimPolicy: Retain rebound scenario and subPath fix.
           Missed: actual cause was filesystem artifacts (lost+found) in fresh hostpath directory;
           PGDATA env var as the PostgreSQL-native fix; StorageClass reclaimPolicy is immutable
           (patch the PV directly, not the StorageClass).
