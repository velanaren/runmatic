# Sprint 10 — Multi-Stage Builds & Image Optimization
**Score:** 18/20  (Concept: 8/10 | Execution: 9/10 | Speed: +1)
**Date:** 2026-04-14
**Duration:** Approx 28 min

---

## What You Got Right

**You understood the mechanism at a deep level.** You correctly identified that the build stage is DISCARDED — not compressed, not hidden, actually gone from the final image. Many engineers miss this subtlety and think Docker is just hiding layers.

**You diagnosed the asymmetry perfectly.** Frontend dropped 84% because Node.js + npm + TypeScript (280MB) are build-time-only dependencies. The compiled output (dist/) is 5MB of static files. API dropped only 4% because Python packages are runtime dependencies — pip and gcc get discarded (130MB), but the installed packages must stay (119MB). You traced the math: `new size = old size - (build tools) + (runtime artifacts)`.

**Strong execution.** Both Dockerfiles are production-quality. You used `python:3.11` (full, with gcc) for the builder and `python:3.11-slim` for runtime — that split is exactly right for Python apps that need to compile C extensions. Frontend Dockerfile is textbook clean.

---

## What You Missed

**Your explanation assumed too much context.** You said: "Multi-stage build keeps build and runtime work separate and copies only files that are required." Technically true. But to a support engineer who's never written a Dockerfile, "build and runtime work" is abstract. You didn't ground it in something they could visualize.

Compare to: *"A Dockerfile can have multiple stages — like building a ship in a shipyard, then sailing away. Stage 1 installs everything needed to compile the app. Stage 2 starts fresh and copies only the compiled result. The shipyard is left behind."*

Your version is precise. That version is **learnable**. When teaching (interviews, documentation, onboarding), meet the audience where they are. You know it deeply — make it obvious to others.

---

## Carry Forward

The builder base can be large (`python:3.11` with gcc, build-essential) because it's discarded. The runtime base must be minimal (`python:3.11-slim` or `alpine`). This isn't just about image size — it's a **security decision**. A smaller runtime image has fewer installed packages, which means fewer CVEs (Common Vulnerabilities and Exposures). In Sprint 11 you'll add vulnerability scanning. Every package in the runtime image is attack surface. Multi-stage builds let you discard build tools that would otherwise be exploitable in production.

---

## What This Teaches About Production Systems

Image size isn't vanity. Every MB you ship is:
- **Bandwidth**: Slower pulls in CI, slower deploys to prod, slower cold starts in autoscaling
- **Attack surface**: More binaries, more libraries, more CVE risk
- **Cost**: Registries charge for storage; egress fees add up at scale

A 300MB image vs a 50MB image doesn't sound dramatic until you're pulling it 500 times a day across a CI fleet. That's 125GB of bandwidth daily — real money, real time, real carbon footprint.

The 84% reduction you achieved on the frontend? In a real team shipping 20 deploys a day, that's 5.7GB saved per day just from removing Node.js from the runtime image. Over a year: 2TB of bandwidth you didn't pay for, didn't wait for, didn't burn energy transmitting.

Multi-stage builds are how production engineers think: **what's the minimum viable runtime?** Everything else is waste.

---

## Bonus Challenge

**Unlocked:** Yes (18/20)  
**Attempted:** Yes  
**Result:** 10/10

**Scenario:** Nginx crashes on startup with "nginx.conf file not found" after converting to multi-stage build. The config file exists in the repo and was copied in the Dockerfile.

**Your diagnosis:** The `COPY nginx.conf` command was in the builder stage. Multi-stage builds discard the entire builder filesystem — only explicit `COPY --from=builder` commands bring files forward. The nginx.conf existed in the builder's `/etc/nginx` but was discarded along with Node.js and npm when that stage ended. The runtime stage (FROM nginx:alpine) starts with a fresh filesystem.

**Your fix:** Move `COPY nginx.conf /etc/nginx/conf.d/default.conf` to the runtime stage, after the `COPY --from=builder /app/dist` line.

**Why this matters:** This is the #1 multi-stage build mistake — assuming files copied in an earlier stage "leak" into later stages. They don't. Each `FROM` is a hard reset. Only the final stage becomes the image. Everything else is build-time scaffolding, discarded completely.

**Flawless execution.** You simulated the bug, traced the root cause, and fixed it in under 10 minutes.
