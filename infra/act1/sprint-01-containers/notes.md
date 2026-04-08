# Sprint 01 — Containers & the Docker Mental Model

## My Understanding

### Docker 3-Layer Architecture

```
YOU
 │  type commands
 ▼
┌─────────────────┐
│   Docker CLI    │  ← the waiter. Takes your order. Does no cooking.
│   (docker)      │     Translates commands into API calls.
└────────┬────────┘
         │  API call over unix socket
         ▼
┌─────────────────┐
│  Docker Daemon  │  ← the kitchen. Does ALL the real work.
│  (dockerd)      │     Pulls images, creates containers,
│                 │     manages networks, volumes, everything.
└────────┬────────┘
         │  pulls from
         ▼
┌─────────────────┐
│   Docker Hub    │  ← the supplier. Stores images.
│  (registry)     │     Public. Anyone can push or pull.
└─────────────────┘
```

**What happens when I run this command:**

```shell
docker run --name redis-test -p 6379:6379 redis:7-alpine
```

1. **Pull** — Docker checks locally for image `redis:7-alpine`. Not found. Fetches from Docker Hub.
2. **Create** — Docker builds a container from the image.
3. **Start** — Redis process started inside it, listening on port 6379.

**Note:** After running the command, the prompt is not returned. The terminal is blocked because we are attached to the container's stdout. This is **foreground mode**. To run it in background mode and return the prompt once it is executed, we need to run it with `-d` option (detached mode).

---

### Container Lifecycle

```
docker run
    │
    ▼
┌─────────┐    docker stop     ┌─────────┐    docker rm    ┌─────────┐
│ RUNNING │ ───────────────→  │ STOPPED │ ─────────────→  │ REMOVED │
└─────────┘                   └─────────┘                  └─────────┘
    ▲                              │
    └──────────────────────────────┘
           docker start
```

**Key commands:**

```shell
# Identify currently running containers
docker ps

# Stop the container redis-test that we created earlier
docker stop redis-test
```

Rerun `docker ps` command to check if the container is stopped. `docker ps` command will not show `redis-test`. The container is stopped here — it still exists and is not deleted. To see all existing containers including containers that are not running:

```shell
docker ps -a
```

**Start a new container with the same image:**

```shell
docker run -d --name redis-test2 -p 6379:6379 redis:7-alpine
```

`docker inspect` command gives the full metadata of the container. Network settings include the internal IP Address of the container.

```shell
docker inspect redis-test2
```

`docker logs` provides logs of the container:

```shell
docker logs redis-test2
```

**Remove the container redis-test we created initially:**

```shell
docker rm redis-test
```

When a container is removed, all its contents are also removed. Both `docker ps` and `docker ps -a` will not show the container details. Note that this deletes only the container and not the image.

---

### Port Mapping

The `-p` flag in the `docker run` command maps the host machine port to the container port (`-p 6379:6379`). Without this mapping, though the container is running, it will not be reachable from the host machine as they run in isolation.

**Format:** `-p host:container`

`docker inspect` network settings will give the container IP Address. Suppose that IP is `172.17.0.2` — that's the container's address inside the Docker network. Your Mac cannot reach it directly. The only reason `localhost:6379` works is because of `-p 6379:6379`, which punches a hole:

**host port 6379 → maps to → container port 6379**

Remove that flag and the container is completely unreachable from your machine, even though it's running fine.

**WITHOUT -p:**
```
┌─────────────────────────────────────┐
│  Your Mac                           │
│                                     │
│  ┌─────────────────────────────┐    │
│  │  Container                  │    │
│  │  redis listening on :6379 ✅│    │
│  │  (nobody outside can reach) │    │
│  └─────────────────────────────┘    │
│                                     │
│  curl localhost:6379 → ❌ refused   │
└─────────────────────────────────────┘
```

**WITH -p 6379:6379:**
```
┌─────────────────────────────────────┐
│  Your Mac                           │
│                                     │
│  :6379 ──────────────────────┐      │
│                              ▼      │
│  ┌─────────────────────────────┐    │
│  │  Container                  │    │
│  │  redis listening on :6379 ✅│    │
│  └─────────────────────────────┘    │
│                                     │
│  curl localhost:6379 → ✅ works     │
└─────────────────────────────────────┘
```

---

## Phase 3 Challenge — The Missing Port Mapping

**Scenario:**  
A colleague hands you this command and says "Redis is running but I can't connect to it":

```shell
docker run -d --name redis-broken redis:7-alpine
```

`docker ps` shows it's running. But `redis-cli -h localhost -p 6379 ping` returns an error. Diagnose it. Explain exactly what's wrong and why. Then fix it with a new docker run command.

---

### My Diagnosis

**Error:** Could not connect to Redis at localhost:6379: Connection refused

**Investigation steps:**
1. `docker ps` — in the output, PORTS column indicates there is no mapping. It shows only the container port `6379/tcp` (no host mapping)
2. `docker inspect` — PortBindings section is empty
3. `docker logs` — indicate the container is listening on port 6379

**Root cause:**  
We are getting this error because the host port is not mapped to the container port. This is a characteristic feature of a container — it has isolated network and process. So we need to map the port so we can reach it from localhost.

---

### The Fix

```shell
docker run -d --name redis-fixed -p 6379:6379 redis:7-alpine
```

**Verification:**

1. `redis-cli -h localhost -p 6379 ping` → Output: **PONG** ✅
2. `docker ps` → PORTS column shows: `0.0.0.0:6379->6379/tcp` (port is mapped)
3. `docker inspect` → PortBindings present:
   ```json
   "PortBindings": {
       "6379/tcp": [
           {
               "HostIp": "",
               "HostPort": "6379"
           }
       ]
   }
   ```
4. `docker logs` → container is healthy, ready to accept connections

---

## Bonus Challenge — The Container Name Conflict

**Scenario:**  
You stop `redis-fixed` and then run:

```shell
docker run -d --name redis-fixed -p 6379:6379 redis:7-alpine
```

Docker throws an error immediately. The container never starts. `redis-fixed` isn't running — `docker ps` confirms it. So why is it failing?

---

### My Diagnosis and Fix

**Why it's failing:**

1. There is already a container named `redis-fixed`
2. `redis-fixed` was stopped and not deleted — `docker ps -a` says the container exited. It is not active but still exists
3. `docker inspect redis-fixed` says the status is "Exited" and "Dead": false — it also has a unique ID
4. `docker run` creates a new container, rather than start an existing one, so Docker needs a unique name to start a new container

**What happens in the background:**

When I run `docker run` command with an already existing container name, the Docker engine receives the request. It goes through its internal ledger to see if the container name exists. If it exists, it will throw an error. If the container is deleted and then `docker run` command is run with the same container name, it will create a new container. But when it is already existing (even in stopped state), it will not create a new one.

**The fix:**

```shell
# Option 1: Remove the stopped container first
docker rm redis-fixed
docker run -d --name redis-fixed -p 6379:6379 redis:7-alpine

# Option 2: Use docker start instead of docker run
docker start redis-fixed

# Option 3: Use --rm flag so container auto-deletes when stopped
docker run -d --rm --name redis-temp -p 6379:6379 redis:7-alpine
```
