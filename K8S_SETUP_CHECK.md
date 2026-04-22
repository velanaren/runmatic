# Kubernetes Pre-Flight Check
**Before starting Sprint 13**

---

## What You Need

For Act 2, you need a **local Kubernetes cluster** and **kubectl** (the Kubernetes CLI).

**Best option for macOS + Docker Desktop:** Enable Kubernetes in Docker Desktop.  
This gives you a single-node cluster running locally — perfect for learning.

---

## Step 1 — Check if kubectl is installed

```bash
kubectl version --client
```

**Expected output:** Version info (v1.28+ is fine).  
**If command not found:** Install kubectl (see Step 3).

---

## Step 2 — Check if Kubernetes cluster is running

```bash
kubectl cluster-info
```

**Expected output:**
```
Kubernetes control plane is running at https://kubernetes.docker.internal:6443
CoreDNS is running at https://...
```

**If connection refused or not found:** Enable Kubernetes in Docker Desktop (see Step 3).

---

## Step 3 — Enable Kubernetes in Docker Desktop

1. Open **Docker Desktop**
2. Click the **gear icon** (Settings)
3. Go to **Kubernetes** tab
4. Check **"Enable Kubernetes"**
5. Click **"Apply & Restart"**
6. Wait 2-3 minutes for the cluster to start (watch the Docker Desktop status)

After restart, run:
```bash
kubectl cluster-info
kubectl get nodes
```

You should see:
```
NAME             STATUS   ROLES           AGE   VERSION
docker-desktop   Ready    control-plane   ...   v1.28.x
```

---

## Step 4 — Validation Test

Run this to confirm kubectl can talk to the cluster:

```bash
# Create a test pod
kubectl run test-nginx --image=nginx --restart=Never

# Check if it's running
kubectl get pods

# Clean up
kubectl delete pod test-nginx
```

**Expected:** Pod starts, shows "Running" status, deletes cleanly.

---

## If Docker Desktop Kubernetes doesn't work

**Alternative: Minikube**

```bash
# Install minikube
brew install minikube

# Start cluster
minikube start

# Verify
kubectl get nodes
```

**Alternative: kind (Kubernetes in Docker)**

```bash
# Install kind
brew install kind

# Create cluster
kind create cluster --name runmatic

# Verify
kubectl cluster-info --context kind-runmatic
```

---

## What Sprint 13 Will Use

- `kubectl` commands to inspect the cluster
- Understanding control plane components (API server, scheduler, etcd)
- Creating your first pod (manually, no YAML yet)
- Observing how Kubernetes reconciles desired state

No manifests yet. Sprint 13 is pure mental model — what Kubernetes IS before what Kubernetes DOES.

---

## Ready?

Once `kubectl cluster-info` works, you're ready for Sprint 13.
