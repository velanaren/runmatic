# Sprint 19 — Horizontal Pod Autoscaler — Notes

## Phase 1 — The Hook
**Claude's Explanation:** HPA is a 15-second feedback loop. Every 15 seconds the controller asks: "Is current utilization above or below target?" If above → add replicas. If below and stable → remove replicas. It needs two inputs to ask that question: a data source (metrics-server) and a denominator (resource requests). No requests = no denominator = no ratio = HPA stuck at `<unknown>`.

**First Test:** Install metrics-server. Verify `kubectl top nodes` returns actual CPU/memory usage.

**My Result:** metrics-server needed a patch for Docker Desktop — `--kubelet-insecure-tls` flag required because Docker Desktop's kubelet uses a self-signed cert. Without the patch, metrics-server couldn't scrape the kubelet and HPA showed `<unknown>`.

## Phase 2 — The Build
**Done Condition:** `kubectl get hpa` shows a real CPU percentage (not `<unknown>`) and `ScalingActive: True`.

**My Work:**
- `worker-deployment.yaml` — first K8s deployment of the worker service with `resources.requests.cpu: 100m, memory: 128Mi` (required as HPA denominator)
- `hpa.yaml` — HPA targeting `runmatic-worker`, minReplicas 1, maxReplicas 3, CPU averageUtilization 50%

**Key observations:** Without `resources.requests`, HPA showed `<unknown>/50%` and could not act. Adding the requests immediately resolved it to `1%/50%` with `ScalingActive: True`.

## Phase 3 — The Challenge
**The Challenge:** Generate CPU load on the worker pod, watch HPA scale from 1 → 3 replicas, kill the load, watch it scale back.

**My Investigation:** Used two terminals — `kubectl get hpa -w` in one, `kubectl exec` in the other. Generated load with `dd if=/dev/zero of=/dev/null &` (multiple instances). Observed the full scale-up and scale-down cycle.

**Complete observed log:**
```
cpu: 2%/50%   → 1 replica  (baseline)
cpu: 3%/50%   → 1 replica  (load starting)
cpu: 201%/50% → 1 replica  (HPA calculating)
cpu: 67%/50%  → 3 replicas (scaled up — load spread across 3 pods)
cpu: 2%/50%   → 3 replicas (load killed — stabilization window active)
cpu: 1%/50%   → 3 replicas (waiting out 300s window)
cpu: 2%/50%   → 3 replicas (still in window)
cpu: 2%/50%   → 1 replica  (window elapsed — scaled down)
```

**Formula derived from controller logs:**
```
desired = ceil(currentReplicas * (currentMetric / targetMetric))
        = ceil(1 * (201 / 50))
        = ceil(4.02)
        = 4  →  capped at maxReplicas 3
```

Scale down: `ceil(3 * (2/50)) = ceil(0.12) = 1`

**HPA behavior config (unprompted):**
```yaml
spec:
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Pods
        value: 2
        periodSeconds: 60
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Pods
        value: 1
        periodSeconds: 60
```

## Phase 4 — Explanation
**Claude's Question:** Explain HPA in 3 sentences — what it does, why it waits before scaling down, what happens without resource requests.

**My Answer:** HPA is a feedback loop that reconciles current vs target resource utilization and scales replicas without human intervention. It waits 5 minutes (stabilization window) before scaling down to avoid thrashing on temporary load spikes. Without resource requests, the denominator for current utilization is missing and HPA cannot calculate a ratio — it shows `<unknown>` and cannot act.

**Claude's Feedback:** 9/10 concept. Gap: didn't name metrics-server as the named data source in the pipeline. Full chain: kubelet → metrics-server → HPA controller → scale decision.

## Key Takeaways
1. HPA is a 15-second feedback loop. Not instant — there's inherent latency.
2. Three requirements: metrics-server (data source) + resource requests (denominator) + target (numerator). Missing any one breaks it at a different point.
3. The replica formula: `ceil(currentReplicas * (currentMetric / targetMetric))`, capped at maxReplicas.
4. Scale-up: immediate (stabilizationWindowSeconds: 0). Scale-down: 5-minute window by default.
5. 201% CPU on 1 pod → 67% across 3 pods. The load doesn't disappear — it spreads.
6. Docker Desktop requires `--kubelet-insecure-tls` on metrics-server. Self-signed cert.
