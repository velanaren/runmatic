# Sprint 17 — Persistent Volumes & PVCs — Notes

## Phase 1 — The Hook

**Claude's Explanation:** Docker volumes work because everything lives on one machine. K8s breaks that — pods can land on any node, so you need storage that lives outside any single node. PersistentVolume (PV) = actual storage provisioned in the cluster. PersistentVolumeClaim (PVC) = a pod's request for storage. The cluster matches them.

Analogy: a PVC is your coat check ticket. Pod restarts? Show the ticket. Same coat. Same data.

**First Test:** `kubectl get pv,pvc -A`

**My Result:** No resources found — proved postgres has zero persistent storage right now. Every pod restart = database wipe.

---

## Phase 2 — The Build

**Done Condition:** PostgreSQL running as a StatefulSet with a PVC. Delete the pod. Recreate it. All data survives.

**Why StatefulSet instead of Deployment:**
- Deployment pods: random names (`runmatic-postgres-7d9bf-xk2p4`) — identity changes on restart
- StatefulSet pods: permanent names (`runmatic-postgres-0`) — name is stable, predictable
- StatefulSet guarantees same pod name → same PVC → same data, every time
- Requires a headless service (`clusterIP: None`) for pod DNS

**My Work:**
- Created `postgres-statefulset.yaml` with headless Service + StatefulSet
- YAML review round 1: 3 bugs found — spec nested under metadata, `ClusterIP` uppercase, template at wrong indent
- YAML review round 2: 1 bug remaining — `clusterIP` case fixed, template/volumeClaimTemplates indent fixed
- Final file applied cleanly

**StorageClass used:** `hostpath` (Docker Desktop default)

**Key observations:**
- Pod came up as `runmatic-postgres-0` (not a random hash)
- PVC `postgres-data-runmatic-postgres-0` STATUS: Bound, 1Gi
- Data survival proof: INSERT → delete pod (IP changed from .92 to .93, proving new pod) → SELECT → same row present

---

## Phase 3 — The Challenge

**Claude's Challenge:** Scale to 3 replicas, observe PVC creation. Scale back to 1, observe PVC orphaning. Scale back to 3, confirm PVCs reattach to same pod names. Answer: why do orphaned PVCs exist, are they safe to delete, what happens on scale-up?

**My Investigation:**
1. Scaled to 3 → pods `runmatic-postgres-0`, `-1`, `-2` created; events showed `create Claim ... success` before pod creation
2. Scaled to 1 → pods `-1` and `-2` deleted; `kubectl get pvc` showed all 3 PVCs still Bound
3. `kubectl describe pvc` → `Used By: <none>` for `-1` and `-2`
4. Scaled back to 3 → same PVC names reattached to same pod names; `Used By: runmatic-postgres-1` and `Used By: runmatic-postgres-2` confirmed

**Findings:**
- PVC lifecycle is decoupled from pod lifecycle — by design, for data safety
- When scaling up, StatefulSet reattaches existing PVCs by name convention (doesn't create new ones)
- Orphaned PVCs are safe to delete only after confirming `Used By: <none>` and verifying no needed data

---

## Phase 4 — Explanation

**Claude's Question:** Explain PersistentVolumes and PersistentVolumeClaims to a support engineer who has never heard of Kubernetes. 3 sentences. No lookups.

**My Answer:** Hotel room analogy — hotel rooms are PVs (actual storage), guest requests are PVCs (what a pod asks for). Guest requests "a double room" and the hotel matches to an available room. If no match, the guest waits.

**Claude's Feedback:**
- PV/PVC split and matching mechanism: correct
- Missing: lifecycle decoupling not stated (PVC survives pod deletion — proved but not said)
- Missing: StatefulSet identity binding — postgres-0 always gets postgres-data-postgres-0, not just any matching PVC. Hotel guests get any available double. StatefulSet pods get their own specific room.

---

## Key Takeaways

1. **PV = storage, PVC = request.** Cluster matches them. PVC stays Pending until a matching PV is available.
2. **StatefulSet pods have permanent names.** `postgres-0` always. Deployment pods have random hashes.
3. **PVCs don't die when pods die.** Intentional. Prevents accidental data loss. Creates orphaned storage if not managed.
4. **StatefulSet identity binding.** Same pod name reattaches to same PVC by naming convention on every restart/reschedule.
5. **Headless service is required.** `clusterIP: None` — gives each StatefulSet pod its own DNS entry. Different from the ClusterIP service used for routing.
6. **Orphaned PVC cleanup is manual.** K8s won't auto-delete PVCs on scale-down. Production operators audit with `kubectl get pvc -A | grep '<none>'`.
