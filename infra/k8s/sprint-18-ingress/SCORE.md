# Sprint 18 — Ingress
**Score:** 17/20  (Concept: 9/10 | Execution: 8/10 | Speed: +0)
**Date:** 2026-05-01
**Duration:** Approx 50 min (extended due to image and Redis debugging)

---

## What You Got Right

**NodePort gap analysis was thorough and precise.**
You identified all four NodePort problems unprompted: port proliferation, no hostname
routing, no TLS, no smart routing. Most engineers stop at "too many ports." You went
further into the structural limitations — that's the senior SRE mindset.

**The two-component analogy was exactly right.**
Law (resource) vs enforcement (controller). Written rules vs the people who execute them.
This is the mental model — Ingress resource is a YAML routing table, the controller is
the process that reads it and implements it as actual Nginx config. Separate concerns,
one outcome.

**Phase 3: Full path-rewrite solution, independently solved.**
Diagnosed that the 404 came from the API (not the Ingress), understood why (path passed
through unchanged), and correctly implemented `rewrite-target: /api/$2` with a regex
capture group `(/|$)(.*)`, `ImplementationSpecific` pathType, and `use-regex: "true"`.
Verified with real runbook data from the API.

---

## What You Missed

**The reconciliation loop — controllers are dynamic, not static.**
You correctly said the controller reads the Ingress resource. The missing piece: it
doesn't read it once. The controller watches the K8s API server continuously. The moment
you `kubectl apply` a change to ingress.yaml, the controller detects it, regenerates its
internal nginx.conf, and reloads — within seconds, with no manual restart. That's the
same reconciliation loop from Sprint 13 (desired state vs actual state), applied inside
the controller itself.

**Annotation scope — rewrite-target applies to all paths in the Ingress.**
The `rewrite-target` annotation affects every path rule in the Ingress object. When you
added it for `/v2/api`, it would also rewrite the `/` path to `/api/` — breaking the
frontend. In practice you'd split these into two separate Ingress objects: one for API
(with rewrite), one for frontend (without). Worth knowing before Sprint 20.

---

## Carry Forward

Ingress passes paths through UNCHANGED by default. `rewrite-target` is the tool when
the path in Ingress doesn't match what the backend expects. In Sprint 20 Capstone, you'll
wire the full stack — decide explicitly: does this path need a rewrite, or does the
backend already handle the prefix correctly?

---

## What This Teaches About Production Systems

Ingress is where application routing meets cluster operations. In a team running 10+
microservices, the alternative — NodePort per service — becomes unmanageable within
weeks. Security teams can't firewall 30 random high ports. DNS teams can't route
30 separate addresses. Ingress collapses all of that to a single entry point with a
routing table that lives in version control, is reviewed in PRs, and is applied
automatically. The path-rewrite capability is what enables API versioning (`/v2/`) and
blue-green routing without touching the backend code at all — the Ingress layer handles
the translation. That's a real architectural lever, not just a config detail.

---

## Bonus Challenge
Unlocked: Yes (17/20)
Attempted: Yes
Result:    8/10

### Diagnosis (4/5)
Correctly identified: no host = wildcard (matches all hostnames), rewrite-target: /
strips paths causing 404, missing monitoring-service causing 502. Missed the mechanism:
nginx ingress controller merges ALL Ingress objects with the same ingressClassName into
one nginx.conf. The monitoring-ingress annotation bleeds into the merged config and
corrupts runmatic.local routing even though runmatic-ingress itself is unchanged.

### Fix (4/5)
Host-based routing in a single Ingress file — correct pattern. Two gaps: port 80 used
for frontend-service (should be 3000), and immediate fix not mentioned: kubectl delete
ingress monitoring-ingress restores service instantly while proper fix is implemented.

### Key Takeaway
One ingressClassName = one nginx process = one merged nginx.conf. Annotations on any
Ingress object can affect all traffic. Production pattern: put monitoring in a separate
namespace with its own Ingress controller so it can't pollute production routing.
