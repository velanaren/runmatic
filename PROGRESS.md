# PROGRESS.md — Runmatic Live State
*Claude reads this at the start of every session to orient immediately.*
*Claude updates this at the end of every sprint.*
*Do not edit manually unless correcting a factual mistake.*

---

## Current State

```
SESSION_PHASE:          active-sprints       (setup | session-0b | active-sprints | complete)
CURRENT_ACT:            2                   (1=Docker | 2=Kubernetes | 3=Platform)
CURRENT_SPRINT:         16                  (00 = not started)
SPRINT_TOPIC:           ConfigMaps & Secrets
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
Current Streak:             15 sessions
Longest Streak:             15 sessions
Best Sprint Score:          20/20
Average Sprint Score:       19.0
Perfect Scores (20/20):     4
Capstone Scores:            29/30 (Act 1)
Bonus Challenges Earned:    13
Bonus Challenges Completed: 14 (Sprint 01 — 9/10, Sprint 02 — 10/10, Sprint 03 — 10/10, Sprint 04 — 7.5/10, Sprint 05 — 10/10, Sprint 06 — 10/10, Sprint 07 — 10/10, Sprint 08 — 7/10, Sprint 09 — 9/10, Sprint 10 — 10/10, Sprint 11 — 9/10, Sprint 13 — 10/10, Sprint 14 — 10/10, Sprint 15 — 10/10)
Deep Dives Completed:       0
```

---

## Last Session

```
Date:                2026-04-26
Sprint:              15 — Services & DNS
What was built:      postgres-deployment.yaml, postgres-service.yaml (ClusterIP), api-service.yaml (NodePort).
                     API now reaches postgres via DNS name postgres-service. Both endpoints show real pod IPs.
                     Bonus: injected a fake-postgres pod with matching labels, proved Service load-balances
                     to it with no readiness gate — then identified readiness probes as the fix.
Key concept:         Service selector matches pod labels (not Deployment name). DNS resolves service-name →
                     ClusterIP → pod IP via kube-proxy. Without readiness probes any Running pod enters
                     the endpoint rotation regardless of whether it can actually serve traffic.
What was missed:     DNS resolves to ClusterIP (virtual IP), not directly to pod IP. kube-proxy handles
                     the final hop from ClusterIP to pod. Minor but important distinction.
Carry forward:       DATABASE_URL is still hardcoded as an env var in the Deployment YAML — visible to
                     anyone with kubectl access. Sprint 16 moves all config into ConfigMaps (safe values)
                     and Secrets (passwords). postgres-service is the hostname that goes into that config.
Next session:        Sprint 16 — ConfigMaps & Secrets (K8s-native config objects, no hardcoded values in YAML)
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
