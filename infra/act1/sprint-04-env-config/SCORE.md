# Sprint 04 — Environment & Configuration
**Score:** 19/20  (Concept: 9/10 | Execution: 9/10 | Speed: +1)
**Date:** 2026-04-08
**Duration:** Approx 30 min

---

## What You Got Right

**Security threat model is sharp.** You immediately recognized that hardcoded secrets in Dockerfiles become permanent in image layers, visible via `docker history`, and exposed when pushed to registries. You connected ENV visibility in `docker inspect` to real incident scenarios — exactly the kind of thinking that prevents production leaks.

**12-Factor principle is clear.** Your mental model — "IMAGE contains app code (never changes), CONFIG injected at runtime (different per environment)" — is textbook correct. You understood that the same image must run everywhere, and only the knobs (env vars) change.

**Practical verification instinct.** You tested the gitignore with a fake `.env` file rather than trusting it blindly. That's production-ready thinking.

---

## What You Missed

**`.env` vs `.env.example` distinction was slightly backwards.** You said ".env may not include secrets, it should be through secret managers." The correction: `.env` DOES include secrets for local development (that's its purpose), but it's gitignored so it never reaches the repo. In production, you skip `.env` files entirely and use secret managers instead. The pattern is:
- **Local dev:** `.env` file (gitignored, contains real secrets)
- **Production:** Secret managers (Vault, AWS Secrets Manager) inject at runtime

**commands.sh wasn't written yet during the sprint.** (Now generated — but the original protocol had you write it to consolidate learning through documentation.)

---

## Carry Forward

**Env vars are a stepping stone, not the destination.** They're fine for non-secret config (PORT, LOG_LEVEL) and acceptable for local dev secrets (in a gitignored `.env` file). But in production, `docker inspect` exposes them, process listings leak them, and CI logs capture them. Sprint 07's Compose will use `.env` files heavily for local multi-service orchestration. Act 2 (Kubernetes) introduces ConfigMaps (non-secret config) and Secrets (base64-encoded, still not perfect). Act 3 teaches secret managers — the actual production solution.

---

## What This Teaches About Production Systems

The 12-Factor App's config principle exists because of a specific class of incident that used to be common: an engineer commits a config file with production credentials, realizes the mistake, deletes the file, and pushes again. The credentials are still in git history forever. Anyone who clones the repo and runs `git log --all -- config.py` can retrieve them. Rotating the credentials is expensive (database downtime, coordinated deployment). Prevention is cheaper.

Docker images have the same property. A Dockerfile with `ENV DATABASE_URL=...` bakes the value into a layer. Even if you remove the line in a later commit, the old image layers persist in the registry. `docker history <image>` reveals every layer. Secrets become archaeology — permanently discoverable.

Thinking about this in Sprint 04 means you're already designing for auditability, credential rotation, and blast radius containment. These aren't "advanced topics" — they're day-one production requirements that most bootcamps teach too late.

---

## Bonus Challenge

**Unlocked:** Yes (19/20)  
**Attempted:** Yes  
**Result:** 7.5/10

**Diagnosis (7/10):** Correctly identified that the password was baked into the image and that restarting the container doesn't pick up the new image. Understood that `docker restart` uses the existing container tied to the old image ID. Minor precision gap: explained it as "the container has the password" rather than "the container is running the old image, which has the old password baked in."

**Fix (8/10):** Commands were correct (stop, rm, pull, run). Missed one critical step: when using runtime injection with `--env-file`, the `.env` file on the deployment server must also be updated before running the new container. The `.env` on the build machine is irrelevant — only the one where `docker run` executes matters.

**Bonus Score: 7.5/10** — Core concept solid (baked vs injected, restart vs recreate). Execution mostly correct. Runtime `.env` update step missing.
