# Sprint 13 — Kubernetes Mental Model
**Score:** 19/20  (Concept: 9/10 | Execution: 9/10 | Speed: +1)
**Date:** 2026-04-22
**Duration:** Approx 30 min

---

## What You Got Right
1. **Reconciliation loop** — "Replaces them if they quit, keeps the boxes stacked forever, without you watching." That sentence captures the entire K8s control loop in plain English. It's precise, not just vague.
2. **Pod co-location reasoning** — You named the actual problem pods solve: two containers that need shared network/storage must land on the same node. If K8s scheduled containers individually, there'd be no guarantee of co-location. That's a sophisticated answer — you explained why the abstraction exists, not just that it exists.
3. **Ownership chain investigation** — Found `ownerReferences` in the pod YAML unprompted, traced Deployment → ReplicaSet → Pod, read the Events section to reconstruct the exact timeline. That's how a real K8s engineer investigates — follow the object graph.

## What You Missed
1. **Control plane component names** — You understood what each component does (from the explain session) but when asked to explain K8s behaviour in the Phase 4 question, the named components didn't appear. In an interview: "The controller manager runs a reconciliation loop comparing desired state in etcd to actual state on the nodes" is stronger than the facility manager analogy alone. Use both.
2. **Live reconciliation observation** — Didn't use `kubectl get pods -w` during the delete to watch the replacement happen in real time. When you see the old pod hit `Terminating` and the new one hit `ContainerCreating` simultaneously — that millisecond overlap makes the reconciliation loop visceral. Do this in Sprint 14.

## Carry Forward
Labels and selectors are the connective tissue of the entire K8s object model. A Deployment doesn't track its pods by name — it tracks them by label. The `selector` in the Deployment spec must match the `labels` in the pod template. Get that wrong and the Deployment creates pods it can never find — orphaned pods running forever. In Sprint 14, write the selector first, then match the labels to it.

## What This Teaches About Production Systems
The reconciliation loop isn't just a Kubernetes feature — it's the correct mental model for any self-healing system. Every time you've been paged to manually restart a crashed service, you were acting as the controller. K8s replaces that manual loop with an automated one running every few seconds across every object in the cluster. The implication: in a production K8s cluster, a pod dying is not an incident — it's a normal event. The real incidents are when the reconciliation loop itself can't converge: node out of capacity, image pull failing, health check never passing. Sprint 14 onwards, your job shifts from "restart the thing" to "figure out why the controller can't make it healthy."

## Bonus Challenge
Unlocked: Yes  
Attempted: Yes  
Result: 10/10 — Correctly identified finalizers as the mechanism. Went further: simulated the entire scenario from scratch, applied a real finalizer, reproduced the stuck pod, fixed it by nullifying via patch. Proved the concept rather than just explaining it.
