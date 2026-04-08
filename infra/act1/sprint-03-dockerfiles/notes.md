# Sprint 03 — Writing Dockerfiles

## My Understanding

### What is a Dockerfile?

A Dockerfile is a **sequence of instructions** that Docker executes to build an image, one layer at a time. We have provisioned servers manually before:

1. Login
2. Install Python
3. Install packages
4. Copy app code
5. Configure the start command

A Dockerfile is the exact same process, **written as code**. It runs identically on any machine.

```
Manual server setup:          Dockerfile equivalent:
----------------------        ----------------------
Start with Ubuntu         →   FROM ubuntu:22.04
Install Python            →   RUN apt-get install python3
Copy requirements.txt     →   COPY requirements.txt .
pip install               →   RUN pip install -r requirements.txt
Copy app code             →   COPY . /app
Start the app             →   CMD ["uvicorn", "main:app"]
```

**KEY DIFFERENCE:**  
`CMD` runs only when the **container is started**. All other commands execute during **BUILD time**.

---

### Building the Runmatic API Dockerfile

We need to build an image for `runmatic-api`. The required code is in `app/api` folder:

- 2 folders: `app/`, `migrations/`
- 2 files: `alembic.ini`, `requirements.txt`

All of this has to be copied into the Dockerfile.

**My Dockerfile:**

```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
COPY alembic.ini .
RUN pip install --no-cache-dir -r requirements.txt
COPY migrations ./migrations
EXPOSE 8000
COPY app ./app
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

---

### Dockerfile Instructions Explained

| Command               | Details                                                      |
|-----------------------|--------------------------------------------------------------|
| `FROM python:3.11-slim` | Every image starts with another image. Here we are using the already downloaded `python:3.11-slim`. |
| `WORKDIR /app`        | Sets the working directory for everything that follows. Without this, files land in `/` (root). |
| `COPY`                | Copy the files/folders to the destination in the image.      |
| `RUN pip install`     | Runs this during build time. Installed packages are frozen in a layer. |
| `EXPOSE 8000`         | **Documentation only**. It just says the container listens on port 8000. |
| `CMD`                 | Command that runs when the container starts.                 |

---

### Building and Running the Image

**Build command:**

```shell
docker build -t runmatic-api-v1 -f infra/act1/sprint-03-dockerfiles/Dockerfile.api app/api
```

**Run command:**

```shell
docker run -d -p 8000:8000 --name api-test runmatic-api-v1
```

**The build context is `app/api`** — this is where all the required files are available.

---

## Layer Caching Strategy

The **order** in which the commands are written is crucial for build speed.

```
Most stable content   → TOP of Dockerfile
Most changing content → BOTTOM of Dockerfile
```

Consider the Dockerfile above: **code** is the one that changes most often, so it is at the **bottom** of the Dockerfile.

---

### Experiment 1: Code Change with Correct Order

I added a comment to the end of `main.py` and ran the build command again.

```shell
time docker build -t runmatic-api-v1 -f infra/act1/sprint-03-dockerfiles/Dockerfile.api app/api
```

**Output:**

```
[+] Building 0.1s (12/12) FINISHED
=> CACHED [2/7] WORKDIR /app
=> CACHED [3/7] COPY requirements.txt .
=> CACHED [4/7] COPY alembic.ini .
=> CACHED [5/7] RUN pip install --no-cache-dir -r requirements.txt
=> CACHED [6/7] COPY migrations ./migrations
=> [7/7] COPY app ./app  ← ONLY this layer rebuilt
```

**Build time: 0.1s**

Layers 1–6 were cached. Only the `COPY app` layer was rebuilt.

---

### Experiment 2: Code Change with Wrong Order

I moved the `COPY app` command to right after `WORKDIR` (instruction 3), then added another comment to `main.py` and rebuilt.

**Modified Dockerfile order (WRONG):**

```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY app ./app               ← moved up
COPY requirements.txt .
COPY alembic.ini .
RUN pip install --no-cache-dir -r requirements.txt  ← rebuilds!
COPY migrations ./migrations
```

**Rebuild output:**

```shell
time docker build -t runmatic-api-v1 -f infra/act1/sprint-03-dockerfiles/Dockerfile.api app/api
```

```
[+] Building 29.5s (12/12) FINISHED
=> CACHED [2/7] WORKDIR /app
=> [3/7] COPY app ./app                                ← changed
=> [4/7] COPY requirements.txt .                       ← rebuilds
=> [5/7] COPY alembic.ini .                            ← rebuilds
=> [6/7] RUN pip install --no-cache-dir -r requirements.txt  ← rebuilds (28.8s!)
=> [7/7] COPY migrations ./migrations                  ← rebuilds
```

**Build time: 29.5s** (compared to 0.1s with correct order)

**KEY INSIGHT:**

Every time there is a code change, **all layers from `COPY app` onward** will rebuild. This includes `pip install`, which takes the most time (28.8s).

**The cache invalidation rule:**

```
Change a layer → that layer rebuilds
                 → every layer AFTER it rebuilds too
                 → every layer BEFORE it stays cached
