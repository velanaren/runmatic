# Sprint 09 — Frontend Container — Notes

## Phase 1 — The Hook
**Claude's Explanation:** 
The frontend is two separate problems. Problem 1: React is TypeScript source code — browsers don't understand TypeScript. You need `npm run build` to compile everything into static HTML/CSS/JS files. Just a folder, no process running. Problem 2: Serving those files and routing API calls. The browser can't use Docker DNS. Nginx is the translator — it serves the static files AND proxies `/api/*` requests to the API container using Docker DNS. One address for the browser, two destinations behind it.

**First Test:** 
Checked if `app/frontend/dist` existed — it didn't (not built yet). Ran `npm run build` to compile the React app. Output: `dist/index.html` (0.75 kB), `dist/assets/` with CSS (14.55 kB) and JS bundles (163.82 kB + 172.40 kB). Total: ~351 KB for the entire UI.

**My Result:**
The build creates static files that Nginx will serve. Checked `app/frontend/nginx.conf` and found the key line: `proxy_pass http://api:8000;` — this is how Nginx forwards `/api/*` requests to the API container by name.

## Phase 2 — The Build
**Done Condition:** Browser at localhost:3000 shows Runmatic UI. Creating a runbook stores it in the database.

**My Work:**
Created `infra/act1/sprint-09-frontend/Dockerfile.frontend`:
- Base image: `node:18-alpine`
- Installed `nginx` via `apk add --no-cache nginx`
- Copied `package.json` and `package-lock.json`, ran `npm ci`
- Copied frontend source code, ran `npm run build` to create `dist/`
- **Key discovery:** Nginx expects static files at `/usr/share/nginx/html`, but the build output was in `/app/dist`. Added:
  ```dockerfile
  RUN mkdir -p /usr/share/nginx/html
  RUN cp -r dist/* /usr/share/nginx/html/
  ```
- Copied `nginx.conf` to `/etc/nginx/http.d/default.conf`
- Created `/run/nginx` directory (required for nginx PID file)
- Exposed port 3000
- CMD: `nginx -g "daemon off;"` (foreground mode)

Updated `docker-compose.yml`:
- Added `frontend` service
- Build context: `../../../app/frontend`, dockerfile path: `../../infra/act1/sprint-09-frontend/Dockerfile.frontend`
- Port mapping: `3001:3000` (3000 was in use by Grafana locally)
- Depends on `api` with `condition: service_healthy`

**Key observations:**
- Initial `docker compose up` succeeded, but `localhost:3001` returned 500 error. Root cause: static files weren't in the location Nginx was serving from (`/usr/share/nginx/html`).
- After adding the `mkdir` and `cp` commands, the UI loaded successfully.
- The login page appeared, but authentication failed initially due to an unrelated API bcrypt library bug (fixed in Mode A by updating `requirements.txt` to pin `bcrypt==4.0.1`).

## Phase 3 — The Challenge
**Claude's Challenge:**
Trace one API request from browser → Nginx → API container using browser DevTools and `docker compose logs`.

**My Investigation:**
Clicked on "Runbook 2" in the UI. Browser DevTools Network tab showed:
- Request URL: `http://localhost:3001/api/runbooks/2`
- Method: `GET`
- Status: `200 OK`
- Response size: 343 bytes

Checked `docker compose logs frontend`:
```
nginx1 | [REDACTED_IP] - - [13/Apr/2026:12:10:27 +0000] "GET /api/runbooks/2 HTTP/1.1" 200 343 "http://localhost:3001/runbooks/2" "Mozilla/5.0..."
```
Nginx received the request from the browser, processed it, and returned 200 OK with 343 bytes.

Checked `docker compose logs api`:
```
api1 | INFO [sqlalchemy.engine.Engine] SELECT runbook_steps.runbook_id, runbook_steps.id, ...
api1 | INFO [sqlalchemy.engine.Engine] WHERE runbook_steps.runbook_id IN ($1::INTEGER)
api1 | INFO [sqlalchemy.engine.Engine] [cached since 119.1s ago] (2,)
```
The API queried PostgreSQL for runbook steps (runbook_id = 2). No HTTP request log from the API — just the SQL query execution.

**Full trace:**
1. Browser sends `GET http://localhost:3001/api/runbooks/2`
2. Nginx (frontend container) receives the request
3. Nginx's `proxy_pass http://api:8000` directive forwards it to the API container via Docker DNS
4. API container queries PostgreSQL for runbook data
5. API returns JSON response (343 bytes)
6. Nginx forwards the response to the browser
7. Browser displays the runbook

**Key insight:** The browser only knows about `localhost:3001`. It never talks directly to the API. Nginx is the bridge between the host network (where the browser lives) and the Docker internal network (where the API lives).

## Phase 4 — Explanation
**Claude's Question:**
Why does the browser send requests to `localhost:3001` instead of `localhost:8000`? What is Nginx actually doing when it sees a request to `/api/runbooks/2`? Why can't the browser just talk to the API container directly?

**My Answer:**
The browser cannot talk to the API container because it is inside a container and it has a different network. Nginx acts as a bridge between browser and the container, this is done using port mapping. Nginx does 2 functions: 1) When we build the app using npm run build, React just compiles the files — these are static files and they can't be delivered to the browser. Nginx does this job; when requested it delivers the static files to the browser through HTTP. 2) When it receives an API request, Nginx's `proxy_pass http://api:8000` uses Docker DNS to find the API container.

**Claude's Feedback:**
Concept: 9/10 — Nailed the network boundary (Docker vs host), Nginx's dual role (static files + API proxy), and Docker DNS resolution. Minor wording imprecision on "static files can't be delivered" (meant: need a web server to serve them via HTTP).

Execution: 10/10 — Dockerfile works, independently discovered the dist/ copy requirement, traced the full request path, adapted to port conflict.

Speed: 0 — Sprint exceeded 35 min due to app bugs (bcrypt, seed data).

Total: 19/20

## Key Takeaways
1. **Network isolation**: The browser runs on the host network. Docker containers run on an internal bridge network. They cannot communicate directly — a published port + reverse proxy is required.
2. **Nginx's dual role**: Serves static compiled assets (HTML/CSS/JS from `npm run build`) AND proxies API requests to backend services using Docker DNS.
3. **Docker DNS**: Inside the Docker network, containers can find each other by service name (`api`, `postgres`, `redis`). Outside Docker (e.g., the browser), only `localhost` + published ports are accessible.
4. **Build vs runtime**: The React app is compiled at build time (inside the Dockerfile). At runtime, Nginx serves the pre-compiled static files — no Node.js needed.
5. **Request tracing**: Browser DevTools + `docker compose logs` reveal the full path of a request through multiple layers. The 343-byte response size in Nginx logs matches the JSON payload size.
6. **Port mapping**: `3001:3000` means "publish container port 3000 to host port 3001." The container still listens on 3000 internally; the host accesses it via 3001.
