# Sprint 02 — Images & Layers
**Score:** 19/20  (Concept: 8/10 | Execution: 10/10 | Speed: +1)
**Date:** 2026-03-29
**Duration:** Approx 30 min

---

## What You Got Right

1. **Layers as filesystem instructions.** "Each layer is one instruction that changes the file system" is precise. Not "part of the image" or "a chunk of data" — an instruction with a filesystem delta. That's the correct mental model.

2. **Shared layer verification.** You didn't just observe "Already exists" — you extracted both images' RootFS layer digests and used `comm` to prove the exact SHA256 match. `docker system df -v` then confirmed the 100.5MB shared size with exact numbers. This is the difference between understanding a concept and being able to prove it.

3. **The math.** 294MB claimed across two images, ~193MB actual disk usage. You worked out exactly where the 100.5MB went and why. This is the mental model that will stop you from panicking when `docker image ls` shows 10GB but your disk hasn't filled up.

## What You Missed

1. **Build-time layer caching.** You explained pull-time caching (shared layers not re-downloaded) but not build-time caching (unchanged layers not rebuilt). These are different things. When Docker builds an image, it checks whether the instruction and its inputs have changed since the last build. If not — cache hit, that layer is instant. If yes — cache miss, that layer rebuilds, **and so does every layer after it**. This cascade is critical in Sprint 03.

2. **Read-only image layers + one writable container layer.** Every image layer is read-only. When you run a container, Docker adds a single writable layer on top. All your writes (log files, temp files, anything) go into that writable layer. Stop the container — writable layer persists. Remove the container — writable layer is gone. The image underneath is untouched. This is why Sprint 05 (volumes) exists: to persist data outside the container's ephemeral writable layer.

## Carry Forward

Layer order in a Dockerfile is a performance decision. If instruction 3 changes, Docker rebuilds instructions 3, 4, 5, 6... to the end. Put slow, stable instructions early (OS setup, package installs). Put fast, frequently-changing instructions late (copy application code). In Sprint 03, this means: `COPY requirements.txt` + `pip install` must come **before** `COPY . .` — or every code change triggers a full pip reinstall.

## What This Teaches About Production Systems

Layer caching isn't a nice-to-have — it's the difference between a 30-second CI build and a 10-minute one. A team running 50 deploys a day with a poorly ordered Dockerfile burns ~8 hours of CI time daily re-running pip installs that didn't need to run. The `comm` command you wrote today is the diagnostic tool: compare two image layer digests to understand exactly what changed between builds and why the cache missed. In Sprint 10 (multi-stage builds) you'll use this to prove your optimizations worked.

## Bonus Challenge
Unlocked: Yes (19/20)
Attempted: Yes
Result:    10/10

**Scenario:** Changing instruction 3 of 8 causes a full 9-minute rebuild despite caching.
**Diagnosis (5/5):** Docker can't know whether downstream layers would produce the same result after a change, so it rebuilds all layers after the changed one to be safe. Cache invalidation cascades downward.
**Fix (5/5):** Order instructions by frequency of change — least-changing first, most-changing last. Demonstrated with the exact pattern:
- Incorrect: COPY . → pip install (app code change triggers pip reinstall)
- Correct: COPY requirements.txt → pip install → COPY . (pip layer cached unless dependencies change)

This is the canonical production Dockerfile pattern, reasoned from first principles before writing a single Dockerfile.
