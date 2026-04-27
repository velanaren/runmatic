# Sprint 16 — ConfigMaps & Secrets
**Score:** 18/20  (Concept: 8/10 | Execution: 9/10 | Speed: +1)
**Date:** 2026-04-27
**Duration:** Approx 35 min

---

## What You Got Right

1. **The three reasons hardcoded env vars fail** — git history is permanent (removing a secret from a future commit doesn't erase it from history), environment portability requires separate files per env, and coupling config to the Deployment spec means every config change triggers a deploy. These are the real production arguments, not textbook ones.

2. **valueFrom syntax on first try** — `secretKeyRef` and `configMapKeyRef` wired correctly across all four files. Pods came up Running with db connected. Phase 3 cracked in under a minute with no hints: `kubectl get secret -o jsonpath | base64 --decode`.

3. **Bonus: three-tier fix** — `kubectl rollout restart` as the immediate fix, immutable versioned ConfigMaps as the GitOps pattern (changing the reference forces an automatic rollout), volume-mounted ConfigMaps as the hot-reload alternative (kubelet syncs every 60s, no rollout needed when the app reads the file at runtime). All three correct.

## What You Missed

1. **Secrets are base64, not encrypted — missing from the verbal explanation.** You proved it hands-on in Phase 3, but the explanation didn't include it. In an interview: "K8s Secrets are base64-encoded, not encrypted — anyone with `kubectl get secret` access can decode them in one command. Production requires external secrets management: AWS Secrets Manager, Vault, or Sealed Secrets." That sentence is the one that signals seniority.

2. **LOG_LEVEL in ConfigMap but never wired to any pod.** The key exists in `runmatic-config` but no Deployment references it. A ConfigMap key that nothing reads is dead config — it creates confusion about what's actually in use.

## Carry Forward

Secrets are base64, not encrypted. In Sprint 17 (Persistent Volumes), postgres gets a PVC — the password to connect to it still comes from `runmatic-secrets`. In Sprint 20 (Capstone), you'll be asked to explain the full security posture of the cluster. The answer includes: "Secrets are base64 only — production would use AWS Secrets Manager via IRSA."

## What This Teaches About Production Systems

Config management is where teams accumulate the most invisible debt. A hardcoded password in a Deployment YAML gets committed, gets copied into staging, gets pasted into a Slack thread during an incident, lives in git history forever. ConfigMaps and Secrets are K8s's answer — but they're only the first layer. The immutable ConfigMap pattern (versioned names, reference changes trigger rollouts) is how GitOps shops enforce that no config change is invisible. Every change is a git commit. Every git commit is a deployment event. The cluster's state is always derivable from the repo. That's the invariant production teams protect.

## Bonus Challenge
Unlocked: Yes (18/20)
Attempted: Yes
Result: 10/10 — Diagnosed env var freeze hands-on, fixed with rollout restart, described immutable ConfigMap and volume-mount patterns unprompted.
