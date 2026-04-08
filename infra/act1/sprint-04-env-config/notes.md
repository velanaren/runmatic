# Sprint 04 — Environment & Configuration — Notes

## My Understanding

### Configuration Does Not Belong in Images

1. **The Problem:** Runmatic API needs to know where Postgres is and what the secret key is. This configuration cannot be included in the Dockerfile.

2. **Why Hardcoding Breaks Portability:** For each environment we end up adding DB URL and secret key. Suppose there are 3 environments (dev, uat, prod):

   ```
   Dev database:   postgresql://postgres:devpass@localhost/runmatic
   Staging:        postgresql://postgres:stagpass@staging-db/runmatic  
   Production:     postgresql://postgres:prodpass@prod-db.aws.com/runmatic
   ```

   Then there will be three Dockerfiles, each containing env variables for that environment. This breaks the core concept of Docker: **a single image should run in any environment**.

3. **Security Problem:** The secret key added to the image will be pushed to Docker Hub and will be available publicly (or to anyone with registry access).

4. **The Solution:**
   ```
   IMAGE  → contains the application code. Never changes between environments.
   CONFIG → injected at runtime. Different per environment.
   
   Same image. Different config. Runs correctly everywhere.
   ```

---

### ENV — Environment Variables

1. **What it is:** ENV is the default settings file that ships with the app.

2. **How it works:** Suppose Dockerfile has `ENV PORT=8000`. When the container starts, it uses that environment variable for the port.

3. **Runtime Override:** Whatever environment variable is in the Dockerfile can be overwritten using `-e` option during runtime:
   ```bash
   docker run -e PORT=9000 runmatic-api
   ```

4. **Security Rule:** ENV is not for secrets. It is only for configuration. **Never put real production passwords in ENV.**

---

### ARG — Build-Time Arguments

```
ARG → exists during docker build. Gone after image is built.
ENV → exists when container runs. Persists forever in the image.
```

**Use cases:**
- **ARG** → things that affect HOW you build  
  Python version, build environment, which apt packages to install

- **ENV** → things that affect HOW the app runs  
  Port, log level, database URL (default)

**Conditional Behavior Example:**  
Use ARG variables to do something conditionally during build time. It will not impact runtime.

```dockerfile
ARG BUILD_ENV=production
RUN if [ "$BUILD_ENV" = "development" ]; then \
    pip install pytest debugpy; \
    fi
```

---

### .env Files

All variables cannot be given in `-e` options as it becomes too lengthy. Better option is to use `.env` file with one variable per line:

```bash
docker run --env-file .env runmatic-api
```

**The Pattern:**

```
.env            → real values, NEVER committed to git
                  lives only on your machine and in CI secrets

.env.example    → fake values, committed to git
                  shows teammates what variables are needed
                       
.gitignore      → contains .env
                  ensures the real file never gets committed
```

---

## Phase 3 Challenge — The Three Leak Paths

**Scenario:**  
You have `.env.example` committed to the repo:
```
DATABASE_URL=postgresql+asyncpg://runmatic:runmatic@localhost:5432/runmatic
REDIS_URL=redis://localhost:6379/0
SECRET_KEY=dev-secret-key-not-for-production
ENVIRONMENT=development
LOG_LEVEL=INFO
CORS_ORIGINS=http://localhost:3000
```

A junior engineer copies it to `.env`, replaces the placeholder values with real production credentials, and runs `docker run --env-file .env runmatic-api:v1`.

**Challenge:** Three things are wrong or missing that could lead to those production credentials leaking. Find them. Fix what you can fix. Document what you can't.

---

### My Answer

**Three Leak Paths I Identified:**

1. **ENV variables are not for secrets** — they are only for configuration. SECRET_KEY should not be included in `.env.example`.

2. **docker inspect exposure** — Suppose the junior engineer copies the template and uses it to run the image, `docker inspect` would provide environment details and the secret key will be leaked to anyone who has access to the running container on the host.

3. **Git history is permanent** — If the junior engineer commits the `.env` file accidentally, the secrets will be permanently added to git, even if the file is deleted in a later stage.

