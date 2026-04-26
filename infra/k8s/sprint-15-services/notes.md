# Sprint 15 — Services & DNS — Notes

## Phase 1 — The Hook
**Claude's Explanation:** Pods are ephemeral — every restart brings a new IP. A Kubernetes Service is the stable virtual IP and DNS name in front of those moving pods. Analogy: Splunk search head connecting to an indexer cluster VIP, not to individual indexer IPs.

**First Test:** `kubectl get pods -o wide` to observe pod IPs, then `kubectl delete pod <api-pod>` and re-run to see the replacement pod get a new IP.

**My Result:** Confirmed — replacement pod received a different IP. The instability that Services solve was made visible.

---

## Phase 2 — The Build
**Done Condition:** `kubectl get endpoints` shows real pod IPs (not `<none>`) for both api-service and postgres-service. DNS resolves inside the cluster. API /health returns `"db": "connected"`.

**My Work:**
- `infra/k8s/sprint-15-services/postgres-deployment.yaml` — simple postgres:15 Deployment with POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD env vars
- `infra/k8s/sprint-15-services/postgres-service.yaml` — ClusterIP Service, selector `app: runmatic-postgres`, port 5432
- `infra/k8s/sprint-15-services/api-service.yaml` — NodePort Service, selector matching API pods, nodePort 30080

**Key Observations:**
- `kubectl get pods --show-labels` was needed to confirm exact label values before writing the Service selector
- The API image (slim production image) did not have `nslookup`. Spun up a `dns-debug` busybox pod to test DNS resolution instead
- DNS test result: `nslookup postgres-service` returned `postgres-service.default.svc.cluster.local → 10.102.103.97` (the Service ClusterIP)
- Updated API Deployment's `DATABASE_URL` to use `postgres-service` hostname
- `kubectl port-forward svc/api-service 8000:8000` → `curl localhost:8000/health` → `"db": "connected"`

---

## Phase 3 — The Challenge
**Claude's Challenge:** `kubectl get endpoints` shows `<none>` for a Service. The worker pods are Running. What's wrong, how do you diagnose without guessing?

**My Investigation:**
- Simulated the scenario by introducing a typo in the postgres Deployment labels (`runmatic-postgress` vs `runmatic-postgres`)
- Observed `postgres-service` endpoints immediately went to `<none>`
- Diagnostic commands used:
  ```bash
  kubectl get pod runmatic-postgress-65b4b454c6-j4s8p -o jsonpath='{.metadata.labels}'
  # → {"app":"runmatic-postgress","pod-template-hash":"..."}

  kubectl get svc postgres-service -o jsonpath='{.spec.selector}'
  # → {"app":"runmatic-postgres"}
  ```
- Mismatch confirmed: one character difference, endpoints empty
- Second experiment: changed only metadata.name (not labels) → a second pod was added to endpoints because labels still matched. Key insight: Service selects on labels only, not on Deployment name.

---

## Phase 4 — Explanation
**Claude's Question:** "What is a Kubernetes Service, why does it exist, and what's the difference between ClusterIP and NodePort?"

**My Answer:**
Pods are ephemeral — new IP on every restart. Services provide a stable DNS name and virtual IP. When the API calls `postgres-service`, the nameserver (kube-dns at 10.96.0.10, visible in /etc/resolv.conf) resolves the name to the Service ClusterIP, which routes to whatever pods are currently in the endpoint list based on selector/label matching.

ClusterIP = intercom inside an office building. Internal only. NodePort = a designated entrance gate (specific port, 30000–32767) that lets traffic from outside the cluster reach a service internally.

**Claude's Feedback:** 9/10 concept. One gap: DNS resolves to the Service ClusterIP (a virtual IP), not directly to pod IPs. kube-proxy handles the translation from ClusterIP to actual pod IP. Pod IPs are the final destination, not what DNS returns.

---

## Bonus Challenge
**Scenario:** API returns 503 intermittently. Both pods show Running. Both IPs in endpoints. Logs show one pod handling requests, the other showing nothing.

**My Investigation:**
- Created a `fake-postgres` pod with matching labels (`app: runmatic-postgres`) but wrong credentials
- Both the real and fake postgres IPs appeared in `postgres-service` endpoints immediately
- With both pods, `/health` showed `db: connected` (sometimes hitting the real pod)
- Deleted the real postgres Deployment — only fake pod remaining in endpoints
- `/health` returned: `"db": "disconnected"`, `"db_error": "password authentication failed for user runmatic"`

**Root Cause:** No readiness probe on the postgres Deployment. K8s added the pod to endpoints as soon as the process started, with no validation of whether it could actually serve real traffic. The Service load-balanced to both pods — one real, one fake.

**Fix:** Readiness probe on the postgres pod that verifies actual connectivity. A failing probe removes the pod's IP from the Service endpoint list, preventing bad traffic routing.

**Score:** 10/10

---

## Key Takeaways
1. A Service's ClusterIP is stable — pod IPs change, the Service IP never does
2. K8s DNS (`kube-dns`) resolves service names to ClusterIPs, not to pod IPs directly
3. The Service selector must exactly match pod labels — case-sensitive, no typos
4. `kubectl get endpoints` is the first command to run when a Service isn't routing traffic
5. Diagnostic pattern: `kubectl get pod -o jsonpath='{.metadata.labels}'` vs `kubectl get svc -o jsonpath='{.spec.selector}'`
6. Readiness probes gate endpoint inclusion — without one, any pod matching the selector receives traffic regardless of actual health
7. The full DNS name for a Service is `<name>.<namespace>.svc.cluster.local` — short name works within the same namespace
