# Runmatic — Learning DevOps in Public

> A living runbook platform built to learn DevOps infrastructure from first principles.
> Every sprint is documented and the work scored by claude.

---

## The Project

**Runmatic** solves a real SRE problem: runbooks go stale. On-call engineers open runbooks at 2am and find instructions for tools that were deprecated, escalation paths to people who left, commands referencing a Kubernetes version from three years ago. Nobody maintains runbooks because there's no forcing function.

Runmatic tracks runbook staleness, links runbooks to deployment events, and builds incident history so teams can see which runbooks were used and whether they were actually accurate.

**This project exists to learn DevOps infrastructure — not to write application code.**

The application was generated with AI to production standards. The infrastructure — every Dockerfile, every Kubernetes manifest, every CI/CD pipeline, every Grafana dashboard, every Terraform resource — was designed, written, debugged, and documented by me, sprint by sprint, scored and committed.

---

## Live Dashboard

| | |
|--|--|
| **Current Act** | Act 1 — Docker |
| **Sprints Completed** | 5 / 32 |
| **Average Score** | 18.8 / 20 |
| **Best Sprint** | Sprint 05 — 20/20 |
| **Current Streak** | 5 🔥 |
| **Bonus Challenges** | 5 won / 5 attempted |
| **Act 1 Status** | 🟢 Sprint 06 up next |
| **Act 2 Status** | 🔒 Locked |
| **Act 3 Status** | 🔒 Locked |

### Sprint Log

| Sprint | Topic | Score | Bonus | Date |
|--------|-------|-------|-------|------|
| 01 | Containers & the Docker Mental Model | 17/20 | 9/10 | 2026-03-26 |
| 02 | Images & Layers | 19/20 | 10/10 | 2026-03-29 |
| 03 | Writing Dockerfiles | 19/20 | 10/10 | 2026-03-31 |
| 04 | Environment & Configuration | 19/20 | 7.5/10 | 2026-04-08 |
| 05 | Volumes & Persistence | 20/20 | 10/10 | 2026-04-09 |

*Updated after every sprint commit.*

---

## What It Looks Like When Complete

**A live URL.** Runmatic running on AWS EKS. Not a localhost screenshot — a real URL a recruiter can open.

**32 sprint case studies.** Every sprint folder has:
- The infrastructure file I wrote (Dockerfile, YAML manifest, Terraform config)
- `README.md` in my words — the mental model that made it click, the mistake I made, what I'd do differently
- `commands.sh` — a narrative annotated runbook of every command I ran and what I actually observed
- `SCORE.md` — honest feedback: what I got right, what I missed, and what it means for production systems

**A git history that tells a story.** Commits like `sprint-03: dockerfiles | score 18/20 | streak 3`. Scores going up. Bonus challenges. Deep dives. 32 commits that show a learning arc.

**The ability to explain every decision.** I didn't just run commands — I understand why the Dockerfile instruction order matters for CI pipeline speed, why Kubernetes needs a StatefulSet for PostgreSQL instead of a Deployment, why GitOps inverts the push model. Because I was scored on explaining it.

---

## Architecture

```
Browser → Nginx (frontend :3000)
              → /api/* → FastAPI (api :8000)
                               → PostgreSQL (postgres :5432)
                               → Redis (cache :6379)
                                       ↑
                         Worker (APScheduler + rq)
```

Five services. The infrastructure evolves from a single Dockerfile to a production AWS platform across 32 sprints.

---

## The Learning Arc

```
ACT 1 — DOCKER          Sprints 01–12    ~6 weeks
├── 01: Containers & the mental model
├── 02: Images & layers
├── 03: Writing Dockerfiles
├── 04: Environment & config
├── 05: Volumes & persistence
├── 06: Container networking
├── 07: Docker Compose v1
├── 08: Docker Compose v2 (health checks)
├── 09: Frontend container
├── 10: Multi-stage builds
├── 11: Health checks & restart policies
└── 12: 🏁 Capstone — docker compose up → full stack

ACT 2 — KUBERNETES      Sprints 13–20    ~4 weeks
├── 13: K8s mental model
├── 14: Pods & Deployments
├── 15: Services & DNS
├── 16: ConfigMaps & Secrets
├── 17: Persistent Volumes
├── 18: Ingress
├── 19: Horizontal Pod Autoscaler
└── 20: 🏁 Capstone — full stack on K8s, self-healing

ACT 3 — PLATFORM        Sprints 21–32    ~6 weeks
├── 21: GitHub Actions CI
├── 22: GitHub Actions CD
├── 23: GitOps with Argo CD
├── 24: Prometheus metrics
├── 25: Grafana dashboards
├── 26: Alerting (Prometheus + Slack)
├── 27: Loki log aggregation
├── 28: AWS foundations (VPC, IAM, ECR)
├── 29: EKS (managed Kubernetes)
├── 30: RDS (managed PostgreSQL)
├── 31: Security hardening
└── 32: 🏁 Capstone — live on AWS, automated, monitored
```

---

## Sprint Format

Each sprint is 35 minutes, four phases:

- **Hook** (0–5 min): one analogy connecting the concept to something I already know, one command to run immediately
- **Build** (5–20 min): one concrete deliverable with an explicit done condition
- **Challenge** (20–30 min): break-fix or conceptual extension — no hints for 5 minutes
- **Score** (30–35 min): explain the concept from memory → scored 1–20

Scoring 16+/20 unlocks a bonus break-fix challenge, scored separately.

---

## Repository Structure

```
runmatic/
├── app/                    # Application (AI-generated, production standards)
│   ├── api/                # FastAPI backend
│   ├── worker/             # Background job processor
│   ├── frontend/           # React/Vite UI + Nginx config
│   └── db/                 # Alembic migrations + seed data
│
├── infra/                  # Infrastructure (hand-written, sprint by sprint)
│   ├── docker/             # Act 1: Dockerfiles, Compose files
│   │   ├── sprint-01-fundamentals/
│   │   ├── sprint-03-dockerfiles/
│   │   │   ├── Dockerfile.api      ← I wrote this
│   │   │   ├── README.md           ← My understanding
│   │   │   ├── commands.sh         ← Annotated command history
│   │   │   └── SCORE.md            ← Honest feedback card
│   │   └── ...
│   ├── k8s/                # Act 2: Kubernetes manifests
│   └── cloud/              # Act 3: Terraform, AWS configs
│
├── ARCHITECTURE_REVIEW.md  # My analysis of Runmatic before touching infra/
├── CHANGELOG.md            # Act completions and milestone moments
└── PROGRESS.md             # Live sprint log with scores
```

---