**My Proposed Fix:**
1. Remove fields having secrets from `.env.example` file. Production solution is to use secret managers.
2. Ensure the repo has `.gitignore` that includes `.env` file so it is not even accidentally committed to the repo.

---

### Claude's Feedback

**What I Got Wrong:**

> Don't remove secrets fields from `.env.example`. The template should document *every* var the app needs, including the secret ones. The difference is:
> - `.env.example` has **placeholder values** (what I already wrote) — this gets committed
> - `.env` has **real secrets** — this never gets committed
> 
> If you remove SECRET_KEY from the template, the junior engineer doesn't know they need to set it.

**What I Should Have Done:**

The actual fixes:
1. Check if `.gitignore` exists and contains `.env`
2. If missing, add it. If `.gitignore` doesn't exist at all, create it.
3. Test the gitignore — create a fake `.env` file and verify git ignores it

**Verification Commands I Ran:**
```bash
cat .gitignore | grep "^\\.env$"
# Result: .env was already present

echo "SECRET_KEY=real-production-secret" > .env
git status
# Result: .env did NOT appear in untracked files. Gitignore working correctly.

rm .env
```

---

## Bonus Challenge — The Baked Password Problem

**Scenario:**  
A teammate pushed `runmatic-api:prod` to Docker Hub and deployed it to staging. The container starts, stays up, health check returns 200. Everything looks fine.

Three days later, someone rotates the production database password for security compliance.

The API immediately starts returning 500 errors. Logs show:
```
sqlalchemy.exc.OperationalError: password authentication failed
```

The teammate says: "I updated the DATABASE_URL in the `.env` file and rebuilt the image with the new password. The image is updated on Docker Hub. I restarted the container. Why isn't it working?"

**Your task:**
1. Explain what they did wrong
2. Explain why the container kept using the old password
3. Show the correct fix (exact commands)

---

### My Answer

**What they did wrong:**  
`.env` file is included in the Dockerfile. Ideally it should be in `.dockerignore` as it was included in the Docker file and pushed to Docker Hub — it is baked into the image.

**Why container kept using old password:**  
Password is baked into the image. Team member has restarted the container after rebuilding the image. It will not work as it is still the old container and it will use the password it already has.

**Correct fix:**
1. `docker rm` — delete the already running container (team member has stopped and restarted — that will not work)
2. `docker pull` — Pull the latest image
3. `docker run` — run with the new image

**Better way:**  
Remove `.env` from Dockerfile and add it to `.dockerignore`. Keep the `.env` on the server and inject during runtime.

---

### Claude's Feedback

**Diagnosis: 7/10**

You're right that:
- The password is baked into the image (correct)
- They restarted the existing container instead of recreating it (correct)
- Restarting doesn't pick up the new image (correct)

**What I Missed (Precision Issue):**

When you `docker restart`, it restarts the existing container, which is tied to the **old image ID**. Even though they pushed a new image to Docker Hub with tag `prod`, the running container is still referencing the old image by its SHA256 digest. The container doesn't "have" a password stored separately — it's running the old image, which has the old password baked in.

**Fix: 8/10**

My commands were correct:
```bash
docker stop <container>
docker rm <container>
docker pull runmatic-api:prod
docker run --env-file .env runmatic-api:prod
```

**What I Missed:**

If they're injecting with `--env-file .env` at runtime (the better way), they also need to **update the `.env` file on the server** before running. The `.env` on the build machine doesn't matter — only the one on the deployment host where `docker run` executes.

**The Complete Fix:**
```bash
# On the deployment server (not the build machine):

# 1. Update .env with new DATABASE_URL
echo "DATABASE_URL=postgresql+asyncpg://user:NEW_PASSWORD@host:5432/db" > .env

# 2. Stop and remove old container
docker stop <container> && docker rm <container>

# 3. No need to pull if using runtime injection — same image works
docker run -d --env-file .env runmatic-api:prod
```

**Total Bonus Score: 7.5/10**

I got the core concept (baked vs injected, restart vs recreate) but missed the precision on what actually happened and the runtime `.env` update step.
