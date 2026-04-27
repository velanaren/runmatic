# Sprint 16 — ConfigMaps & Secrets — Notes

## Phase 1 — The Hook
**Claude's Explanation:** env vars hardcoded in Deployment YAML are visible to anyone with kubectl access — in terminal history, Slack screenshots, Jira tickets. K8s has two purpose-built objects: ConfigMap (non-sensitive config) and Secret (passwords, keys, certificates). Both live outside the Pod spec.

**First Test:** `kubectl describe deployment runmatic-api` — Environment section showed DATABASE_URL with plaintext password, SECRET_KEY in plaintext.

**My Result:** Immediately saw the problem. All three values exposed: DATABASE_URL with devpassword, REDIS_URL, SECRET_KEY.

## Phase 2 — The Build
**Done Condition:** kubectl describe deployment runmatic-api shows no hardcoded values — only references to ConfigMap and Secret keys.

**My Work:**
- `configmap.yaml` — REDIS_URL, LOG_LEVEL, POSTGRES_DB, POSTGRES_USER
- `secret.yaml` — DATABASE_URL, POSTGRES_PASSWORD, SECRET_KEY (base64 encoded with `echo -n "value" | base64`)
- `api-deployment.yaml` — replaced all `value:` with `valueFrom: secretKeyRef` and `configMapKeyRef`
- `postgres-deployment.yaml` — POSTGRES_DB and POSTGRES_USER from ConfigMap, POSTGRES_PASSWORD from Secret

**Key observations:** Apply order matters — ConfigMap and Secret must exist before the Deployments that reference them. After apply, `kubectl describe` shows `<set to the key 'DATABASE_URL' in secret 'runmatic-secrets'>` — no plaintext visible. Pods Running, db connected.

## Phase 3 — The Challenge
**Claude's Challenge:** Recover plaintext value of SECRET_KEY from the live cluster. No `kubectl describe`, no opening secret.yaml.

**My Investigation:**
```bash
kubectl get secret runmatic-secrets -o jsonpath='{.data.SECRET_KEY}' | base64 --decode
# dev-secret-key
```
Under one minute, no hints. Proves Secrets are base64 encoding, not encryption.

## Phase 4 — Explanation
**Claude's Question:** Explain ConfigMaps and Secrets in 3 sentences for a support engineer who knows env vars but not K8s.

**My Answer:** Hardcoded env vars in Deployment YAML fail three ways: git history is permanent, portability requires multiple files per environment, and coupling config to the Deployment spec means every config change triggers a redeploy. ConfigMaps hold non-sensitive config (hostnames, log levels). Secrets hold sensitive data (passwords, API keys).

**Claude's Feedback:** Strong WHY (three real production arguments). Missing: Secrets are base64 not encrypted — the nuance proved in Phase 3 should be in the explanation.

## Bonus Challenge
**Challenge:** Update REDIS_URL in ConfigMap. Why don't running pods see the change?

**My Investigation:**
- Exec'd into pod before change: `echo $REDIS_URL` → `redis://redis:6379/0`
- Applied ConfigMap update
- Exec'd into same pod: still `redis://redis:6379/0`
- Root cause: env vars are injected at pod start and frozen for the pod's lifetime

**Fix:** `kubectl rollout restart deployment/runmatic-api` — rolling update, no downtime, new pods pick up new values.

**Two deeper alternatives identified:**
1. Immutable versioned ConfigMaps (`runmatic-config-v2`) — changing the reference in the Deployment spec forces an automatic rollout. GitOps pattern: every config change is a git commit, every git commit is a deployment event.
2. Volume-mounted ConfigMaps — kubelet syncs every 60 seconds. Change is visible in the file without any rollout, as long as the app reads the file at runtime rather than caching it at startup.

**Bonus Score:** 10/10

## Key Takeaways
1. ConfigMap = non-sensitive config. Secret = sensitive data. Both decouple config from the Deployment spec.
2. `valueFrom: secretKeyRef` and `configMapKeyRef` — the syntax for referencing these objects in a pod.
3. Apply order: ConfigMap and Secret before Deployments that reference them.
4. K8s Secrets are base64, not encrypted. `kubectl get secret -o jsonpath | base64 --decode` recovers plaintext instantly. Production requires AWS Secrets Manager, Vault, or Sealed Secrets.
5. Env vars are frozen at pod start. ConfigMap changes require a pod restart (`kubectl rollout restart`) to take effect — unless the ConfigMap is mounted as a volume file, in which case kubelet syncs every 60s.
6. Immutable versioned ConfigMaps are the GitOps pattern for enforcing that every config change is a visible, auditable deployment event.
