#!/bin/bash
# Sprint 06 — Container Networking
# Goal: Connect API to PostgreSQL and Redis using hostnames instead of IPs
# Key question: How do containers find each other by name?

# === Phase 1: Prove the problem — default bridge has no DNS ===

# why: Run postgres on default bridge network
docker run -d --name postgres-test -e POSTGRES_PASSWORD=devpassword postgres:15-alpine
# what I saw: Container started on default bridge (172.17.0.0/16)

# why: Get the container's IP address
docker inspect postgres-test --format '{{.NetworkSettings.IPAddress}}'
# what I saw: 172.17.0.2

# why: Run a second postgres container on default bridge
docker run -d --name postgres-test-2 -e POSTGRES_PASSWORD=devpassword postgres:15-alpine

# why: Inspect default bridge network to see both containers
docker network inspect bridge
# what I saw: Both containers listed with sequential IPs (172.17.0.2 and 172.17.0.3)

# why: Try to ping by container NAME (this will FAIL)
docker exec postgres-test ping -c 2 postgres-test-2
# what I saw: ping: bad address 'postgres-test-2'
# KEY INSIGHT: Default bridge cannot resolve container names to IPs

# why: Try to ping by IP address (this will SUCCEED)
docker exec postgres-test ping -c 2 172.17.0.3
# what I saw: 2 packets transmitted, 2 received, 0% packet loss
# KEY INSIGHT: IP communication works, but IPs are not stable across restarts

# why: Restart postgres-test-2 to prove IP changes
docker restart postgres-test-2
docker network inspect bridge
# what I saw: postgres-test-2 now has 172.17.0.4 (or different IP)
# KEY INSIGHT: Hardcoded IPs break on restart. Need DNS.

# why: Clean up test containers
docker rm -f postgres-test postgres-test-2 postgres-test-3

# === Phase 2: Fix with custom network — DNS enabled ===

# why: Create custom bridge network
docker network create runmatic-net
# what I saw: Network ID returned

# why: Inspect the new network
docker network inspect runmatic-net
# what I saw: Empty network, subnet 172.22.0.0/16 (or similar)

# why: Run postgres on custom network with stable name
docker run -d \
  --name postgres \
  --network runmatic-net \
  -e POSTGRES_DB=runmatic \
  -e POSTGRES_USER=runmatic \
  -e POSTGRES_PASSWORD=devpassword \
  postgres:15-alpine
# what I saw: Container started

# why: Test DNS resolution from another container
docker run --rm --network runmatic-net alpine ping -c 2 postgres
# what I saw: ping successful! DNS resolved "postgres" to container's IP
# KEY INSIGHT: Custom networks enable Docker's embedded DNS

# why: Run Redis on same network
docker run -d \
  --name redis \
  --network runmatic-net \
  redis:7-alpine
# what I saw: Container started

# why: Run API with DATABASE_URL using HOSTNAME not IP
docker run -d \
  --name api \
  --network runmatic-net \
  -p 8000:8000 \
  -e DATABASE_URL=postgresql+asyncpg://runmatic:devpassword@postgres:5432/runmatic \
  -e REDIS_URL=redis://redis:6379/0 \
  -e SECRET_KEY=dev-secret-key-not-for-production \
  runmatic-api:latest
# what I saw: Container started
# Note: Initially forgot REDIS_URL, container failed. Added it, restarted, worked.

# why: Check API logs
docker logs api
# what I saw: Startup logs, database migrations ran, server listening on 0.0.0.0:8000

# why: Hit health check endpoint
curl localhost:8000/health
# what I saw: {"status":"healthy","db":"connected","cache":"connected","details":{}}
# KEY INSIGHT: API connected to postgres and redis using hostnames, not IPs

# why: Inspect network to see all containers
docker network inspect runmatic-net
# what I saw: postgres (172.22.0.2), redis (172.22.0.3), api (172.22.0.4)
# All on same network, DNS resolves names to IPs

# === Phase 3: Test network isolation ===

