# Sprint 06 — Container Networking
**Score:** 20/20  (Concept: 9/10 | Execution: 10/10 | Speed: +1)
**Date:** 2026-04-10
**Duration:** Approx 28 min

---

## What You Got Right
- **Network isolation model** — You understood that containers are invisible to each other by default unless explicitly connected. You didn't assume "same host = can talk."
- **Default bridge limitation** — You immediately identified that the default bridge network has no DNS resolution, only IP-based communication, and explained why that's fragile.
- **Custom network DNS** — You explained Docker's embedded DNS precisely: container name becomes hostname, IP changes don't break connections, names are stable.
- **Multi-network bridging** — You demonstrated that a container can have interfaces on multiple networks, acting as a bridge between isolated network segments.

## What You Missed
- **Published ports vs network ports** — You used `-p 8000:8000` to access the API from your browser (host → container). But you didn't explicitly distinguish that: published ports are for **host access**, internal network communication (api → postgres) doesn't need `-p` at all. Postgres was never published, yet the API reached it fine — because they're on the same network. Minor conceptual gap, but it matters when debugging "why can't I reach this service?"

## Carry Forward
Networks isolate by default. In Sprint 07 you'll see Compose create a network automatically for all services in the compose file. That's why compose services can find each other by name without you manually running `docker network create`. Compose handles it. But the model you learned here — custom networks enable DNS — is exactly what Compose is doing under the hood.

## What This Teaches About Production Systems
Hardcoded IPs are a production incident waiting to happen. A database container restarts during a deploy, gets a new IP, and suddenly every service that hardcoded `172.17.0.3` is dead. DNS-based service discovery (whether Docker's embedded DNS, Kubernetes DNS, or Consul) is the difference between a system that heals itself and a system that pages you at 2am because someone restarted a container. You learned this on Sprint 06 with two containers. In Kubernetes (Sprint 15) it's the same concept scaled to hundreds of pods across dozens of nodes — names, not IPs, always.

## Bonus Challenge
Unlocked: Yes (20/20)
Attempted: Yes
Result: 10/10

**Scenario:** API shows `"db":"disconnected"` with error "Name or service not known" even though all containers are running and attached to the network.

**Diagnosis:** Hostname mismatch in DATABASE_URL. Used `postgre` instead of `postgres`. DNS cannot resolve a container name that doesn't exist on the network. Not a connectivity issue — a name resolution failure.

**Fix:** Recreated API container with correct hostname in DATABASE_URL. DNS resolved `postgres` to the running container. Health check restored.

**What this teaches:** DNS errors (`Name or service not known`) mean the hostname doesn't exist on the network. Always verify: (1) container is running, (2) container is on the right network, (3) connection string uses the exact container name. Typos in hostnames are silent until runtime.
