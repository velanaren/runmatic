#!/bin/bash
# Sprint 14 — Pods & Deployments
# Goal: deploy Runmatic API as a K8s Deployment with 2 replicas, prove self-healing
# Key question: what's the difference between a bare Pod and a Deployment?

# === Phase 1 — bare pod has no recovery ===

# why: prove that a pod with no owner is gone when it dies
kubectl run orphan --image=nginx --restart=Never

# why: confirm pod is running
kubectl get pods

# why: delete it and observe — no replacement, no owner watching it
kubectl delete pod orphan
kubectl get pods
# result: No resources found in default namespace

# === Phase 2 — deploy Runmatic API as a Deployment ===

# why: apply the declarative manifest — Deployment creates ReplicaSet creates Pods
kubectl apply -f infra/k8s/sprint-14-deployments/api-deployment.yaml

# why: watch pod startup in real time (-w = watch mode)
kubectl get pods -w

# why: see the ReplicaSet the Deployment created underneath
kubectl get rs

# why: inspect the ReplicaSet — selector, desired/current/ready counts, Events
kubectl describe rs runmatic-api-5ffc7d7657

# why: delete one pod to trigger the reconciliation loop
kubectl delete pod runmatic-api-5ffc7d7657-28jnl

# why: watch replacement pod appear (within ~7s)
kubectl get pods -w -l app=runmatic-api

# === Phase 3 — rolling update + rollback ===

# why: check rolling update strategy before triggering (know the constraints first)
kubectl get deployment runmatic-api -o yaml | grep -A5 strategy

# why: trigger a rolling update to a broken image tag
kubectl set image deployment/runmatic-api api=runmatic-api:does-not-exist

# why: watch the rolling update — observe old pods stay Running, new pod fails
kubectl get pods -w -l app=runmatic-api

# why: describe the failing pod — see ErrImageNeverPull and the Events
kubectl describe pod runmatic-api-668f75fb48-d2cq8

# why: describe an old pod — confirm it's still using the working image
kubectl describe pod runmatic-api-5ffc7d7657-74jvn

# why: watch rollout status — see it wait, then surface progressDeadlineExceeded after 600s
kubectl rollout status deployment/runmatic-api

# why: roll back to the previous working ReplicaSet without editing any YAML
kubectl rollout undo deployment/runmatic-api

# why: confirm rollback succeeded
kubectl rollout status deployment/runmatic-api

# why: see revision history — shows all ReplicaSet revisions for this Deployment
kubectl rollout history deployment/runmatic-api

# why: confirm same original pods are still running (rollback = scale old RS up, not new pods)
kubectl get pods
