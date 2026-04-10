# Sprint 06 — Container Networking — Notes

## Phase 1 — The Hook

**Claude's Explanation:**

You've configured Splunk forwarders to send logs to indexers by hostname — `indexer-01.prod`, not `10.45.2.18` — because IPs change. Container networking is the same idea.

Right now, if you start postgres and then start the API, you'd need to find postgres's IP with `docker inspect`, hardcode it in DATABASE_URL, and pray it doesn't change on the next restart. That's fragile and absurd.

Docker networks give you **internal DNS**. Containers on the same custom network can reach each other by name. `postgres` as a hostname, not an IP. The name is stable. The IP is managed by Docker.

**First Test — Prove the Problem:**

Commands to run:
```bash
docker run -d --name postgres-test -e POSTGRES_PASSWORD=devpassword postgres:15-alpine
docker inspect postgres-test --format '{{.NetworkSettings.IPAddress}}'
```

**My Result:**
```
172.17.0.2
```

As the network is not specified it goes to the default bridge, any containers now run will go to default bridge.

I tried running another container with name `postgres-test-2` and ran `docker network inspect bridge` — both containers are listed:

```json
"Containers": {
    "8a110f66e53014401e2f8436b7f56ff5eb3ca7d214b70f2e19d86fabad658eb4": {
        "Name": "postgres-test",
        "EndpointID": "1826ec88d26232a42d72f13c82f510323333831cc4bf5a8abef7556e075a6ca4",
        "MacAddress": "2e:79:4b:d0:b7:04",
        "IPv4Address": "172.17.0.2/16",
        "IPv6Address": ""
    },
    "f28099c136df9dbee5376fe125b4df2c005035573f4366f4e4df9818ec2e87f5": {
        "Name": "postgres-test-2",
        "EndpointID": "302ff316c11c94f2a9384d4a2c1a228f56044e94e785e2a505e869565cbe47cb",
        "MacAddress": "c2:04:64:08:36:82",
        "IPv4Address": "172.17.0.3/16",
        "IPv6Address": ""
    }
}
```

**Claude's Next Step:**

Try to ping one container from the other **by name**:
```bash
docker exec postgres-test ping -c 2 postgres-test-2
```

Then try with IP:
```bash
docker exec postgres-test ping -c 2 172.17.0.3
```

**My Result:**

First one failed:
```
docker exec postgres-test ping -c 2 postgres-test-2  
ping: bad address 'postgres-test-2'
```

Second one was successful:
```
docker exec postgres-test ping -c 2 172.17.0.3
PING 172.17.0.3 (172.17.0.3): 56 data bytes
64 bytes from 172.17.0.3: seq=0 ttl=64 time=0.200 ms
64 bytes from 172.17.0.3: seq=1 ttl=64 time=0.150 ms

--- 172.17.0.3 ping statistics ---
2 packets transmitted, 2 packets received, 0% packet loss
round-trip min/avg/max = 0.150/0.175/0.200 ms
```

**Reason:** Though both containers are in same default bridge, they can connect only through IP address and not through hostname as the default network cannot resolve DNS. The problem this may cause — suppose I have to restart `postgres-test-2` and next time a new IP will be assigned. `docker exec postgres-test ping -c 2 172.17.0.3` will not connect to `postgres-test-2`.

I tried doing it. This time `postgres-test-2` is assigned 172.17.0.4:

```json
"Containers": {
    "8a110f66e53014401e2f8436b7f56ff5eb3ca7d214b70f2e19d86fabad658eb4": {
        "Name": "postgres-test",
        "MacAddress": "2e:79:4b:d0:b7:04",
        "IPv4Address": "172.17.0.2/16",
    },
    "c29772c5db1f5289f735fb8521f7fed5581939bd00c217b13c74f186a64446d5": {
        "Name": "postgres-test-2",
        "MacAddress": "3a:9a:76:1f:0a:a1",
        "IPv4Address": "172.17.0.4/16",
    },
    "c99199b7032c16fcc7d434a2dff325c8c08e064b4f15600c7085fd592881bfa2": {
        "Name": "postgres-test-3",
        "MacAddress": "3e:1a:34:86:20:d9",
        "IPv4Address": "172.17.0.3/16",
    }
}
```

That is why we should not rely on IP and we need to rely on name resolution.

**Claude's Response:**

Exactly right. You discovered the fundamental problem: **the default bridge has no DNS**. IPs shift. Hardcoding them is fragile.

---

## Phase 2 — The Build

**Done Condition:** API container connects to PostgreSQL using `DATABASE_URL=postgresql://postgres:5432/runmatic`. Health check shows db connected.

**My Commands:**

