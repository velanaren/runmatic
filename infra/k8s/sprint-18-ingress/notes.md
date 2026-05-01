# Sprint 18 — Ingress — Notes

## Phase 1 — The Hook
**Claude's Explanation:** Ingress is Sprint 09's Nginx pattern (browser → Nginx → proxy
to API) elevated to the cluster level. The Ingress controller is Nginx running as a pod
inside K8s. The Ingress resource is its routing rules — equivalent to nginx.conf location
blocks. NodePort = one port per service (hacky, insecure, unscalable). Ingress = one
entry point, hostname and path-based routing to any service.

**First Test:** `kubectl get pods -A | grep -i ingress` — confirmed nginx ingress
controller running. `kubectl get ingressclass` — confirmed `nginx` is the class name.

**My Result:** nginx ingress controller present. ingressClassName: nginx confirmed.

---

## Phase 2 — The Build
**Done Condition:** Browser loads Runmatic UI at runmatic.local. API responds at
runmatic.local/api/runbooks.

**My Work:**
- `frontend-deployment.yaml` — Deployment for runmatic-frontend image, port 3000
- `frontend-service.yaml` — ClusterIP service on port 3000
- `ingress.yaml` — Ingress with two path rules: /api → api-service:8000, / → frontend-service:3000

**Key observations during build:**
- Initial image set to `nginx:alpine` — wrong. Should be `runmatic-frontend:latest` (the built image)
- `imagePullPolicy: Never` required (Docker Desktop — images in local daemon, not registry)
- Used `docker tag sprint-11-restart-policies-frontend:latest runmatic-frontend:latest`
  (no rebuild needed — same image, Docker Desktop sees it immediately)
- Removed `rewrite-target: /` annotation — it rewrites ALL paths to `/`, breaking the API
- `pathType: Prefix` for /api — correct. Matches /api, /api/runbooks, /api/anything
- app/frontend/nginx.conf crashed K8s frontend pod: `host not found in upstream "api"` —
  Nginx resolves upstreams at startup. Fixed by adding `resolver 127.0.0.11` +
  `set $api_upstream` variable (defers DNS resolution to request time)
- Redis not deployed in K8s — caused login 500. Deployed redis.yaml to fix.
- ConfigMap had typo: `REDIS_URL=redis://rediss:6379/0` (rediss → redis)

**Result:** `kubectl describe ingress runmatic-ingress` showed Address: localhost,
both backends with endpoints. Browser confirmed runmatic.local loads Runmatic UI.

---

## Phase 3 — The Challenge
**Claude's Challenge:** Update Ingress path from `/api` to `/v2/api`. Hit
`runmatic.local/v2/api/runbooks`. Diagnose why it returns 404 and fix it.

**My Investigation:**
```bash
curl -v http://runmatic.local/v2/api/runbooks
# HTTP/1.1 404 Not Found — {"detail":"Not Found"}
```
- 404 came from the API itself (FastAPI JSON response), not the Ingress (which would return HTML)
- Ingress routed correctly: /v2/api matched, forwarded to api-service
- But the path arrived at the API pod as `/v2/api/runbooks` — FastAPI has no routes there
- All FastAPI routes have `/api` prefix: `/api/runbooks`, `/api/services`, etc.

**Fix — path rewrite with regex capture group:**
```yaml
annotations:
  nginx.ingress.kubernetes.io/rewrite-target: /api/$2
  nginx.ingress.kubernetes.io/use-regex: "true"
spec:
  rules:
    - host: runmatic.local
      http:
        paths:
          - path: /v2/api(/|$)(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: api-service
                port:
                  number: 8000
```

- `(/|$)(.*)` — capture group 1: the slash or end; capture group 2: everything after
- `$2` — rewrites to `/api/runbooks` (strips the `/v2` prefix)
- `ImplementationSpecific` — required when using regex paths
- `use-regex: "true"` — enables regex matching in nginx ingress

**Result:** `curl http://runmatic.local/v2/api/runbooks` returned 4 runbooks. ✓

---

## Phase 4 — Explanation
**Claude's Question:** Explain Ingress to a support engineer who's been using NodePort.

**My Answer:**
NodePort gives one port per service — 10 services = 10 ports to manage, document,
and firewall. No hostname routing, no TLS, no smart routing.

Reception desk analogy: NodePort = 50 separate doors in the office building's outer wall.
Ingress = one reception desk at the main entrance, routes visitors to the right floor.

Ingress has two parts: Resource (routing rules — the YAML) and Controller (the running
Nginx pod that reads and enforces those rules). Law vs enforcement. Rules vs the police.

**Claude's Feedback:** Excellent on NodePort gaps and the two-component model. Missed:
controller watches K8s API continuously — change ingress.yaml, controller detects and
reloads its nginx.conf automatically within seconds (reconciliation loop).

---

## Key Takeaways
1. Ingress = one cluster entry point. NodePort = one port per service. The difference matters at scale.
2. Ingress resource (YAML routing table) + Ingress controller (running Nginx pod) — two separate things.
3. Paths pass through UNCHANGED by default. `rewrite-target` is only needed when the backend doesn't expect the full path.
4. `pathType: Prefix` matches the path and everything under it. `Exact` matches only the exact string.
5. `ImplementationSpecific` + `use-regex: "true"` required for regex capture groups in path rules.
6. Nginx resolves upstream hostnames at startup — not at request time. Use `resolver` + `set $var` to defer.
7. ingressClassName must match what the controller advertises (`kubectl get ingressclass`).
