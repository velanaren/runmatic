# Sprint 07 — Docker Compose v1
**Score:** 20/20  (Concept: 9/10 | Execution: 10/10 | Speed: +1)
**Date:** 2026-04-11
**Duration:** Approx 30 min

---

## What You Got Right

**Infrastructure as code, not shell script shortcuts.** You immediately understood that Compose isn't just syntactic sugar for docker run commands — it's a declaration of relationships. The file is versioned, reviewable, shareable. Compose understands dependencies, networks, and volumes as a coherent system, not isolated commands.

**The depends_on race condition and both solutions.** When you removed depends_on, you didn't just observe "it still works" — you explained why it worked locally (fast SSD, 108ms timing luck) and why it would fail in production (slow disk, longer postgres init). Then you named both solutions: health check conditions in Compose and retry logic in the application layer. That's production-level thinking.

**Service vs container name, published vs internal ports.** You observed that postgres and redis show `5432/tcp` and `6379/tcp` without host mapping, and correctly explained they don't need it — they're internal-only, reachable via the Compose network. The API publishes 8000 because browsers can't join Docker networks.

## What You Missed

**Brevity.** I asked for 3 sentences. You gave me a comprehensive decision tree and architecture essay. The content was excellent, but in an interview or incident channel, you'd need to condense. Practice the 3-sentence constraint — it forces you to identify the core insight and discard the rest. "Compose declares multi-container apps as code. It manages the network, volumes, and startup order as one unit. One file, one command, repeatable infrastructure."

## Carry Forward

Compose auto-creates a network and registers every service name as a DNS hostname. In Sprint 08 you'll add the worker service to this file — now you have four services (api, worker, postgres, redis) all talking to each other by name, still with one `docker compose up` command. The pattern scales. The network Compose creates is why you don't have to run `docker network create` manually anymore.

## What This Teaches About Production Systems

Docker Compose is the boundary between "works on my laptop" and "works on any laptop." Before Compose, every new engineer clones the repo, reads a 47-step README, runs commands in the wrong order, fights with port conflicts, and gives up. With Compose: `docker compose up`. The environment is identical. The startup order is guaranteed. The network is consistent. This is why Compose files live in the root of every microservice repo — they're the executable documentation of how to run the system. When interviewing, if a candidate can't explain what's in their docker-compose.yml, they don't understand their own infrastructure.

## Bonus Challenge
Unlocked: Yes
Attempted: Yes
Result: 10/10

### Bonus — Network Isolation Break-Fix

**Challenge:** API declared with explicit `networks: [backend]`, postgres/redis left without network declaration. API health check fails with "db: disconnected, cache: disconnected". Diagnose and fix.

**Diagnosis: 5/5** — Root cause identified immediately using `docker network inspect`. Proved that API joined `sprint-07-compose-v1_backend`, while postgres/redis joined `sprint-07-compose-v1_default`. Network isolation prevented DNS resolution. Showed complete container membership for both networks.

**Fix: 5/5** — Stated both valid solutions: (1) remove all explicit network declarations, let Compose auto-assign everything to default, or (2) add `networks: [backend]` to postgres and redis so all dependent services share one network. Explained the rule: when you add `networks:` to a service, Compose ONLY attaches it to those networks — it doesn't add default automatically anymore.

**Key insight:** This is production network segmentation. You can isolate database services from internet-facing services by putting them on separate networks, with the API bridging both. Defense-in-depth.
