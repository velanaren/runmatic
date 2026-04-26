# Sprint 15 — Services & DNS
**Score:** 19/20  (Concept: 9/10 | Execution: 9/10 | Speed: +1)
**Date:** 2026-04-26
**Duration:** Approx 35 min

---

## What You Got Right

1. **DNS resolution flow from first principles.** You explained `/etc/resolv.conf` → nameserver → service-name → ClusterIP without prompting. That's the actual mechanism, not a hand-wavy "K8s handles it."

2. **Selector/label mismatch diagnosis with jsonpath.** When endpoints showed `<none>`, you ran `kubectl get pod -o jsonpath='{.metadata.labels}'` and `kubectl get svc -o jsonpath='{.spec.selector}'` side by side. That's the exact two-command production diagnostic — no guessing, no grepping through YAML.

3. **Busybox workaround without being told.** The API image didn't have nslookup. You spun up a dns-debug busybox pod and ran the test there. That's real cluster debugging instinct — production images are slim, debug tools live separately.

## What You Missed

1. **DNS resolves to ClusterIP, not directly to pod IPs.** You described the flow as nameserver → pod IP. The actual path is nameserver → ClusterIP (virtual IP managed by kube-proxy), and kube-proxy then forwards to a pod IP. The distinction matters: ClusterIP is stable even when all pods are replaced; pod IPs are what actually receive traffic.

2. **No readiness probe on the postgres Deployment.** K8s marked the postgres pod Ready as soon as the process started — not when postgres was actually accepting connections. Sprint 15's bonus exposed exactly why this matters: a pod with a matching label but no readiness probe gets added to endpoints immediately, regardless of whether it can serve real traffic.

## Carry Forward

In Sprint 16, your DATABASE_URL is still hardcoded as an env var in the Deployment YAML — visible to anyone with `kubectl` access. The service names you defined (`postgres-service`, `api-service`) are now the canonical hostnames that go into ConfigMaps. Passwords go into Secrets. The Deployment YAML itself will contain no sensitive values.

## What This Teaches About Production Systems

Services are not a convenience — they are the load balancing and service discovery layer that makes K8s workloads resilient. Without Services, every pod-to-pod connection requires a hardcoded IP that changes on every restart. With Services, you deploy a new postgres pod to a different node with a different IP, and the API never notices — the DNS name resolves the same way. The bonus challenge exposed the other side: a Service with no readiness probes is a load balancer that routes traffic to broken backends silently. In production, a pod that passes the label selector but fails to authenticate to a database will receive real user traffic until someone notices elevated error rates. Readiness probes are what connect the Service's endpoint list to actual health — without them, the Service is making promises the cluster cannot keep.

## Bonus Challenge
Unlocked: Yes
Attempted: Yes
Result: 10/10 — Simulated intermittent failures by injecting a fake-postgres pod with matching labels but wrong credentials. Proved the load-balancing failure empirically by deleting the real postgres pod and forcing all traffic to the fake one. Correctly identified readiness probes as the fix: a failing probe removes the pod IP from the Service endpoints entirely.
