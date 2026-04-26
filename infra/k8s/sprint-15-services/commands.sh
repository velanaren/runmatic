#!/bin/bash
# Sprint 15 — Services & DNS
# Goal: expose Runmatic services via stable DNS names so pods can find
#       each other without hardcoded IPs that change on every restart
# Key question I was exploring: how does the API find postgres when pod IPs change?

# === Phase 1 — Prove the instability Services solve ===

# why: observe pod IPs before deletion — these are what would be hardcoded without Services
kubectl get pods -o wide

# why: delete one API pod to force a replacement — watch the new IP differ
kubectl delete pod runmatic-api-78d85985f-7qhrj

# why: confirm the replacement pod got a different IP
kubectl get pods -o wide

# === Phase 2 — Apply the Services ===

# why: deploy postgres as a simple Deployment (no PVC yet — Sprint 17 handles persistence)
kubectl apply -f infra/k8s/sprint-15-services/postgres-deployment.yaml

# why: create ClusterIP Service for postgres — internal DNS name for the API to use
kubectl apply -f infra/k8s/sprint-15-services/postgres-service.yaml

# why: check pod labels before writing the api-service selector — must match exactly
kubectl get pods --show-labels

# why: create NodePort Service for the API — allows laptop browser access during development
kubectl apply -f infra/k8s/sprint-15-services/api-service.yaml

# why: confirm both services exist with assigned ClusterIPs
kubectl get services

# why: endpoints must show real pod IPs, not <none> — this proves selector matched pod labels
kubectl get endpoints

# === Phase 3 — DNS test inside the cluster ===

# why: the API image is slim and doesn't have nslookup — use a debug pod instead
kubectl run dns-debug --image=busybox --restart=Never -- sleep 3600

# why: exec into busybox to test DNS resolution from inside the cluster
kubectl exec -it dns-debug -- sh

# inside the pod:
# why: prove K8s DNS resolves the service name to the ClusterIP
# nslookup postgres-service
# what I saw: postgres-service.default.svc.cluster.local → 10.102.103.97 (the ClusterIP)

# why: see which nameserver pods use — kube-dns at 10.96.0.10
# cat /etc/resolv.conf

# === Phase 4 — Verify API can reach postgres via DNS ===

# why: create a tunnel from laptop to the api-service (Docker Desktop doesn't expose NodePort directly)
kubectl port-forward svc/api-service 8000:8000

# why: confirm the API resolves postgres-service and connects to the database
curl localhost:8000/health
# what I saw: {"status":"degraded","db":"connected","cache":"disconnected",...}
# db: connected — DNS resolution and postgres connection working

# === Break-fix — Diagnosing selector/label mismatch ===

# why: simulate a mismatch by applying a deployment with a typo in labels
# (runmatic-postgress instead of runmatic-postgres)
kubectl apply -f infra/k8s/sprint-15-services/postgres-deployment.yaml  # with typo in labels

# why: endpoints immediately goes to <none> when selector doesn't match any pod labels
kubectl get endpoints

# why: production diagnostic — extract actual pod labels without looking at YAML files
kubectl get pod runmatic-postgress-65b4b454c6-j4s8p -o jsonpath='{.metadata.labels}'
# what I saw: {"app":"runmatic-postgress","pod-template-hash":"65b4b454c6"}

# why: extract Service selector to compare directly against pod labels
kubectl get svc postgres-service -o jsonpath='{.spec.selector}'
# what I saw: {"app":"runmatic-postgres"}
# mismatch identified: one character difference — that's all it takes for <none>

# === Bonus — Fake pod infiltrates Service endpoints ===

# why: simulate a rogue pod with matching labels but wrong credentials
kubectl run fake-postgres \
  --image=postgres:15 \
  --labels="app=runmatic-postgres" \
  --port=5432 \
  --env="POSTGRES_PASSWORD=wrongpassword" \
  --env="POSTGRES_DB=wrongdb" \
  --env="POSTGRES_USER=wronguser"

# why: confirm fake pod IP was added to endpoints immediately (no readiness check)
kubectl get endpoints
# what I saw: postgres-service now has two IPs — real and fake both in rotation

# why: force all traffic to the fake pod by deleting the real postgres Deployment
kubectl delete deployment runmatic-postgres

# why: confirm only the fake pod IP remains
kubectl get endpoints

# why: prove the API fails when only the fake pod is in the endpoint list
curl localhost:8000/health
# what I saw: {"db":"disconnected","db_error":"password authentication failed for user runmatic"}

# === Cleanup ===

# why: remove the debug pods used for testing
kubectl delete pod dns-debug
kubectl delete pod fake-postgres
