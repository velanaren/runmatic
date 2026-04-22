#!/bin/bash
# Sprint 13 — Kubernetes Mental Model
# Goal: understand what Kubernetes IS before writing a single YAML file
# Key question: what is the reconciliation loop and why does it matter?

# === CONTEXT SETUP ===

# why: Runmatic uses docker-desktop context; kind-cka is kept separate for CKA study
kubectl config use-context docker-desktop

# why: confirm the correct cluster is active before doing anything
kubectl config get-contexts

# === CONTROL PLANE INSPECTION ===

# why: the control plane lives in kube-system as regular pods — inspecting it demystifies K8s
# what I saw: kube-apiserver, etcd, kube-controller-manager, kube-scheduler, coredns, kube-proxy all Running
kubectl get pods -n kube-system

# why: understand the node's resource capacity and what K8s reserves for itself
# what I saw: ~100MB reserved for OS/kubelet; pods: 110 max; allocatable < capacity
kubectl describe node docker-desktop

# === CLUSTER STRUCTURE ===

# why: understand the isolation boundary above pods
kubectl get namespaces

# why: see all running pods across every namespace at once
kubectl get pods -A

# why: confirm control plane endpoint and DNS service
kubectl cluster-info

# === RECONCILIATION LOOP DEMONSTRATION ===

# why: standalone pod has no controller watching it — deleting it means it's gone
kubectl run nginx-test --image=nginx

# why: watch the pod reach Running state before deleting
kubectl get pods -w

# why: delete the standalone pod — it will not come back
kubectl delete pod nginx-test

# why: deployment creates desired state + a controller hierarchy (Deployment → ReplicaSet → Pod)
kubectl create deployment nginx-deploy --image=nginx

# why: find the pod name to inspect its ownership chain
kubectl get pods

# why: find ownerReferences to see which controller owns this pod
# what I saw: kind: ReplicaSet — this pod is not standalone, it's owned by a controller
kubectl get pod nginx-deploy-<pod-id> -o yaml | grep -A 5 ownerReferences

# why: see the ReplicaSet directly — this is where replica count is enforced
# what I saw: DESIRED: 1, CURRENT: 1, Events showing pod creation
kubectl get rs
kubectl describe rs nginx-deploy-<rs-id>

# why: see where the desired state (spec.replicas) actually lives
kubectl get deployment nginx-deploy -o yaml

# why: delete the pod and observe immediate replacement — the reconciliation loop in action
kubectl delete pod nginx-deploy-<pod-id>

# why: watch the new pod appear — old pod Terminating, new pod ContainerCreating simultaneously
kubectl get pods -w

# === CLEANUP ===
kubectl delete deployment nginx-deploy

# === BONUS CHALLENGE — FINALIZERS ===

# why: simulate a pod that survives deployment deletion due to a finalizer
kubectl create deployment ghost-app --image=nginx --replicas=3

# why: apply a custom finalizer to one pod — K8s won't delete it until this is cleared
kubectl patch pod ghost-app-<pod-id> -p '{"metadata":{"finalizers":["kubernetes.io/ghost-lock"]}}'

# why: confirm the finalizer is set
kubectl get pod ghost-app-<pod-id> -o yaml | grep -A 5 "finalizers"

# why: delete the deployment — 2 pods die, 1 stays stuck due to finalizer
kubectl delete deployment ghost-app

# why: stuck pod has deletionTimestamp set but finalizer blocks actual deletion
kubectl get pods
kubectl get pod ghost-app-<pod-id> -o yaml | grep deletionTimestamp

# why: nullifying the finalizer removes the pre-deletion block — pod is deleted immediately
kubectl patch pod ghost-app-<pod-id> -p '{"metadata":{"finalizers":null}}' --type=merge

# why: confirm pod is gone
kubectl get pods
