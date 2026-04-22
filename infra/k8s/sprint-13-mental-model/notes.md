# Sprint 13 — Kubernetes Mental Model — Notes

## Phase 1 — The Hook
**Claude's Explanation:** Kubernetes is like Autosys's master daemon for containers across a fleet of machines. Docker Compose = you manage everything manually on one machine. K8s = you write a declaration ("I want 3 replicas") and the system makes it real and keeps it real, automatically, across however many machines you have.

Control plane = the manager's brain. You write the note, the brain handles the rest.

**First Test:** `kubectl get pods -n kube-system`
**My Result:** Saw all control plane component pods: kube-apiserver, etcd, kube-controller-manager, kube-scheduler, coredns, kube-proxy. Identified each component and its role.

## Phase 2 — The Build
**Done Condition:** `kubectl get nodes` shows Ready node. Can label all control plane components from memory and explain what each does.

**Investigation:**
- `kubectl describe node docker-desktop` — observed Conditions (kubelet health: memory OK, no disk pressure, sufficient PIDs, kubelet ready) and Allocatable (~100MB reserved for OS/kubelet overhead, pods: 110 max)
- `kubectl get namespaces` — cluster organized as virtual partitions
- `kubectl get pods -A` — all pods across all namespaces; pod is the lowest schedulable unit
- `kubectl cluster-info` — control plane address and DNS service endpoint

**Mental model established:**
```
Cluster
  └── Namespaces (virtual isolation boundaries)
        └── Pods (atomic scheduled unit)
              └── Containers (what actually runs)
```

**Control plane components mapped:**
- `kube-apiserver` — single entry point for all operations; every kubectl command hits this
- `etcd` — the notebook; all cluster state stored here as key-value pairs; this IS the cluster
- `kube-scheduler` — placement engine; decides which node gets which pod based on available resources
- `kube-controller-manager` — reconciliation engine; runs continuous loops comparing desired vs actual state
- `coredns` — cluster DNS; service names resolve to pod IPs
- `kube-proxy` — network rules on each node; makes Service routing work

## Phase 3 — The Challenge
**Claude's Challenge:** Run `kubectl run nginx-test --image=nginx` (standalone pod) vs `kubectl create deployment nginx-deploy --image=nginx` (deployment). Delete the pod both times. Explain why one stays dead and the other comes back.

**My Investigation:**
- Standalone pod: independent object, no controller watching it, no desired state — deleted = gone
- Deployment: found `ownerReferences` in pod YAML unprompted — kind: ReplicaSet, meaning the pod is owned by a controller
- Traced full chain: Deployment (desired state: spec.replicas) → ReplicaSet (enforces replica count) → Pod (actual running unit)
- Observed Events in `kubectl describe rs`: first pod ran 18 min, deleted, second pod created within seconds by `replicaset-controller`
- Understanding: Deployment creates a ReplicaSet (not pods directly) because rolling updates work by creating a new ReplicaSet and scaling it up while scaling the old one down

## Phase 4 — Explanation
**Claude's Question:** Explain Kubernetes in 3 sentences. Pretend you're explaining to a support engineer who's never heard of it.

**My Answer:** Just running a container manually is like hiring individual workers and telling each one exactly what to do. Kubernetes is like hiring a facility manager. You write a note: "I need 3 boxes stacked in the warehouse at all times." The manager reads the note, assigns workers, replaces them if they quit, and keeps the boxes stacked forever, without you watching.

Also explained why pods exist: two containers needing shared network/storage must run on the same node. Scheduling containers individually risks them landing on different nodes. Pods guarantee co-location.

**Claude's Feedback:** Analogy precise and complete. Pod co-location reasoning sophisticated — named the actual problem pods solve. Gap: control plane component names didn't appear in explanation; named components strengthen interview answers.

## Bonus Challenge
**Challenge:** One pod survives `kubectl delete deployment ghost-app`. Deployment is gone. Pod won't die. What's keeping it alive?

**My Investigation and Fix:**
1. Identified mechanism: finalizers — a pre-deletion checklist; K8s marks the object with deletionTimestamp but won't remove it until all finalizers are cleared
2. Simulated entire scenario from scratch:
   - Created deployment with 3 replicas
   - Applied a custom finalizer to one pod: `kubectl patch pod ghost-app-... -p '{"metadata":{"finalizers":["kubernetes.io/ghost-lock"]}}'`
   - Deleted the deployment — other 2 pods gone, finalizer pod stuck
   - Fixed by nullifying: `kubectl patch pod ghost-app-... -p '{"metadata":{"finalizers":null}}' --type=merge`
   - Pod deleted immediately after finalizer cleared

**Score:** 10/10

## Key Takeaways
1. Kubernetes manages desired state, not individual containers — you declare intent, the control plane reconciles reality
2. The reconciliation loop is the core pattern: observe → compare → act on the diff, continuously, forever
3. Object ownership chain: Deployment → ReplicaSet → Pod; labels and selectors are the connective tissue
4. Deployments create ReplicaSets (not pods directly) to enable zero-downtime rolling updates
5. Finalizers are pre-deletion checklists — an object with a finalizer will not be deleted until the finalizer is removed
6. Control plane lives in kube-system namespace as regular pods — you can inspect them like any other pod
