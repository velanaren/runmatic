# Sprint 12 — Act 1 Capstone
**Score:** 29/30  (Operational: 10/10 | Architecture: 9/10 | Documentation: 10/10)
**Date:** 2026-04-18
**Duration:** Approx 45 min

---

## Operational Proof — 10/10

**What You Demonstrated:**
- All 5 services started healthy within expected timeframe
- Created runbook "API Health check failure" via browser UI successfully
- Persistence verified: `docker compose down && docker compose up` → runbook ID 5 survived
- Volume behavior understood: explained that `docker compose down -v` deletes volumes, without `-v` they persist
- Restart policy tested correctly: used `docker compose exec api sh -lc 'kill 1'` to simulate a crash (not `docker compose kill` which is a manual stop)
- Observed restart behavior precisely: API container went from "health: starting" to "healthy", uptime reset to 5 seconds while other services stayed at 6 minutes
- Understood the distinction: "docker compose kill api will not allow restart because docker will treat this as stopped by user" — exactly correct for `unless-stopped` policy

**Why This Matters:**
You demonstrated production-level operational knowledge. The distinction between crash (kill 1 inside container) and manual stop (docker compose kill) is what separates junior from senior engineers. In a real incident, knowing which restart policy to use and how to test it correctly prevents hours of debugging.

---

## Architecture Explanation — 9/10

**Q1 — Network Topology (9/10)**
You explained the communication graph correctly:
- Frontend → API
- Worker → postgres + redis + API
- API → postgres + redis

You understood why docker compose networking works: it creates a network automatically, services resolve each other via DNS (hostname = service name), unlike bridge network where you'd need IP addresses. The only thing missing was naming the specific network (`sprint-11-restart-policies_default`), but the conceptual understanding was solid.

**Q2 — Volume Strategy (10/10)**
Perfect reasoning: "Container lifecycle should be separated from data lifecycle. Containers are meant to be ephemeral, disposable and replaceable. But that is not the case with data."

You correctly identified:
- Business-critical data (postgres runbooks, services, incidents) → must persist
- Ephemeral data (JWT sessions, Redis temporary triggers) → doesn't need persistence for this use case

This is the core insight. The decision isn't "what can I persist?" but "what must survive a container restart for the business to function?"

**Q3 — Dockerfile Layer Ordering (8/10)**
You gave the correct principle and a correct example from Dockerfile.api:
- Stable layers on top (FROM, WORKDIR, requirements.txt)
- Changing layers at bottom (COPY app)
- Why: changing a layer invalidates everything after it

One clarification on wording: you said "if we change any layer, the layer below it will be rebuilt." You meant "layers after/below in the file" which is correct — just slightly ambiguous phrasing. Your example proved you understand it: app code at the bottom because it changes most frequently.

**Q4 — Startup Dependency Chain (10/10)**
Perfect. You listed the full order:
1. postgres starts
2. redis starts
3. api waits for postgres + redis healthy
4. frontend waits for api healthy
5. worker waits for postgres + redis + api healthy

And you nailed the purpose of health checks: "Health check ensures the dependent services are not just up, but they are up and doing the desired function." This is the difference between `depends_on` (wait for start) and `depends_on: condition: service_healthy` (wait for readiness).

---

## Documentation Quality — 10/10

**Audit Results:**
- All 11 sprints have SCORE.md, notes.md, and commands.sh ✓
- Files are substantial (not empty placeholders):
  - Sprint 05 SCORE.md: 43 lines
  - Sprint 10 notes.md: 147 lines
  - Sprint 11 commands.sh: 118 lines
- All infrastructure files present in build sprints:
  - Sprint 03: Dockerfile.api, Dockerfile.worker
  - Sprint 07-11: docker-compose.yml evolution
  - Sprint 09: Dockerfile.frontend
  - Sprint 10-11: Multi-stage Dockerfiles with optimizations
- Complete audit trail from Sprint 01 (first `docker run`) to Sprint 11 (production-ready compose stack)

**Why This Matters:**
In an interview, you can point to any sprint folder and say "I wrote every line in infra/. Here's the runbook (notes.md), here's every command I ran (commands.sh), here's the assessment (SCORE.md)." The git blame is clean. The learning is documented. This is portfolio-grade work.

---

## What This Teaches About Production Systems

The capstone wasn't about building something new — it was about proving you can *operate* what you've built. Production systems aren't just code that runs; they're systems you can explain, debug, and hand off to someone else.

The three dimensions mirror real SRE work:
1. **Operational proof** = can you run it in an incident? Can you test restart policies under pressure? Can you verify persistence after a deployment?
2. **Architecture explanation** = can you onboard a new teammate? Can you draw the dependency graph in a postmortem? Can you explain *why* postgres persists but redis doesn't?
3. **Documentation quality** = can you reconstruct what you did six months ago? Can you show your reasoning? Can you prove you didn't just copy-paste from Stack Overflow?

You passed all three. Docker is no longer a black box. You can containerize an application, orchestrate multi-service stacks, optimize builds for production, implement self-healing with restart policies and health checks, and explain every decision you made.

**Act 1 complete. Kubernetes next.**

---

## Act 2 Preview — The Mindset Shift

Docker Compose: "Here are my containers. Run them on this machine."

Kubernetes: "Here is my desired state. Make reality match it, on however many machines you have, and keep it that way forever — even when things fail."

You're not running containers anymore. You're declaring intentions. The control plane figures out *how* to make it happen. A pod dies? K8s recreates it. A node fails? K8s reschedules the pods. You update the image? K8s rolls it out with zero downtime.

Same Runmatic app. Radically different substrate.

Sprint 13 starts with the mental model: control plane, nodes, pods, reconciliation loops. You'll understand the brain before you write the first line of YAML.