# why: Can API reach postgres by IP instead of hostname?
docker rm -f api
docker run -d \
  --name api \
  --network runmatic-net \
  -p 8000:8000 \
  -e DATABASE_URL=postgresql+asyncpg://runmatic:devpassword@172.22.0.2:5432/runmatic \
  -e REDIS_URL=redis://redis:6379/0 \
  -e SECRET_KEY=dev-secret-key-not-for-production \
  runmatic-api-v1:latest
curl localhost:8000/health
# what I saw: {"status":"healthy",...} — yes, IP works fine on same network
# KEY INSIGHT: DNS is convenience for stability, not a requirement

# why: Create a second network to test isolation
docker network create runmatic-backend
docker network inspect runmatic-backend
# what I saw: Empty network, different subnet (172.23.0.0/16)

# why: Connect postgres to the new network
docker network connect runmatic-backend postgres
docker network inspect runmatic-backend
# what I saw: postgres now on runmatic-backend with IP 172.23.0.2
# KEY INSIGHT: postgres now has TWO network interfaces

# why: Disconnect postgres from runmatic-net
docker network disconnect runmatic-net postgres
# what I saw: postgres removed from runmatic-net

# why: Check API health (this will FAIL)
curl localhost:8000/health
# what I saw: {"status":"degraded","db":"disconnected","cache":"connected","details":{"db_error":"[Errno 113] No route to host"}}
# KEY INSIGHT: API can't reach postgres — different networks are isolated

# why: Connect postgres back to BOTH networks
docker network connect runmatic-net postgres
docker network inspect runmatic-net
docker network inspect runmatic-backend
# what I saw: postgres on both networks (172.22.0.2 and 172.23.0.2)

# why: Check API health again
curl localhost:8000/health
# what I saw: {"status":"healthy",...} — connection restored
# KEY INSIGHT: Containers can join multiple networks, acting as bridges

# === Bonus Challenge: DNS name resolution failure ===

# why: Simulate typo in hostname — use "postgre" instead of "postgres"
docker rm -f api
docker run -d \
  --name api \
  --network runmatic-net \
  -p 8000:8000 \
  -e DATABASE_URL=postgresql+asyncpg://runmatic:devpassword@postgre:5432/runmatic \
  -e REDIS_URL=redis://redis:6379/0 \
  -e SECRET_KEY=dev-secret-key-not-for-production \
  runmatic-api-v1:latest
# what I saw: Container started (no errors at startup)

# why: Verify all containers running
docker ps
# what I saw: api, postgres, redis all running

# why: Verify all attached to network
docker network inspect runmatic-net
# what I saw: All 3 containers listed

# why: Check health endpoint
curl localhost:8000/health
# what I saw: {"status":"degraded","db":"disconnected",...,"db_error":"[Errno -2] Name or service not known"}
# KEY INSIGHT: DNS error — hostname "postgre" doesn't exist on the network

# why: Fix by recreating API with correct hostname
docker rm -f api
docker run -d \
  --name api \
  --network runmatic-net \
  -p 8000:8000 \
  -e DATABASE_URL=postgresql+asyncpg://runmatic:devpassword@postgres:5432/runmatic \
  -e REDIS_URL=redis://redis:6379/0 \
  -e SECRET_KEY=dev-secret-key-not-for-production \
  runmatic-api-v1:latest

# why: Verify fix worked
curl localhost:8000/health
# what I saw: {"status":"healthy",...}
# KEY INSIGHT: Always verify connection string hostname matches exact container name

# === Cleanup ===

# why: Remove all containers and networks
docker rm -f api postgres redis
docker network rm runmatic-net runmatic-backend

# === Key Takeaways ===
# 1. Default bridge (172.17.0.0/16) has NO DNS — only IP-based communication
# 2. Custom networks enable Docker's embedded DNS — container name = hostname
# 3. Networks are isolated — containers on different networks can't communicate
# 4. Containers can join multiple networks — acting as bridges between segments
# 5. Published ports (-p) are for HOST access, not container-to-container
# 6. DNS errors = name doesn't exist on network — verify exact container name
# 7. In Sprint 07 Compose auto-creates a network for all services in the file
