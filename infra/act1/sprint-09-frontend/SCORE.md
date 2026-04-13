# Sprint 09 — Frontend Container
**Score:** 19/20  (Concept: 9/10 | Execution: 10/10 | Speed: 0)
**Date:** 2026-04-13
**Duration:** Approx 90 min (including app bug fixes in Mode A)

---

## What You Got Right
- **Network boundary understanding**: Explained clearly why the browser (host network) cannot directly reach the API container (Docker internal network) — different network contexts require a bridge.
- **Nginx's dual role**: Identified that Nginx both serves static compiled files (npm build output) AND proxies API requests to the backend using `proxy_pass http://api:8000`.
- **Docker DNS resolution**: Understood that `proxy_pass http://api:8000` works because Nginx runs inside the Docker network and can resolve the `api` hostname via Docker's embedded DNS.
- **Independent problem-solving**: Discovered that the compiled `dist/` files needed to be copied to `/usr/share/nginx/html` and added the necessary RUN commands to the Dockerfile without prompting.
- **Complete request trace**: Used browser DevTools (Network tab) + `docker compose logs` to trace a full request path from browser → Nginx → API → PostgreSQL and back, identifying each hop and the byte count.

## What You Missed
- **Minor wording imprecision**: "Static files can't be delivered to the browser" — you meant they need a web server to serve them via HTTP. Your understanding was correct; the phrasing was slightly unclear. Static files are just files — they need Nginx (or any web server) to serve them over HTTP so the browser can fetch them.

## Carry Forward
The browser → Nginx → API proxy pattern you traced in this sprint is architecturally identical to Kubernetes Ingress. In Sprint 15 (Services & DNS), you'll see: browser → Ingress → Service → Pod. Different tooling, same flow. The "bridge between networks" concept maps directly to how Ingress controllers route external traffic into a K8s cluster.

## What This Teaches About Production Systems
Nginx as a reverse proxy isn't just a Docker convenience — it's a production architecture pattern. In real systems, Nginx (or Envoy, or HAProxy) sits at the edge, handles TLS termination, routes traffic to internal services, serves static assets from CDN origins, and provides a single public endpoint for disparate backend services. 

The frontend container you built mirrors how companies like Vercel and Netlify deploy static sites: compile once (build step), serve via Nginx/CDN (runtime), proxy API calls to separate backend services. This separation means you can scale the frontend independently of the API, deploy them on different schedules, and serve static assets from a CDN while keeping the API behind a firewall.

Understanding that the browser lives outside Docker's network — and thus needs a published port + proxy to reach internal containers — is the same reason production apps use load balancers and API gateways. The browser (or any external client) cannot reach your private internal network directly. You control the entry point.

## Bonus Challenge
Unlocked: Yes (19/20 ≥ 16)
Attempted: Yes
Result: 9/10

**Challenge:** Frontend loads, static assets work, but API requests fail with CORS error. Browser console shows: "Access-Control-Allow-Origin header is not present." Direct curl to API works perfectly.

**Diagnosis (5/5):** Perfect identification of the root cause:
- Simulated the issue by fetching from browser console
- Identified origin mismatch: `http://127.0.0.1:3001` ≠ `http://localhost:3001`
- Recognized that browsers enforce same-origin policy (different origins even though same machine)
- Traced request flow: browser → Nginx → checks headers → missing `Access-Control-Allow-Origin` → blocks request
- Understood CORS is browser-enforced (curl bypasses it, no browser = no CORS check)
- Found Nginx has security headers but missing CORS headers

**Fix (4/5):** Correct concept and location, minor syntax precision:
- Correctly identified headers need to be added
- Proposed: `add_header Access-Control-Allow-Origin <appname> always`
- Precise syntax: `add_header Access-Control-Allow-Origin "http://127.0.0.1:3001" always;` or wildcard `"*"` for dev
- Also needed: API's `CORS_ORIGINS` env var must include both `localhost:3001` AND `127.0.0.1:3001`

**Key insight:** Independently discovered that `localhost` and `127.0.0.1` are treated as different origins by browsers despite pointing to the same machine. This origin mismatch is a common production issue when frontends and APIs are on different subdomains.

---

## Notes
- Port conflict: Grafana already using 3000 → frontend mapped to 3001 instead. Correct adaptation.
- App bugs encountered (bcrypt library incompatibility, seed script not in container) were resolved in Mode A. Not counted against sprint time conceptually, but clock elapsed.
- The `mkdir -p /usr/share/nginx/html` + `cp -r dist/* /usr/share/nginx/html/` discovery was excellent independent debugging.
