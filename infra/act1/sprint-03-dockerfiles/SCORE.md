# Sprint 03 — Writing Dockerfiles
**Score:** 19/20  (Concept: 9/10 | Execution: 9/10 | Speed: +1)
**Date:** 2026-03-31
**Duration:** Approx 30 min (active session)

---

## What You Got Right

1. **exec vs shell form — PID 1 and SIGTERM.** This wasn't explicitly taught this sprint. You reasoned that shell form makes `/bin/sh` PID 1, which swallows SIGTERM and causes forced kills instead of graceful shutdown — dropped DB connections, cut mid-flight requests. exec form makes uvicorn PID 1 directly, so signals reach the process. That's production-quality thinking before Sprint 11 even covers it.

2. **Layer order proved empirically.** 0.1 seconds vs 29.5 seconds — same code change, different instruction order. You didn't just state the rule, you ran the experiment and measured it. That number (29.5s) is now a reference point. Sprint 10 (multi-stage builds) will cut it further.

3. **Real-world debugging.** Two issues found and fixed independently: missing `alembic.ini` copy and missing `email-validator` in requirements. Both were gaps in the scaffold, both were diagnosed from error output and fixed without hints.

## What You Missed

1. **EXPOSE is documentation only.** `EXPOSE 8000` in a Dockerfile does not publish the port. It signals to other developers (and Docker tooling) that the container listens on 8000 — that's all. You still need `-p 8000:8000` at `docker run` time. Removing EXPOSE entirely changes nothing about connectivity. This matters in Sprint 07: Compose handles port publishing via the `ports:` key, and EXPOSE in the Dockerfile is informational metadata.

2. **No .dockerignore.** Without it, Docker copies everything in the build context into the image — including `__pycache__/`, any `.env` files, local `.venv/` directories if they exist. A `.dockerignore` should list at minimum: `__pycache__`, `*.pyc`, `.env`, `.venv`, `*.egg-info`. Leaking a `.env` into a Docker image that gets pushed to a registry is a real credential exposure vector.

## Carry Forward

`EXPOSE` documents. `-p` publishes. They are not the same. In Sprint 07, Docker Compose uses the `ports:` key in `docker-compose.yml` to publish ports — the Dockerfile's `EXPOSE` is read by Compose as a hint but is not sufficient on its own. Keep this distinction sharp when writing Compose files.

## What This Teaches About Production Systems

The Dockerfile you wrote today is the single source of truth for how the Runmatic API runs — on your Mac, in CI, in prod. Every engineer who joins the team gets the exact same environment by running one command. That's the problem it solves: not "does it work," but "does it work the same way everywhere, forever." The layer ordering you proved today (0.1s vs 29.5s) scales to real teams: at 50 deploys/day, a misconfigured Dockerfile wastes 24 minutes of CI time daily. At 200 engineers, it wastes hours. Thinking about this on Sprint 03 means you're already optimizing for team scale, not just "does it run locally."

## Bonus Challenge
Unlocked: Yes (19/20)
Attempted: Yes
Result:    10/10

**Scenario:** Colleague adds `EXPOSE 8000` and claims the port is published. `curl` fails.
**Diagnosis (5/5):** EXPOSE is documentation only — signals intent to readers of the Dockerfile, opens no network access. Correctly distinguished from actual port publishing.
**Fix (5/5):** `docker run -d -p 8000:8000 --name api runmatic-api-v1` — maps host port 8000 to container port 8000. Correct command, correct explanation of the mapping direction.
