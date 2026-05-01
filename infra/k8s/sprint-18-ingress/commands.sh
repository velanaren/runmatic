#!/bin/bash
# Sprint 18 — Ingress
# Goal: expose Runmatic at runmatic.local via nginx Ingress controller
# Key question: how does one cluster entry point route to multiple services?

# === CHECK INGRESS CONTROLLER ===

# why: confirm nginx ingress controller is running before writing any YAML
kubectl get pods -A | grep -i ingress

# why: find the ingressClassName value to use in ingress.yaml
kubectl get ingressclass

# === APPLY SPRINT 18 MANIFESTS ===

# why: deploy frontend + service + ingress resource in one shot
kubectl apply -f infra/k8s/sprint-18-ingress/

# why: confirm Ingress was picked up — Address field and endpoint IPs confirm routing is live
kubectl describe ingress runmatic-ingress

# why: check pod status — empty endpoints in describe means pod isn't Running
kubectl get pods

# === DEBUGGING — FRONTEND CRASHLOOPBACKOFF ===

# why: docker logs doesn't work for K8s pods — kubectl logs is the right tool
kubectl logs runmatic-frontend-<pod-id>
# what I saw: host not found in upstream "api" — nginx resolves upstreams at startup

# why: after fixing nginx.conf (resolver + set $upstream), rebuild and reload
docker build -t runmatic-frontend:latest \
  -f infra/act1/sprint-10-multistage/Dockerfile.frontend \
  app/frontend/

kubectl rollout restart deployment runmatic-frontend
kubectl get pods -w

# === DEBUGGING — LOGIN 500 / REDIS NOT DEPLOYED ===

# why: Redis was never deployed in K8s — login calls store_session which needs Redis
kubectl get pods
kubectl get svc
# what I saw: no redis pod, no redis service

# why: check what REDIS_URL the API is actually using
kubectl exec runmatic-api-<pod-id> -- env | grep REDIS
# what I saw: redis://rediss:6379/0 — typo: rediss should be redis

# why: deploy Redis and fix the configmap
kubectl apply -f infra/k8s/sprint-18-ingress/redis.yaml
kubectl apply -f infra/k8s/sprint-16-configmaps-secrets/configmap.yaml
kubectl rollout restart deployment runmatic-api

# === VERIFY END TO END ===

# why: confirm runmatic.local resolves to localhost (Docker Desktop)
grep runmatic.local /etc/hosts
# if missing: echo "127.0.0.1 runmatic.local" | sudo tee -a /etc/hosts

# why: confirm frontend serves HTML
curl -s http://runmatic.local | head -5

# why: login and get a token for authenticated API calls
TOKEN=$(curl -s -X POST http://runmatic.local/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"demo@runmatic.dev","password":"demo1234"}' \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

# why: confirm /api routing works — returns runbook JSON
curl -s http://runmatic.local/api/runbooks \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool

# === PHASE 3 — PATH REWRITE CHALLENGE ===

# why: test /v2/api path — ingress routes it but API returns 404 (no routes at /v2/api/*)
curl -v http://runmatic.local/v2/api/runbooks
# what I saw: HTTP 404 {"detail":"Not Found"} — came from FastAPI, not nginx

# why: after adding rewrite-target annotation + regex capture group — verify rewrite works
kubectl apply -f infra/k8s/sprint-18-ingress/ingress.yaml
kubectl describe ingress runmatic-ingress
# what I saw: /v2/api(/|$)(.*) → api-service:8000, annotation: rewrite-target: /api/$2

# why: confirm rewrite sends /v2/api/runbooks → /api/runbooks at the pod
curl -s http://runmatic.local/v2/api/runbooks \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
# what I saw: 4 runbooks returned — rewrite working correctly

# === DIAGNOSTIC COMMANDS ===

# why: see all ingress objects and their addresses
kubectl get ingress -A

# why: full routing table with backend endpoint IPs
kubectl describe ingress runmatic-ingress

# why: check nginx ingress controller logs for sync errors
kubectl logs -n ingress-nginx \
  $(kubectl get pods -n ingress-nginx -o name | head -1) --tail=20

# why: check API logs when debugging 500 errors
kubectl logs runmatic-api-<pod-id> --tail=30
