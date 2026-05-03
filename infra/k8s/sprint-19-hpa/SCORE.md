# Sprint 19 — Horizontal Pod Autoscaler
**Score:** 19/20  (Concept: 9/10 | Execution: 10/10 | Speed: +0)
**Date:** 2026-05-03
**Duration:** Approx 40 min across two sessions (Phase 1+2 on 2026-05-02, Phase 3 on 2026-05-03)

---

## What You Got Right

- **The formula from first principles.** You derived `ceil(currentReplicas * (currentMetric / targetMetric))` from the actual HPA controller log, not from documentation. You correctly identified that 201%/50% → ceil(4.02) = 4, capped at maxReplicas 3.

- **Resource requests as denominator.** You explained precisely why omitting `requests.cpu` breaks HPA: the denominator for current utilization doesn't exist, so the controller can't produce a ratio, and the target shows `<unknown>`.

- **Stabilization window mechanics.** You correctly identified the asymmetry: scaleUp stabilizationWindowSeconds=0 (immediate), scaleDown stabilizationWindowSeconds=300 (5 min). You named the reason — avoiding thrash on temporary load spikes — and showed the behavior YAML config unprompted.

## What You Missed

- **metrics-server as the named data source.** The HPA controller doesn't read pod CPU directly from the kubelet. It queries the metrics-server, which aggregates resource metrics from all nodes. You saw this in Phase 1 (you installed and patched it with `--kubelet-insecure-tls` for Docker Desktop), but didn't name it in your Phase 4 explanation. The full chain is: kubelet → metrics-server → HPA controller → scale decision. Remove metrics-server and HPA shows `<unknown>` — the controller has no signal at all.

## Carry Forward

HPA needs exactly three things to function: **metrics-server** (data source), **resource requests** (denominator), **target utilization** (numerator). Remove any one and the feedback loop breaks at a different point. In the Act 2 Capstone, when something isn't scaling, your first diagnostic question is: which of these three is missing?

## What This Teaches About Production Systems

HPA is not a performance feature — it's a cost control mechanism with a safety floor. In production, you tune `minReplicas` to absorb baseline load without cold-start latency, `maxReplicas` to cap your cloud bill, and the stabilization window to match your traffic pattern's volatility. A service that spikes for 90 seconds and recovers needs a different window than one that sustains elevated load for 20 minutes. Getting this wrong in either direction is expensive: too aggressive scale-down causes latency spikes when load returns; too conservative leaves idle pods running at full cost. The formula you derived today is the same formula the production Kubernetes controller runs every 15 seconds — you now understand exactly what it's doing.

## Bonus Challenge
Unlocked: Yes (19/20 ≥ 16)
Attempted: Yes
Result:    9/10

**Challenge:** Apply 1000m CPU request to worker — HPA shows `<unknown>/50%`, ScalingActive: False. Diagnose and fix.

**What happened:** Scenario didn't reproduce as written — node had 8 CPUs, 1000m left plenty of headroom, one running pod still fed metrics to HPA. Rather than stopping, Vela investigated why (checked allocatable + allocated resources), then deliberately set requests to 6000m to engineer a real resource exhaustion condition.

**What she found instead — and correctly diagnosed:**
- HPA scaled to 2 replicas (ScalingActive: True throughout)
- Second pod stuck `Pending` with `FailedScheduling: Insufficient cpu`
- Node had ~600m remaining, pod needed 6000m
- HPA thought it was working; actual capacity unchanged

**Key insight from this:** `<unknown>` requires the *running* pod to be unschedulable (no metrics at all). A running pod + pending pod = HPA still has metrics, still acts, but capacity is silently capped. More dangerous than `<unknown>` because no obvious signal.

**Fix:** Restored 100m/200m requests. All pods Running. Allocated resources back to 18%.
