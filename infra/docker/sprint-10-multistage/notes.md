# Sprint 10 — Multi-Stage Builds & Image Optimization — Notes

## Phase 1 — The Hook

**Claude's Explanation:**  
Building a ship in a shipyard requires cranes, welding equipment, scaffolding — massive infrastructure. None of that goes on the ship when it sails. A multi-stage build is the same: Stage 1 is the shipyard (all build tools, compilers, dev dependencies). Stage 2 is the ship (only what's needed to run). The final image contains only Stage 2. Everything from Stage 1 is discarded.

**First Test:**  
Measured baseline image sizes before optimization:
- `runmatic-api-v1`: 279 MB
- `runmatic-worker-v1`: 210 MB
- `frontend`: 338 MB

**My Result:**  
Frontend at 338MB was carrying the entire Node.js toolchain + npm + build dependencies just to serve 5MB of compiled static files. API at 279MB likely had pip and build tools still present after installation completed.

---

## Phase 2 — The Build

**Done Condition:**  
Frontend ≤ 135MB (60% reduction), API ≤ 140MB (50% reduction), both still functional in Compose.

**My Work:**

**Frontend Dockerfile (`Dockerfile.frontend`):**
- Stage 1 (builder): `FROM node:18-alpine` → install dependencies → run `npm run build` → produces `/app/dist`
- Stage 2 (runtime): `FROM nginx:alpine` → copy only `/app/dist` from builder → copy nginx.conf → serve
- Result: 338 MB → 53.8 MB = **84% reduction** (crushed the 60% target)

**API Dockerfile (`Dockerfile.api`):**
- Stage 1 (builder): `FROM python:3.11` (full image with gcc) → `pip install --prefix=/install` → packages installed to `/install`
- Stage 2 (runtime): `FROM python:3.11-slim` → copy `/install` to `/usr/local` → copy app code
- Result: 279 MB → 268 MB = **4% reduction** (well below 50% target)

**Key observations:**
- Frontend: Node.js runtime (600MB) + node_modules (300MB) completely discarded. Only 5MB of compiled HTML/CSS/JS remains.
- API: pip and gcc discarded (~130MB), but all installed Python packages must stay at runtime (~119MB). Net savings minimal because Python is interpreted — you need the packages to run the app.
- Used `python:3.11` (full) for builder to have gcc available for compiling C extensions in packages like psycopg2, cryptography. Runtime uses `python:3.11-slim` which is lighter.

---

## Phase 3 — The Challenge

**Claude's Challenge:**  
Why did the frontend shrink 84% but the API only 4%? When does multi-stage give you massive savings vs minimal savings?

**My Investigation:**

Traced the image size math:
```
API:
Old: 279 MB
New: 279 MB - (pip + gcc: 130 MB) + (installed packages copied from /install: 119 MB) = 268 MB
Savings: 11 MB (4%)

Frontend:
Old: 338 MB  
New: base nginx:alpine (30 MB) + compiled dist/ (5 MB) = 53.8 MB
Discarded: Node.js + npm + node_modules (280 MB)
Savings: 284 MB (84%)
```

**Key insight:**  
Multi-stage builds win big when **build-time dependencies are large and runtime output is small**.

- Frontend: Build needs 280 MB of tooling. Runtime needs 5 MB of static files. 98% of build stage is waste.
- API: Build needs 130 MB of tools. Runtime needs 119 MB of packages. Only the tools are waste.

For compiled languages (Go, Rust), the runtime artifact is a single binary — massive wins.  
For interpreted languages (Python, Node.js), it depends on whether dependencies are build-time-only (npm) or runtime-required (Python packages).

**The difference:**
- `npm run build` compiles TypeScript → static files. Node.js is not needed at runtime. Nginx serves the files.
- `pip install` downloads Python packages. Those packages ARE the runtime. Python interpreter executes them on every request.

---

## Phase 4 — Explanation

**Claude's Question:**  
Explain multi-stage builds in 3 sentences to a support engineer who's never heard of Docker.

**My Answer:**  
"The assumption that as long as the app runs successfully image size does not matter is wrong. Every increase in image size is a security issue. Multi-stage build helps to resolve it. It keeps the build and run time work separate and copy files from build to runtime - only files that are required. The entire build is discarded, they are not hidden, compressed or archived, they are discarded."

**Claude's Feedback:**  
Mechanically correct — I nailed the "discarded not compressed" concept and understood why frontend won big and API didn't. But my explanation assumed the audience already knew what "build vs runtime" means. For someone new to Docker, I should have grounded it in a concrete analogy rather than abstract concepts.

A better version for teaching:  
*"A Dockerfile can have multiple stages — like building a ship in a shipyard, then sailing away. Stage 1 installs everything needed to compile the app. Stage 2 starts fresh and copies only the compiled result. The shipyard (Node.js, compilers, build tools) is left behind — completely discarded, not just hidden."*

---

## Bonus Challenge

**Claude's Challenge:**  
A teammate's multi-stage Dockerfile builds successfully but Nginx crashes on startup:  
`nginx: [emerg] open() "/etc/nginx/nginx.conf" failed (2: No such file or directory)`

The config file exists in the repo. The Dockerfile has `COPY nginx.conf /etc/nginx/conf.d/default.conf` in the builder stage.

**My Investigation:**

Simulated the issue. The problem:
- `nginx.conf` was copied in the **builder stage**: `COPY nginx.conf /etc/nginx/conf.d/default.conf`
- The runtime stage starts with `FROM nginx:alpine` — a completely fresh filesystem
- The builder stage filesystem (which included the nginx.conf) is **discarded**
- Only files explicitly copied with `COPY --from=builder` carry forward to runtime
- Nginx in the runtime stage has no nginx.conf — hence the crash

**Root cause:**  
Teammate assumed files copied in the builder stage would be present in the runtime stage. They don't understand that each `FROM` starts a blank slate. Files don't "leak" between stages unless explicitly copied with `COPY --from=`.

**My Fix:**
```dockerfile
FROM node:18-alpine as builder
WORKDIR /app
COPY package*.json .
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf  # ← Moved to runtime stage
EXPOSE 3000
CMD ["nginx", "-g", "daemon off;"]
```

**Diagnosis:** 5/5  
**Fix:** 5/5  
**Total:** 10/10

---

## Key Takeaways

1. **Multi-stage builds shine when build tools ≫ runtime output.** Frontend (Node.js tooling huge, compiled output tiny) saw 84% reduction. API (Python packages needed at runtime) saw 4%.

2. **Each FROM is a hard reset.** The runtime stage starts with a completely fresh filesystem. Only explicit `COPY --from=builder` commands bring files forward. Everything else in earlier stages is discarded.

3. **Builder can be fat, runtime must be lean.** Use `python:3.11` (full, with gcc) for building. Use `python:3.11-slim` for runtime. The builder is thrown away, so its size doesn't matter.

4. **Image size = security + cost + speed.** Smaller runtime images have fewer CVEs, lower bandwidth costs, faster CI pulls, faster cold starts. A 300MB → 50MB reduction saves 2TB of bandwidth per year at 20 deploys/day.

5. **Not all optimizations give big wins.** Python apps see minimal gains because packages are runtime dependencies. Compiled languages (Go, Rust) and compiled-to-static toolchains (TypeScript, Webpack) see massive wins.
