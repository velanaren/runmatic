# Sprint 05 — Volumes & Persistence
**Score:** 20/20  (Concept: 9/10 | Execution: 10/10 | Speed: +1)
**Date:** 2026-04-09
**Duration:** Approx 28 min

---

## What You Got Right
- **Lifecycle separation mental model** — you immediately understood that containers are ephemeral but data must be persistent, and volumes decouple those two lifecycles
- **Independent discovery** — spotted that postgres creates anonymous volumes automatically via the VOLUME instruction in its Dockerfile, and tested reusing the anonymous volume by name
- **Backup/restore without hints** — used Alpine as a tool container, correctly applied `:ro` flag on source, created a new volume name for the restore instead of overwriting, verified data after restore

## What You Missed
Nothing critical. The only depth missing was the technical detail of how Docker manages volume storage under the hood — the driver abstraction that lets you swap `local` for network storage drivers like NFS or cloud block storage. That becomes relevant in Kubernetes (Sprint 17) when you'll see the same pattern at cluster scale: PersistentVolume + PersistentVolumeClaim.

## Carry Forward
Anonymous volumes are orphans waiting to fill your disk. Every `docker run postgres` without `-v` creates a new one. They survive `docker rm` but nobody knows what they're for. `docker volume prune` cleans them up, but you have to remember to run it. In Sprint 07 when you write docker-compose.yml, you'll define volumes explicitly in the YAML — every volume gets a name, no more orphans.

## What This Teaches About Production Systems
A database container without a volume is a time bomb. It works perfectly in testing — until someone runs `docker stop && docker start` and 10,000 customer records vanish. This isn't hypothetical. Early Docker adopters lost production data this way because they didn't understand that container filesystems are ephemeral by design. The postgres image creates an anonymous volume to protect you from this, but anonymous volumes are invisible in `docker volume ls` output (just hex hashes) — so teams forget they exist, run `docker volume prune` to clean up disk space, and accidentally delete live data. Named volumes make the dependency explicit. In YAML (Compose, Kubernetes), in documentation, in runbooks. The data's location is declared, tracked, backed up. Thinking about this on Sprint 05 means you're already designing for data durability, not just "does it start."

## Bonus Challenge
Unlocked: Yes — 20/20
Attempted: Yes
Result: 10/10

### Challenge: The Case of the Vanishing Data
**Symptom:** PostgreSQL container running, volume mounted, but all tables gone.

**Root Cause Identified:**
Container restarted without the `-v runmatic-postgres-data:/var/lib/postgresql/data` flag. Postgres's Dockerfile has `VOLUME /var/lib/postgresql/data`, so Docker auto-created an anonymous volume. The container started with an empty filesystem. The named volume still exists with all the data, but nothing is using it.

**Diagnostic Process:**
1. Check if named volume has data: `docker run --rm -v runmatic-postgres-data:/check alpine ls -la /check`
2. Check for orphaned volumes: `docker volume ls -f dangling=true`
3. Inspect container mounts: `docker inspect postgres | grep -A 10 Mounts` — would show anonymous volume, not named volume
4. Identified shadow mount scenario: when explicit volume conflicts with Dockerfile `VOLUME` directive or env-based auto-creation

**Fix:**
Stop container, restart with correct volume mount flag, or copy data from anonymous volume to named volume if data was written to the wrong location.

**Production Impact:**
This is a common incident pattern. An engineer troubleshoots by "restarting clean" and forgets the volume mount flag. The app starts fine (no startup errors), but all historical data is invisible. The data isn't deleted — it's orphaned. This is why infrastructure-as-code (Compose, Kubernetes manifests) is critical: the volume mount is declared in a file, versioned in git, never forgotten during a restart.
