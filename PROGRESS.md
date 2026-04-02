# PROGRESS.md — Runmatic Live State
*Claude reads this at the start of every session to orient immediately.*
*Claude updates this at the end of every sprint.*
*Do not edit manually unless correcting a factual mistake.*

---

## Current State

```
SESSION_PHASE:          active-sprints       (setup | session-0b | active-sprints | complete)
CURRENT_ACT:            1                   (1=Docker | 2=Kubernetes | 3=Platform)
CURRENT_SPRINT:         00                  (00 = not started)
SPRINT_TOPIC:           —
APP_BUILT:              true                (true after Session 0A completes)
ARCHITECTURE_REVIEW:    true                (true after Session 0B passes 4/5 questions)
```

---

## Session 0 Status

```
Session 0A (App Generation):          COMPLETE — 2026-03-17
  app/ scaffold generated:            true
  Files created:                      54
  RUNMATIC.md populated:              true

Session 0B (Architecture Review):     COMPLETE — 2026-03-26
  Questions attempted:                5/5
  Questions passed:                   4/5
  Sprint 01 unlocked:                 true
  ARCHITECTURE_REVIEW.md written:     true
  Miss:                               Q5 — could not name the 6 API env vars (Sprint 04 focus)
```

---

## Sprint Log — Act 1: Docker

| Sprint | Topic | Type | Concept | Execution | Speed | Total | Date | Bonus |
|--------|-------|------|---------|-----------|-------|-------|------|-------|
| 01 | Containers & Mental Model | 🔭 | 7 | 9 | +1 | 17/20 | 2026-03-26 | Unlocked |
| 02 | Images & Layers | 🔭 | 8 | 10 | +1 | 19/20 | 2026-03-29 | Unlocked |
| 03 | Writing Dockerfiles | 🔨 | 9 | 9 | +1 | 19/20 | 2026-03-31 | Unlocked |
| 04 | Environment & Config | 🔨 | — | — | — | —/20 | — | — |
| 05 | Volumes & Persistence | 🔨 | — | — | — | —/20 | — | — |
| 06 | Container Networking | 🔨 | — | — | — | —/20 | — | — |
| 07 | Docker Compose v1 | 🔨 | — | — | — | —/20 | — | — |
| 08 | Docker Compose v2 | 🔨 | — | — | — | —/20 | — | — |
| 09 | Frontend Container | 🔨 | — | — | — | —/20 | — | — |
| 10 | Multi-Stage Builds | 🔨 | — | — | — | —/20 | — | — |
| 11 | Health Checks & Restart | 🔨 | — | — | — | —/20 | — | — |
| 12 | Act 1 Capstone | 🏁 | — | — | — | —/30 | — | — |

**Act 1 Status:** 🟢 UNLOCKED — Session 0A and 0B complete
**Act 1 Unlock:** Score 24+/30 on Sprint 12 Capstone

---

## Sprint Log — Act 2: Kubernetes

| Sprint | Topic | Type | Concept | Execution | Speed | Total | Date | Bonus |
|--------|-------|------|---------|-----------|-------|-------|------|-------|
| 13 | K8s Mental Model | 🔭 | — | — | — | —/20 | — | — |
| 14 | Pods & Deployments | 🔨 | — | — | — | —/20 | — | — |
| 15 | Services & DNS | 🔨 | — | — | — | —/20 | — | — |
| 16 | ConfigMaps & Secrets | 🔨 | — | — | — | —/20 | — | — |
| 17 | Persistent Volumes | 🔨 | — | — | — | —/20 | — | — |
| 18 | Ingress | 🔨 | — | — | — | —/20 | — | — |
| 19 | Horizontal Pod Autoscaler | 🔨 | — | — | — | —/20 | — | — |
| 20 | Act 2 Capstone | 🏁 | — | — | — | —/30 | — | — |

**Act 2 Status:** 🔒 LOCKED — Complete Act 1 Capstone (Sprint 12, 24+/30) to unlock

---

## Sprint Log — Act 3: Platform

| Sprint | Topic | Type | Concept | Execution | Speed | Total | Date | Bonus |
|--------|-------|------|---------|-----------|-------|-------|------|-------|
| 21 | GitHub Actions CI | 🔨 | — | — | — | —/20 | — | — |
| 22 | GitHub Actions CD | 🔨 | — | — | — | —/20 | — | — |
| 23 | GitOps with Argo CD | 🔨 | — | — | — | —/20 | — | — |
| 24 | Prometheus | 🔨 | — | — | — | —/20 | — | — |
| 25 | Grafana Dashboards | 🔨 | — | — | — | —/20 | — | — |
| 26 | Alerting | 🔨 | — | — | — | —/20 | — | — |
| 27 | Loki Log Aggregation | 🔨 | — | — | — | —/20 | — | — |
| 28 | AWS Foundations | 🔨 | — | — | — | —/20 | — | — |
| 29 | EKS | 🔨 | — | — | — | —/20 | — | — |
| 30 | RDS | 🔨 | — | — | — | —/20 | — | — |
| 31 | Security Hardening | 🔨 | — | — | — | —/20 | — | — |
| 32 | Act 3 Capstone | 🏁 | — | — | — | —/50 | — | — |

**Act 3 Status:** 🔒 LOCKED — Complete Act 2 Capstone (Sprint 20, 24+/30) to unlock

---

## Performance Stats

```
Current Streak:             3 sessions
Longest Streak:             3 sessions
Best Sprint Score:          19/20
Average Sprint Score:       18.3
Perfect Scores (20/20):     0
Bonus Challenges Earned:    3
Bonus Challenges Won:       3 (Sprint 01 — 9/10, Sprint 02 — 10/10, Sprint 03 — 10/10)
Deep Dives Completed:       0
```

---

## Last Session

```
Date:                2026-03-31
Sprint:              03 — Writing Dockerfiles
What was built:      Dockerfile.api — correct layer order, exec form CMD, --no-cache-dir. Health endpoint responds. Proved 0.1s vs 29.5s caching.
Key concept:         Dockerfile = reproducible server setup as code. Layer order controls build speed. exec form = PID 1 = graceful SIGTERM handling.
What was missed:     EXPOSE is documentation only (not port publishing). No .dockerignore created.
Carry forward:       EXPOSE documents. -p publishes. Sprint 07 Compose uses ports: key — EXPOSE alone does nothing for connectivity.
Next session:        Sprint 04 — Environment & Configuration
```

---

## Pending Bonus Challenges

*Bonus challenges earned (16+/20) but saved for a future session:*
(none yet)

---

## Act Completion Record

```
Act 1 — Docker:       ⬜ NOT STARTED    Unlock: Sprint 12 capstone 24+/30
Act 2 — Kubernetes:   🔒 LOCKED         Unlock: Sprint 20 capstone 24+/30
Act 3 — Platform:     🔒 LOCKED         Unlock: Sprint 32 capstone 40+/50
```