```bash
# Clean up test containers
docker rm -f postgres-test postgres-test-2 postgres-test-3

# Create custom bridge network
docker network create runmatic-net
docker network inspect runmatic-net

# Run postgres on custom network with stable name
docker run -d \
  --name postgres \
  --network runmatic-net \
  -e POSTGRES_DB=runmatic \
  -e POSTGRES_USER=runmatic \
  -e POSTGRES_PASSWORD=devpassword \
  postgres:15-alpine

# Test DNS works from another container
docker run --rm --network runmatic-net alpine ping -c 2 postgres

# Run Redis on same network
docker run -d \
  --name redis \
  --network runmatic-net \
  redis:7-alpine

# Run API with DATABASE_URL using hostname not IP
docker run -d \
  --name api \
  --network runmatic-net \
  -p 8000:8000 \
  -e DATABASE_URL=postgresql+asyncpg://runmatic:devpassword@postgres:5432/runmatic \
  -e REDIS_URL=redis://redis:6379/0 \
  -e SECRET_KEY=dev-secret-key-not-for-production \
  runmatic-api:latest
```

**Note:** I initially missed REDIS_URL. Claude reminded me Redis is a dependency. I also corrected the DATABASE_URL to use `postgresql+asyncpg` instead of just `postgresql`.

```bash
# Check API logs
docker logs api

# Hit health check
curl localhost:8000/health
```

**Result:**
```json
{"status":"healthy","db":"connected","cache":"connected","details":{}}
```

**Done condition met.**

I inspected the network to see all containers:
```bash
docker network inspect runmatic-net
```

All three containers visible: `postgres` (172.22.0.2), `redis` (172.22.0.3), `api` (172.22.0.4).

---

## Phase 3 — The Challenge

**Claude's Challenge:**

No hints for 5 minutes. Think out loud.

Right now all three containers are on `runmatic-net`. Explore these questions:

1. Can the API container reach postgres by IP instead of by name? Test it.
2. Create a **second network** called `runmatic-backend`. Move only postgres to that network (disconnect from runmatic-net, connect to runmatic-backend). What happens to the API's health check? Why?
3. Can you connect postgres to **both networks at once** so the API can reach it? How?

---

**My Exploration:**

### Question 1: Can API reach postgres by IP?

```bash
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
```

**Result:**
```json
{"status":"healthy","db":"connected","cache":"connected","details":{}}
```

**Answer:** Yes, it can reach as they are within the same network. DNS is a convenience, not a requirement — IPs work fine if you're on the same network. DNS just makes them stable and readable.

### Question 2: Move postgres to a different network

```bash
# Create second network
docker network create runmatic-backend

# Verify no containers initially
docker network inspect runmatic-backend

# Connect postgres to new network
docker network connect runmatic-backend postgres

# Verify postgres now on runmatic-backend
docker network inspect runmatic-backend
```

Output shows postgres on `runmatic-backend` with IP 172.23.0.2.

```bash
# Disconnect postgres from runmatic-net
docker network disconnect runmatic-net postgres

# Check health endpoint
curl localhost:8000/health
```

**Result:**
```json
{"status":"degraded","db":"disconnected","cache":"connected","details":{"db_error":"[Errno 113] No route to host"}}
```

**Why:** API is not able to connect to postgres as postgres is in a different network (`runmatic-backend`) and it is isolated from `runmatic-net`. Container in one custom network cannot speak to containers in another custom network.

### Question 3: Connect postgres to both networks

```bash
# Connect postgres back to runmatic-net (while still on runmatic-backend)
docker network connect runmatic-net postgres

# Verify postgres on both networks
docker network inspect runmatic-net
docker network inspect runmatic-backend
```

**Observations:**
- `runmatic-net` shows: postgres (172.22.0.2), redis (172.22.0.3), api (172.22.0.4)
- `runmatic-backend` shows: postgres (172.23.0.2)

Postgres now has **TWO network interfaces** — one on each network.

```bash
curl localhost:8000/health
```

**Result:**
```json
{"status":"healthy","db":"connected","cache":"connected","details":{}}
```

**Answer:** Yes! Postgres can be on multiple networks simultaneously. It acts as a bridge between isolated network segments. This is how you'd isolate a database — frontend containers on `runmatic-net`, database containers on `runmatic-backend`, API straddling both.

**Claude's Feedback:**

Flawless. You just proved three critical concepts:

1. **DNS is a convenience, not a requirement** — IPs work fine if you're on the same network. DNS just makes them stable and readable.
2. **Network isolation is real** — disconnect postgres from runmatic-net and the API loses its route. Networks are invisible walls.
3. **Multi-network containers bridge networks** — postgres has TWO network interfaces, can talk to both. This is production network segmentation.

Clean up:
```bash
docker rm -f api postgres redis
docker network rm runmatic-net runmatic-backend
```

---

## Phase 4 — Explanation

**Claude's Question:**

