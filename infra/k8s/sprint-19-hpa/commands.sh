#!/bin/bash
# Sprint 19 — Horizontal Pod Autoscaler
# Goal: wire up HPA for the runmatic-worker deployment and observe live autoscaling
# Key question: what does HPA actually need to calculate a replica count?

# === Phase 1 — Install metrics-server ===

# why: HPA queries metrics-server for current CPU — without it, HPA shows <unknown> and can't act
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# why: Docker Desktop kubelet uses a self-signed cert — metrics-server rejects it by default
kubectl patch deployment metrics-server -n kube-system \
  --type='json' \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/args/-","value":"--kubelet-insecure-tls"}]'

# why: verify metrics-server is actually scraping — if this shows <unknown>, HPA won't work
kubectl top nodes
kubectl top pods

# === Phase 2 — Deploy worker with resource requests ===

# why: resource requests are the denominator in HPA's formula — omit them and HPA shows <unknown>
kubectl apply -f infra/k8s/sprint-19-hpa/worker-deployment.yaml

# why: apply the HPA manifest that targets runmatic-worker at 50% CPU
kubectl apply -f infra/k8s/sprint-19-hpa/hpa.yaml

# why: confirm HPA is active and showing a real percentage (not <unknown>)
kubectl get hpa
kubectl describe hpa runmatic-worker-hpa

# === Phase 3 — Generate CPU load and watch autoscaling ===

# why: watch HPA in real time — REPLICAS column is what we're waiting to change
kubectl get hpa runmatic-worker-hpa -w

# why: get the pod name to exec into it
kubectl get pods -l app=runmatic-worker

# why: exec into the pod to generate CPU load from inside the container
# replace pod name with actual pod name from above
kubectl exec -it <worker-pod-name> -- /bin/sh

# inside the container — why: dd hammers CPU by copying /dev/zero to /dev/null in a tight loop
dd if=/dev/zero of=/dev/null &
dd if=/dev/zero of=/dev/null &
dd if=/dev/zero of=/dev/null &

# kill the load processes inside the container
kill %1 %2 %3
exit

# === Phase 3 — Inspect HPA decisions ===

# why: see the full HPA status including last scale time and condition messages
kubectl describe hpa runmatic-worker-hpa

# why: read the HPA controller logs to see the formula output directly
kubectl logs -n kube-system -l app=kube-controller-manager --tail=50 | grep horizontal

# === Verify scale-up ===
# Expected: cpu jumps to ~200%/50% → REPLICAS changes 1 → 3
# Formula: ceil(1 * (201/50)) = ceil(4.02) = 4, capped at maxReplicas 3

# === Verify scale-down ===
# Expected: cpu drops to ~2%/50% → replicas stay at 3 for 300s (stabilization window)
# Formula: ceil(3 * (2/50)) = ceil(0.12) = 1 → scales down after window