```

**Comparison:**

- **Correct order** (app code last): 0.1s build
- **Wrong order** (app code early): 29.5s build
- **Difference:** 295x slower

---

## Exec Form vs Shell Form in CMD

There are two ways in which `CMD` can be formatted: **Exec form** and **Shell form**.

**Shell form:**

```dockerfile
CMD uvicorn main:app --host 0.0.0.0
```

**Exec form:**

```dockerfile
CMD ["uvicorn", "main:app", "--host", "0.0.0.0"]
```

They look almost identical. The difference is **what Docker actually runs**.

---

### Shell Form — What Happens Under the Hood

Docker runs:

```
/bin/sh -c "uvicorn main:app --host 0.0.0.0"
```

**Process tree inside container:**

```
PID 1: /bin/sh      ← shell is PID 1
PID 2: uvicorn      ← your app is PID 2
```

---

### Exec Form — What Happens Under the Hood

Docker runs:

```
uvicorn main:app --host 0.0.0.0
```

**Process tree inside container:**

```
PID 1: uvicorn      ← your app IS PID 1
```

---

### Why PID 1 Matters

When you run `docker stop`, Docker sends **SIGTERM** to PID 1 — "please shut down gracefully."

**Shell form:**

```
SIGTERM → /bin/sh (PID 1)
  /bin/sh does NOT forward signals to children
  uvicorn (PID 2) never receives SIGTERM
  uvicorn never shuts down gracefully
  Docker waits 10 seconds → sends SIGKILL → force kills everything
```

**Exec form:**

```
SIGTERM → uvicorn (PID 1) directly
  uvicorn receives signal → shuts down gracefully
  Connections close cleanly, no data corruption
```

---

### The Real-World Consequence

**Shell form** = every `docker stop` is a force kill after 10 seconds:
- Database connections dropped mid-transaction
- Requests cut off mid-response
- Logs not flushed

**Exec form** = clean shutdown:
- Connections drain properly
- Data integrity preserved
- Logs flushed

---

## .dockerignore File

`COPY . /app` will copy **everything** in a directory, including things you never want in an image.

`.dockerignore` is like `.gitignore` — it's used to exclude sensitive information or unnecessary files that don't need to be copied into the Docker image.

Anything included inside `.dockerignore` will never be part of the image.

**Common entries:**

```
.git
.env
__pycache__
*.pyc
node_modules
.vscode
.DS_Store
```

---

## Key Takeaways

1. **Dockerfile instruction order matters for build speed** — most stable at top, most changing at bottom.
2. **EXPOSE is documentation only** — it doesn't publish ports. Use `-p` to actually publish.
3. **Use exec form CMD** — ensures your app runs as PID 1 and receives SIGTERM for graceful shutdown.
4. **Layer caching** — change a layer → all layers after it rebuild. Order your instructions carefully.
5. **Use .dockerignore** — prevent secrets and unnecessary files from being copied into the image.
