#!/bin/bash
# Sprint 16 — ConfigMaps & Secrets
# Goal: remove all hardcoded env vars from Deployment YAMLs
# Key question: what's the difference between ConfigMap and Secret, and what are the limits of each?

# === Phase 1 — See the problem ===

# why: prove that hardcoded env vars are visible to anyone with kubectl access
kubectl apply -f infra/k8s/sprint-15-services/
kubectl describe deployment runmatic-api
# what I saw: DATABASE_URL with plaintext password, SECRET_KEY in plaintext — visible in describe output

# === Phase 2 — Build the config objects ===

# why: base64 encode each sensitive value before putting it in a Secret
echo -n "devpassword" | base64
echo -n "dev-secret-key" | base64
echo -n "postgresql+asyncpg://runmatic:devpassword@postgres-service:5432/runmatic" | base64

# why: apply ConfigMap and Secret before Deployments that reference them
kubectl apply -f infra/k8s/sprint-16-configmaps-secrets/configmap.yaml
kubectl apply -f infra/k8s/sprint-16-configmaps-secrets/secret.yaml

# why: verify ConfigMap contents look correct before referencing them in pods
kubectl get configmap runmatic-config -o yaml

# why: verify Secret was stored (values will appear base64 encoded)
kubectl get secret runmatic-secrets -o yaml

# why: apply updated Deployments that use valueFrom instead of hardcoded value
kubectl apply -f infra/k8s/sprint-16-configmaps-secrets/api-deployment.yaml
kubectl apply -f infra/k8s/sprint-16-configmaps-secrets/postgres-deployment.yaml

# why: confirm env vars now show references, not plaintext values
kubectl describe deployment runmatic-api
# what I saw: <set to the key 'DATABASE_URL' in secret 'runmatic-secrets'>  Optional: false

# why: confirm pods are actually running (misconfigured secretKeyRef causes pod failure)
kubectl get pods

# === Phase 3 — Prove Secrets aren't encrypted ===

# why: demonstrates that base64 is encoding not encryption — recoverable by anyone with get access
# what I saw: dev-secret-key — full plaintext, under one minute, no hints
kubectl get secret runmatic-secrets -o jsonpath='{.data.SECRET_KEY}' | base64 --decode

# === Bonus Challenge — ConfigMap update doesn't reach running pods ===

# why: confirm current REDIS_URL inside a running pod
kubectl exec -it runmatic-api-56ccf66db4-48jlb -- sh -c "echo \$REDIS_URL"
# what I saw: redis://redis:6379/0

# why: apply the updated ConfigMap (changed redis to rediss to simulate an update)
kubectl apply -f infra/k8s/sprint-16-configmaps-secrets/configmap.yaml

# why: prove the running pod still has the old value — env vars frozen at pod start
kubectl exec -it runmatic-api-56ccf66db4-48jlb -- sh -c "echo \$REDIS_URL"
# what I saw: redis://redis:6379/0 (unchanged — env vars are frozen at pod start)

# why: force a rolling restart so new pods pick up the updated ConfigMap
# rolling update — no downtime, pods cycle through one by one
kubectl rollout restart deployment/runmatic-api

# why: confirm new pods are running and have the updated value
kubectl get pods
kubectl exec -it runmatic-api-6c499bbd4f-ck8n6 -- sh -c "echo \$REDIS_URL"
# what I saw: redis://rediss:6379/0 — new value confirmed
