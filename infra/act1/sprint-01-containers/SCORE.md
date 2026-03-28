# Sprint 01 — Containers & the Docker Mental Model
**Score:** 17/20  (Concept: 7/10 | Execution: 9/10 | Speed: +1)
**Date:** 2026-03-26
**Duration:** Approx 30 min

---

## What You Got Right

1. **The isolation mental model.** Apartment building analogy was your own construction, not the one I gave you — and it worked. Isolated filesystem, network, process tree. That's the core of it.

2. **VM vs container distinction.** You knew VMs virtualize hardware and containers are lighter. You also knew containers boot faster — and you understood *why*, not just *that*.

3. **Break-fix diagnosis.** You found the missing port mapping using three independent tools (logs, ps, inspect) before attempting a fix. That's the right order. In production you confirm the diagnosis before touching anything.

## What You Missed

1. **"Virtualizes the OS" is imprecise.** Containers don't virtualize the OS — they *share* the host OS kernel. The isolation comes from Linux kernel features called **namespaces** (each container has its own view of processes, network, filesystem) and **cgroups** (limits how much CPU and memory a container can use). This distinction matters: you cannot run a Windows container on a Linux host without special tooling, because there's no Windows kernel to share.

2. **Image vs container.** You ran containers but didn't articulate the distinction. An image is a static, read-only snapshot — a recipe. A container is a running (or stopped) instance created from that image. You can create 10 containers from the same image. When you `docker rm`, you delete the container. The image stays. This becomes critical in Sprint 02 and Sprint 03.

## Carry Forward

When writing your first Dockerfile in Sprint 03, remember: the Dockerfile **builds an image**. `docker run` **creates a container** from that image. These are two separate steps. Confusing them is the most common Sprint 03 mistake.

## What This Teaches About Production Systems

Port mapping isn't just a developer convenience — it's a security boundary. In production, you never publish database ports (5432, 6379) to the host. Runmatic's postgres and redis containers will have no `-p` flag at all. They're reachable only by other containers on the same Docker network, not from the internet. Sprint 06 (networking) is where this becomes explicit, but the reason is already in front of you: no `-p` means no external access, full stop.

## Bonus Challenge
Unlocked: Yes (17/20)
Attempted: Yes
Result:    9/10

**Scenario:** `docker run` with an existing stopped container name fails.
**Diagnosis (5/5):** Found stopped container via `ps -a`, confirmed existence via `inspect`, correctly identified that `docker run` creates new containers and requires unique names — distinguished from `docker start`.
**Fix (4/5):** Correct logic (rm then run), but fix commands not executed to confirm. Always verify.
**Bonus insight:** "Docker checks its ledger" — accurate. Container names are unique keys in Docker's internal registry, rejected before create even starts.
**Gap to close:** Two fix options exist: `docker rm` + `docker run` (new container) vs `docker start` (resume existing). Not the same — matters in Sprint 05 when container filesystem state becomes significant.
