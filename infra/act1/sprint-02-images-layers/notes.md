# Sprint 02 — Images & Layers

## My Understanding

### What is an Image?

An image is a **read-only snapshot of a filesystem** — plus metadata that tells Docker what command to run when a container starts.

```
Image (recipe):
┌─────────────────────────────────┐
│  Filesystem snapshot            │  ← exact files, exact versions
│  Environment variables          │  ← runtime configuration
│  Metadata: what command to run  │  ← e.g. "start uvicorn"
│  READ ONLY. Never changes.      │
└─────────────────────────────────┘

Container (meal cooked from recipe):
┌─────────────────────────────────┐
│  Running instance of the image  │
│  Has its own writable layer     │  ← can write files, generate logs
│  Lives and dies independently   │
└─────────────────────────────────┘
```

---

### Layers — The Building Blocks of Images

An image is not one big file — it is a **stack of independent layers**. Each layer is one instruction that changed the filesystem.

```
Layer 4: COPY app code          ← your application
    ▲
Layer 3: RUN pip install        ← your dependencies  
    ▲
Layer 2: RUN apt-get install    ← system packages
    ▲
Layer 1: Ubuntu 22.04 base      ← the OS filesystem
```

---

### Working with Images

**Pull an image from Docker Hub:**

```shell
docker pull python:3.11-slim
```

When we pull the same image again, we get the message: "Image is up to date for python:3.11-slim" and it displays a digest value, indicating there is no change in the image and the digest value of the first pulled image and now is the same.

**List all images downloaded:**

```shell
docker image ls
```

**See how each layer is stacked in the image:**

```shell
docker image history python:3.11-slim
```

**See the metadata of the image:**

```shell
docker image inspect python:3.11-slim
```

The `RootFS` section in the above command will give the number of filesystem layers.

---

### History vs Inspect — The Difference

In my test case:
- `docker image history` gave **10 layers**
- `docker image inspect` RootFS gave **4 layers**

**Why the difference?**

- **`docker image history`** shows every build instruction, including zero-size metadata steps like `ENV`, `CMD`, `LABEL`. These are recorded but write nothing to disk.
- **`docker image inspect` RootFS** shows only layers that actually changed the filesystem. These are the real layers. 4 layers = 4 times something was written to disk.

---

## Phase 3 Challenge — Shared Layers & Disk Usage

**Scenario:**  
You have `python:3.11-slim` on disk. Run this:

```shell
docker pull python:3.12-slim
```

Watch the output carefully as it pulls. Then run:

```shell
docker image ls
docker image inspect python:3.12-slim
```

**Two questions:**

1. During the pull — which lines said "Already exists"? Which downloaded fresh?
2. `docker image ls` shows a size for each image. Add them up. Now run `docker system df` — what does the actual disk usage say? Explain the difference.

---

### My Observations

**During the pull of python:3.12-slim:**

```
3.12-slim: Pulling from library/python
f4badedbec24: Already exists 
e154f12a68d4: Pull complete 
41a4e6de4142: Pull complete 
bf2133636eec: Pull complete
```

Docker pulls images bottom-up. The very first layer is the base layer — which is the Debian OS:

```
debian.sh --arch 'arm64' out/ 'trixie' '@1773619200'
```

This is the same base layer as in `python:3.11-slim`.

**Finding the common layer:**

```shell
comm -12 <(docker image inspect python:3.11-slim --format '{{range .RootFS.Layers}}{{.}}{{"\n"}}{{end}}' | sort) \
         <(docker image inspect python:3.12-slim --format '{{range .RootFS.Layers}}{{.}}{{"\n"}}{{end}}' | sort)
```

**Output:**  
`sha256:dbd35b2200dce25964b5371e8221a0b6c8638a6d86d76e2b1795b7584c5d4428`

This is the shared Debian base layer.

---

### Disk Usage Analysis

**From `docker image ls`:**

- `python:3.11-slim` → 150MB
- `python:3.12-slim` → 144MB
- **Sum total:** 294MB

**From `docker system df -v`:**

```
REPOSITORY  TAG        SIZE   SHARED SIZE  UNIQUE SIZE
python      3.11-slim  150MB  100.5MB      49.17MB
python      3.12-slim  144MB  100.5MB      43.89MB
```

**Actual disk usage:**  
100.5MB (shared) + 49.17MB (unique to 3.11) + 43.89MB (unique to 3.12) = **193.56MB**

**Why is `docker system df` size smaller than the sum total of size in `docker image ls`?**

The image sizes are almost identical, but the **shared size is 100.5MB** — the base Debian OS layer, which was not downloaded when we pulled 3.12 as it was already available from 3.11.

```
Image A (3.11)                    Image B (3.12)
┌─────────────────────┐          ┌─────────────────────┐
│ Layer 4: api code   │          │ Layer 4: worker code │
├─────────────────────┤          ├─────────────────────┤
│ Layer 3: pip deps   │          │ Layer 3: pip deps    │
├─────────────────────┤          ├─────────────────────┤
│ Layer 2: python3.11 │◄─────────► Layer 2: python3.12 │
├─────────────────────┤          ├─────────────────────┤
│ Layer 1: Debian     │◄─────────► Layer 1: Debian      │
└─────────────────────┘  SHARED  └─────────────────────┘ 
                         ON DISK
```

**KEY INSIGHT:**  
Layers are content-addressed (SHA256). If two images have identical layers, Docker stores them once. This is why pulling related images is fast and why disk usage is far less than the sum of image sizes.

---

## Bonus Challenge — The Caching Disaster

**Scenario:**  
A Dockerfile has 8 instructions. A developer changes instruction 3 and rebuilds. The build takes 9 minutes — same as a clean build with no cache at all.

They complain: "Docker caching is broken."

They're wrong. What's actually happening, and what's the fix? No commands needed — this is pure reasoning.

---

### My Answer

**The Wrong Assumption:**

The developer assumes caching is automatic. It is not the case. If layer 3 is changed, Docker doesn't know whether other layers 4, 5, 6, 7, 8 would produce the same result, so it rebuilds them all to be safe.

**The Cache Invalidation Rule:**

```
Change a layer → that layer rebuilds
                 → every layer AFTER it rebuilds too
                 → every layer BEFORE it stays cached
```

**The Fix:**

The instructions should be ordered such that:
- **Files that change LEAST frequently** → TOP of Dockerfile
- **Files that change MOST frequently** → BOTTOM of Dockerfile

If the developer is changing instruction 3 — which could be the app code that changes frequently — then it should be copied last.

---

### Example

**Incorrect order:**

```dockerfile
Layer 1 - FROM python:3.11-slim      # Cached ✅
Layer 2 - COPY . /app                # Changed → Rebuilds ❌
Layer 3 - RUN pip install            # Rebuilds (cache invalidated) ❌
```

Every code change forces `pip install` to rerun — wasting minutes.

**Correct order (files that change most frequently should be copied last):**

```dockerfile
Layer 1 - FROM python:3.11-slim      # Cached ✅
Layer 2 - COPY requirements.txt .    # Cached ✅
Layer 3 - RUN pip install            # Cached ✅
Layer 4 - COPY . /app                # Changed → Rebuilds ❌
```

Now `pip install` only reruns when dependencies change, not on every code edit.

**Real-world impact:**  
This isn't academic — it's the difference between a 2-minute CI pipeline and a 20-minute one. In a team running 50 deploys a day, a poorly ordered Dockerfile burns hours of developer time every week.
