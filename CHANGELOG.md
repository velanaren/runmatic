# CHANGELOG.md — Runmatic Learning Milestones
*Updated by Claude at act completions, capstone scores, and milestone moments.*
*This file tells the story of the learning journey at a glance.*

---

## Format

Each entry captures a meaningful moment — not every sprint, just the milestones.
A recruiter reading this understands the arc: where you started, where you are, where you're going.

---

## Milestones

*(Updated as they are reached)*

---

### Project Initialized
**Date:** [YYYY-MM-DD]
**What:** Repository set up. CLAUDE.md, SPRINTS.md, PROGRESS.md, RUNMATIC.md generated. Learning OS configured.
**Starting point:** 13 years application support. Zero Docker experience. Zero K8s experience. Beginning from scratch.

---

### Session 0A Complete — App Generated
**Date:** [YYYY-MM-DD]
**What:** Runmatic application generated in `app/`. [N] files. Full FastAPI backend, APScheduler worker, React frontend, PostgreSQL schema, seed data.
**Note:** This is the application we will operate for the next 32 sprints. Not written by me — built by AI to production standards. My job: run it, containerize it, orchestrate it, monitor it.

---

### Session 0B Complete — Architecture Review
**Date:** [YYYY-MM-DD]
**Architecture questions:** [X]/5 correct
**What:** Reviewed the Runmatic codebase, documented architecture understanding in ARCHITECTURE_REVIEW.md. Sprint 01 unlocked.
**Key insight:** [One thing you understood about the architecture that wasn't obvious at first]

---

### First Sprint Complete
**Date:** [YYYY-MM-DD]
**Sprint:** 01 — Containers & the Docker Mental Model
**Score:** [XX]/20
**What:** [One sentence]

---

### First 20/20
**Date:** [YYYY-MM-DD]
**Sprint:** [XX] — [Topic]
**What:** [What you got perfectly right]

---

### First Bonus Challenge Won
**Date:** [YYYY-MM-DD]
**Sprint:** [XX] bonus — [Topic]
**Score:** [X]/10
**The scenario:** [Brief description of the break-fix]
**How I solved it:** [One sentence]

---

### Act 1 Complete — Docker Mastery
**Date:** 2026-04-18
**Capstone score:** 29/30
**Act 1 stats:** 11 sprints | Average score: 19.1/20 | Bonus challenges: 11 won / 11 attempted | Streak: 12 sessions
**What Runmatic can do:** `docker compose up` → 5 services start, all healthy (API, worker, frontend, postgres, redis). Data persists across restarts. Services self-heal with restart policies. Multi-stage builds reduce image sizes by 50-60%. Health checks enforce startup dependencies.
**Weakest sprint:** Sprint 01 — Containers & Mental Model (17/20) — First sprint learning Docker fundamentals, minor confusion distinguishing containers from images
**Strongest sprint:** Multiple 20/20s — Sprints 05 (Volumes), 06 (Networking), 07 (Compose v1), 08 (Compose v2) — Concepts clicked, execution flawless, completed under 35 minutes
**Key thing learned from Act 1:** Container lifecycle must be separated from data lifecycle. Containers are ephemeral and disposable — you can delete them, recreate them, restart them without worry. But data isn't. Business operations depend on persistent state surviving container restarts. That distinction — knowing what to persist (postgres runbooks) and what to leave ephemeral (redis sessions) — is what makes infrastructure production-ready, not just functional. Every restart policy, every volume mount, every health check encodes operational intent: "this is how the system should behave when things fail." Docker taught me that infrastructure isn't code that runs — it's systems that recover.

---

### Act 2 Complete — Kubernetes Mastery
**Date:** [YYYY-MM-DD]
**Capstone score:** [XX]/30
**Act 2 stats:** [X] sprints | Average score: [X.X]/20
**What Runmatic can do:** Full stack on local K8s. Self-healing. Scales under load. Accessible via Ingress.
**Biggest mental model shift:** [The thing K8s taught you that Docker couldn't]

---

### Act 3 Complete — Platform Mastery
**Date:** [YYYY-MM-DD]
**Capstone score:** [XX]/50
**Act 3 stats:** [X] sprints | Average score: [X.X]/20
**What Runmatic can do:** Live on AWS EKS. Deployed automatically on git push. Monitored with Prometheus + Grafana. Logs in Loki. Alerts in Slack. Database on RDS. Images on ECR.
**Total project stats:**
- Duration: [X] weeks
- Total sprints: 32
- Average score: [X.X]/20
- Bonus challenges won: [X]/[X]
- Commits: [N]
**What this project taught me:** [One honest paragraph]
