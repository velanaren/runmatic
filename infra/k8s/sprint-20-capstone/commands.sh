#!/bin/bash
# Sprint 20 — Act 2 Capstone
# Goal: Assemble and operate the full Runmatic K8s stack from a single directory
# Key question: Does everything we built across sprints 13-19 work together as a system?

# === PHASE 1 — Clear the slate ===

# why: know the starting state before applying anything — stale resources cause confusing errors
kubectl delete all --all -n default

# why: PVCs survive kubectl delete all intentionally — check what storage exists before deciding to keep or delete
kubectl get pvc -n default

# why: metrics-server is required for HPA in Phase 3 — verify it's healthy before getting to that proof
kubectl get deployment metrics-server -n kube-system

# === PHASE 2 — Assemble the capstone stack ===

# why: apply all 12 manifests in numbered order — config and secrets must exist before deployments reference them
kubectl apply -f infra/k8s/sprint-20-capstone/

# why: watch pods reach Running — postgres (StatefulSet) takes longest due to PVC rebinding
kubectl get pods -w

# why: verify PVC was rebound to existing storage — data should be present from previous sessions
kubectl exec runmatic-postgres-0 -- psql -U runmatic -d runmatic -c "SELECT count(*) FROM runbooks;"

# === PHASE 3 — PROOF 1: Self-Healing ===

# why: Deployment controller must replace deleted pods — this proves desired state reconciliation works
kubectl delete pod -l app=runmatic-api

# why: watch the replacement pods appear — should be Running within 2 seconds
kubectl get pods -w

# === PHASE 3 — PROOF 2: Ingress + Persistence ===

# why: confirm data survived cluster restart via PVC rebinding
kubectl exec runmatic-postgres-0 -- psql -U runmatic -d runmatic -c "SELECT id, title, status, created_at FROM runbooks ORDER BY created_at DESC;"

# why: seed demo user if needed (only if UniqueViolationError appears, user already exists)
kubectl cp create_user.py $(kubectl get pod -l app=runmatic-api -o jsonpath='{.items[0].metadata.name}'):/tmp/create_user.py
kubectl exec $(kubectl get pod -l app=runmatic-api -o jsonpath='{.items[0].metadata.name}') -- python /tmp/create_user.py

# browser: open http://runmatic.local — login: demo@runmatic.dev / demo1234

# === PHASE 3 — PROOF 3: Manual Scaling ===

# why: prove the Deployment controller responds to imperative scale commands immediately
kubectl scale deployment/runmatic-worker --replicas=3
kubectl get pods -l app=runmatic-worker

# why: scale back down — watch pods go through Terminating → Completed lifecycle
kubectl scale deployment/runmatic-worker --replicas=1
kubectl get pods -w

# === PHASE 3 — PROOF 4: HPA ===

# why: --kubelet-insecure-tls required for Docker Desktop — metrics-server can't reach kubelet otherwise
kubectl patch deployment metrics-server -n kube-system \
  --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

kubectl rollout status deployment/metrics-server -n kube-system

# why: generate CPU load on the api-service so HPA sees utilisation above 50% target
kubectl run load --image=busybox --restart=Never -- \
  sh -c "while true; do wget -q -O- http://api-service:8000/health; done"

# why: watch HPA respond — TARGETS column shows current/target, REPLICAS shows scale decisions
kubectl get hpa -w

# why: kill the load generator after observing scale-up to 3 replicas
kubectl delete pod load

# === VERIFICATION COMMANDS ===

# why: confirm ConfigMaps are populated and readable by pods
kubectl get configmap runmatic-config -o yaml

# why: confirm Secrets exist (values will be base64-encoded — not encrypted)
kubectl get secret runmatic-secrets -o yaml

# why: confirm HPA is correctly targeting the worker deployment with right thresholds
kubectl describe hpa runmatic-worker-hpa

# why: confirm StatefulSet pod identity and PVC binding
kubectl get statefulset runmatic-postgres -o yaml | grep -A5 volumeClaimTemplates
kubectl get pvc
