# PROGRESS.md — Runmatic Live State
*Claude reads this at the start of every session to orient immediately.*
*Claude updates this at the end of every sprint.*
*Do not edit manually unless correcting a factual mistake.*

---

## Current State

```
SESSION_PHASE:          active-sprints       (setup | session-0b | active-sprints | complete)
CURRENT_ACT:            2                   (1=Docker | 2=Kubernetes | 3=Platform)
CURRENT_SPRINT:         18                  (00 = not started)
SPRINT_TOPIC:           Ingress
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
| 04 | Environment & Config | 🔨 | 9 | 9 | +1 | 19/20 | 2026-04-08 | Unlocked (7.5/10) |
| 05 | Volumes & Persistence | 🔨 | 9 | 10 | +1 | 20/20 | 2026-04-09 | Unlocked (10/10) |
| 06 | Container Networking | 🔨 | 9 | 10 | +1 | 20/20 | 2026-04-10 | Unlocked (10/10) |
| 07 | Docker Compose v1 | 🔨 | 9 | 10 | +1 | 20/20 | 2026-04-11 | Unlocked (10/10) |
| 08 | Docker Compose v2 | 🔨 | 9 | 10 | +1 | 20/20 | 2026-04-11 | Unlocked (7/10) |
| 09 | Frontend Container | 🔨 | 9 | 10 | 0 | 19/20 | 2026-04-13 | Unlocked |
| 10 | Multi-Stage Builds | 🔨 | 8 | 9 | +1 | 18/20 | 2026-04-14 | Unlocked (10/10) |
| 11 | Health Checks & Restart | 🔨 | 8 | 10 | +1 | 19/20 | 2026-04-15 | Unlocked (9/10) |
| 12 | Act 1 Capstone | 🏁 | — | — | — | 29/30 | 2026-04-18 | — |

**Act 1 Status:** ✅ COMPLETE — Docker Mastery Proven (29/30)
**Act 2 Status:** 🔓 IN PROGRESS — Kubernetes (Sprint 13-20) — Sprint 15 complete

---

## Sprint Log — Act 2: Kubernetes

| Sprint | Topic | Type | Concept | Execution | Speed | Total | Date | Bonus |
|--------|-------|------|---------|-----------|-------|-------|------|-------|
| 13 | K8s Mental Model | 🔭 | 9 | 9 | +1 | 19/20 | 2026-04-22 | 10/10 |
| 14 | Pods & Deployments | 🔨 | 9 | 9 | +0 | 18/20 | 2026-04-23 | Unlocked |
| 15 | Services & DNS | 🔨 | 9 | 9 | +1 | 19/20 | 2026-04-26 | 10/10 |
| 16 | ConfigMaps & Secrets | 🔨 | 8 | 9 | +1 | 18/20 | 2026-04-27 | 10/10 |
| 17 | Persistent Volumes | 🔨 | 7 | 9 | +1 | 17/20 | 2026-04-29 | Unlocked |
| 18 | Ingress | 🔨 | 9 | 8 | +0 | 17/20 | 2026-05-01 | Unlocked |
| 19 | Horizontal Pod Autoscaler | 🔨 | — | — | — | —/20 | — | — |
| 20 | Act 2 Capstone | 🏁 | — | — | — | —/30 | — | — |

**Act 2 Status:** 🔓 IN PROGRESS — Kubernetes (Sprint 13-20) — Sprint 18 complete

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
Current Streak:             18 sessions
Longest Streak:             18 sessions
Best Sprint Score:          20/20
Average Sprint Score:       18.7
Perfect Scores (20/20):     4
Capstone Scores:            29/30 (Act 1)
Bonus Challenges Earned:    15
Bonus Challenges Completed: 17 (Sprint 01 — 9/10, Sprint 02 — 10/10, Sprint 03 — 10/10, Sprint 04 — 7.5/10, Sprint 05 — 10/10, Sprint 06 — 10/10, Sprint 07 — 10/10, Sprint 08 — 7/10, Sprint 09 — 9/10, Sprint 10 — 10/10, Sprint 11 — 9/10, Sprint 13 — 10/10, Sprint 14 — 10/10, Sprint 15 — 10/10, Sprint 16 — 10/10, Sprint 17 — 7/10, Sprint 18 — 8/10)
Deep Dives Completed:       0
```

---

## Last Session

```
Date:                2026-05-01
Sprint:              18 — Ingress
What was built:      frontend-deployment.yaml + frontend-service.yaml (first K8s frontend deployment).
                     ingress.yaml — nginx Ingress with two path rules: /api → api-service:8000,
                     / → frontend-service:3000. Runmatic UI live at runmatic.local in browser.
                     Phase 3: diagnosed path-rewrite gap (/v2/api/runbooks → 404 from FastAPI),
                     fixed with rewrite-target: /api/$2, regex capture group (/|$)(.*),
                     ImplementationSpecific pathType, use-regex: true. Verified with real API data.
                     Side fixes: nginx.conf resolver trick (deferred DNS resolution), Redis deployed,
                     ConfigMap REDIS_URL typo fixed, DB migrations run.
Key concept:         Ingress = one cluster entry point. Ingress resource = routing rules (YAML).
                     Ingress controller = running Nginx pod that reads and enforces those rules.
                     Paths pass through UNCHANGED by default — rewrite-target only needed when backend
                     doesn't match the incoming path. Controller watches K8s API continuously and
                     reconciles routing config automatically on every ingress.yaml change.
What was missed:     Controller reconciliation loop — it watches K8s API continuously, not just at
                     startup. rewrite-target annotation scope — applies to ALL paths in the Ingress
                     object, not just the one with the regex.
Carry forward:       Ingress passes paths unchanged by default. Know when to rewrite vs let through.
                     Sprint 20 Capstone: decide explicitly for each path — rewrite needed or not?
Next session:        Sprint 19 — Horizontal Pod Autoscaler (worker scales under load)
```

---

## Pending Bonus Challenges

*Bonus challenges earned (16+/20) but saved for a future session:*
(none yet)

---

## Act Completion Record

```
Act 1 — Docker:       ✅ COMPLETE       Score: 29/30 (2026-04-18)
Act 2 — Kubernetes:   🔓 UNLOCKED       Unlock: Sprint 20 capstone 24+/30
Act 3 — Platform:     🔒 LOCKED         Unlock: Sprint 32 capstone 40+/50
```