Explain Docker container networking in 3 sentences. Pretend you're explaining it to a support engineer who's never heard of Docker. Don't look anything up.

**My Answer:**

Network isolation is by default. Each container gets its own network namespace, its own IP address, its own routing table. Inside a container, other containers are invisible unless we explicitly connect them. The assumption that all containers in same machine can talk to each other is wrong. It has a limitation.

When we don't specify a network docker uses the default bridge network (it is created when docker is installed). With a default bridge network we can connect to other containers in the host only with the IP address. The default bridge does not resolve DNS.

The fix is custom networks. When a custom network is created Docker's embedded DNS activates. For every container on the custom network the container name becomes hostname and now they can speak to each other with the hostname. Even if IP changes the containers can continue to speak using hostname. This fixes the issue with default bridge network.

Container in one custom network cannot speak to containers in another custom network. For any container to communicate with another container they need to be part of same custom network. A container can be part of many custom networks.

**Claude's Feedback:**

Nailed isolation, DNS, custom networks, multi-network containers. Only missed: published ports (`-p`) are for host access, not needed for container-to-container communication on the same network. Minor gap — the core model is flawless.

---

## Bonus Challenge — DNS Name Resolution Failure

**Claude's Scenario:**

You start three Runmatic containers: `api`, `postgres`, and `redis`. All three on `runmatic-net`. Everything works — health check is green.

You stop the containers and restart them. Now the API logs show:
```
sqlalchemy.exc.OperationalError: (psycopg.OperationalError) connection failed: 
Name or service not known
```

`docker ps` shows all three containers running. `docker network inspect runmatic-net` shows all three attached. But health check returns `{"status":"degraded","db":"disconnected"}`.

The compose file hasn't changed. The network exists. The containers are running and attached. DNS worked before the restart. What's wrong?

---

**My Investigation:**

I simulated the failure by intentionally using wrong hostname in DATABASE_URL:

```bash
# Started all 3 containers
docker run -d \
  --name postgres \
  --network runmatic-net \
  -e POSTGRES_DB=runmatic \
  -e POSTGRES_USER=runmatic \
  -e POSTGRES_PASSWORD=devpassword \
  postgres:15-alpine

docker run -d \
  --name redis \
  --network runmatic-net \
  redis:7-alpine

# API with WRONG hostname: postgre instead of postgres
docker run -d \
  --name api \
  --network runmatic-net \
  -p 8000:8000 \
  -e DATABASE_URL=postgresql+asyncpg://runmatic:devpassword@postgre:5432/runmatic \
  -e REDIS_URL=redis://redis:6379/0 \
  -e SECRET_KEY=dev-secret-key-not-for-production \
  runmatic-api-v1:latest
```

**Verification:**

```bash
docker ps  # All 3 running
docker network inspect runmatic-net  # All 3 attached
curl localhost:8000/health
```

**Result:**
```json
{"status":"degraded","db":"disconnected","cache":"connected","details":{"db_error":"[Errno -2] Name or service not known"}}
```

**Diagnosis:**

Hostname mismatch in DATABASE_URL. Used `postgre` instead of `postgres`. DNS cannot resolve a container name that doesn't exist on the network. Not a connectivity issue — a **name resolution failure**.

**Fix:**

```bash
docker stop api
docker rm api

docker run -d \
  --name api \
  --network runmatic-net \
  -p 8000:8000 \
  -e DATABASE_URL=postgresql+asyncpg://runmatic:devpassword@postgres:5432/runmatic \
  -e REDIS_URL=redis://redis:6379/0 \
  -e SECRET_KEY=dev-secret-key-not-for-production \
  runmatic-api-v1:latest

curl localhost:8000/health
```

**Result:**
```json
{"status":"healthy","db":"connected","cache":"connected","details":{}}
```

**Claude's Feedback:**

**Bonus Score: 10/10**

- Diagnosis: 5/5 — Identified root cause: hostname mismatch. Explained DNS can't resolve a name that doesn't exist.
- Fix: 5/5 — Recreated API container with correct hostname. Verified with health endpoint. Clean.

**Real-world note:** This exact scenario happens when someone copies a docker run command from Slack, spots a typo, fixes it in their head but not in the command, and wonders why "the network is broken." It's never the network. It's always the typo.

---

## Key Takeaways

1. **Default bridge has no DNS** — containers can only communicate via IP, which changes on restart
2. **Custom networks enable DNS** — container name becomes hostname, IP changes don't break connections
3. **Networks isolate by default** — containers on different networks can't communicate unless explicitly connected
4. **Multi-network containers act as bridges** — one container can have interfaces on multiple networks
5. **DNS errors mean name resolution failure** — verify container name matches hostname in connection string
6. **Published ports (-p) are for host access** — containers on same network communicate internally without -p
7. **In Sprint 07 Compose will auto-create networks** — all services in compose file get DNS automatically
