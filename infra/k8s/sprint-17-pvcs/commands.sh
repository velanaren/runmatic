#!/bin/bash
# Sprint 17 — Persistent Volumes & PVCs
# Goal: give postgres durable storage that survives pod deletion in Kubernetes
# Key question: what is the difference between a PV, a PVC, and a StatefulSet?

# === PHASE 1 — Prove the problem exists ===

# why: if no PVCs exist, postgres has zero persistent storage right now
# what I saw: No resources found — confirmed ephemeral-only storage
kubectl get pv,pvc -A

# why: check what storage options the cluster offers before writing the YAML
# what I saw: hostpath (default) — Docker Desktop's built-in storage provisioner
kubectl get storageclass

# === PHASE 2 — Build: apply the StatefulSet + PVC ===

# why: remove the old Deployment first to avoid two sets of pods with the same labels
kubectl delete deployment runmatic-postgres

# why: apply both the headless service and StatefulSet together — they're a coupled unit
# what I saw: service/runmatic-postgres-headless created, statefulset.apps/runmatic-postgres created
kubectl apply -f postgres-statefulset.yaml

# why: watch the pod come up — confirm it gets a stable name (postgres-0, not a random hash)
# what I saw: runmatic-postgres-0 Running — no random suffix
kubectl get pods -o wide

# why: confirm the PVC was created and bound — this is the storage anchor
# what I saw: postgres-data-runmatic-postgres-0 STATUS: Bound, 1Gi, hostpath
kubectl get pvc

# === PHASE 2 — Prove data survives pod deletion ===

# why: insert test data before deleting the pod — gives us something to verify after restart
kubectl exec -it runmatic-postgres-0 -- psql -U runmatic -d runmatic -c \
  "CREATE TABLE runbooks (title TEXT, service TEXT, content TEXT);"

kubectl exec -it runmatic-postgres-0 -- psql -U runmatic -d runmatic -c \
  "INSERT INTO runbooks (title, service, content) VALUES ('PVC Test', 'postgres', 'survive this');"

kubectl exec -it runmatic-postgres-0 -- psql -U runmatic -d runmatic -c \
  "SELECT * FROM runbooks;"

# why: deleting the pod simulates a crash or rescheduling event
# what I saw: pod deleted, StatefulSet controller immediately created a new one
kubectl delete pod runmatic-postgres-0

# why: verify the replacement pod has the same name and a new IP (proof it's a new pod)
# what I saw: runmatic-postgres-0 Running — IP changed from .92 to .93, new pod, same name
kubectl get pods -o wide

# why: the data should still be there — PVC was never deleted, just detached and reattached
# what I saw: PVC Test row present — data survived pod deletion
kubectl exec -it runmatic-postgres-0 -- psql -U runmatic -d runmatic -c \
  "SELECT * FROM runbooks;"

# === PHASE 3 — The Challenge: PVC lifecycle vs pod lifecycle ===

# why: scale up to observe that each new pod gets its own PVC created automatically
kubectl scale statefulset runmatic-postgres --replicas=3

# why: see all 3 pods with stable names and individual IPs
kubectl get pods -o wide

# why: read StatefulSet events — shows 'create Claim' happens before 'create Pod'
# critical: PVC is created first, pod is created second and bound to it
kubectl describe statefulset runmatic-postgres

# why: scale down — observe what happens to PVCs when pods are removed
kubectl scale statefulset runmatic-postgres --replicas=1

# why: confirm pods 1 and 2 are gone but their PVCs remain
kubectl get pods -o wide
kubectl get pvc

# why: confirm orphaned PVCs — 'Used By: <none>' means pod is gone but storage persists
kubectl describe pvc

# why: scale back up — confirm same PVCs reattach to same pod names (not new volumes)
# what I saw: postgres-data-runmatic-postgres-1 reattached to runmatic-postgres-1
#             same VOLUME ID — proves it's the same physical storage
kubectl scale statefulset runmatic-postgres --replicas=3
kubectl get pods -o wide
kubectl get pvc

# why: final confirmation — 'Used By' populated again with correct pod names
kubectl describe pvc

# === CLEANUP — Scale back to 1 for sprint completion ===

kubectl scale statefulset runmatic-postgres --replicas=1
kubectl get pods
kubectl get pvc
