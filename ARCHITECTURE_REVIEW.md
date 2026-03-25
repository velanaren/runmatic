# ARCHITECTURE_REVIEW.md


This document is my understanding of runmatic architecture

Runmatic has to perform the below tasks simultaneously 

1. Serve HTTP requests from the browser (constantly, unpredictably)
2. Check every runbook's staleness every hour (scheduled, background)
3. Process deployment webhook events as they arrive (event-driven, unpredictable)
4. Send notifications when staleness thresholds are crossed (triggered)

To achieve this runmatic has 5 different services ( API, Worker, Frontend, Postgresql, Redis )

---

## The Services

### API
1. It is a python program running FAST API
2. Fast API is a web framework. It sits and listens to HTTP requests and then responds to them 
3. This is reactive - only does something when a request arrives 

### Worker
1. It is a python program that runs scheduler and rq
2. It does 2 types of work 
	1. Scheduled work - every hour check the staleness of runback
        2. Queue based work - when an event arrives 


### Frontend
1. Nginx + React - It serves the UI to the browser
2. Browser talks to nginx and nginx does the below 
	1. If it is an API request - forward the request to API
	2. Else render the index.html

### PostgreSQL
1. It is used to store persistent data. Without which the app will not function

### Redis
1. Redis is used to store temporary data ( JWT sessions, API response cache )

---

## Failure Modes I Identified


┌──────────────┬────────────────────────────┬──────────────────────────┐
│   Failure    │       What Breaks          │     What Keeps Working   │
├──────────────┼────────────────────────────┼──────────────────────────┤
│ PostgreSQL   │ Everything that reads or   │ Redis operations (cache  │
│ goes down    │ writes data. API health    │ still serves until TTL). │
│              │ check fails. UI shows      │ Frontend loads (static   │
│              │ errors. Worker staleness   │ files). But nothing      │
│              │ check fails.               │ useful works.            │
├──────────────┼────────────────────────────┼──────────────────────────┤
│ Redis        │ Sessions invalidated -     │ All database reads and   │
│ goes down    │ users logged out. Queue    │ writes. API functional   │
│              │ unavailable, webhooks      │ for non-cached requests. │
│              │ lost. Cache gone and       │ Worker scheduled jobs    │
│              │ slower API responses.      │ (staleness check) still  │
│              │                            │ run - they use DB not    │
│              │                            │ Redis directly.          │
├──────────────┼────────────────────────────┼──────────────────────────┤
│ API          │ UI shows empty state.      │ Worker continues. DB     │
│ goes down    │ All browser requests       │ safe. Redis unaffected.  │
│              │ fail. Webhooks 404.        │ Frontend loads but       │
│              │                            │ shows no data.           │
├──────────────┼────────────────────────────┼──────────────────────────┤
│ Worker       │ Staleness scores freeze.   │ Everything else. Full    │
│ goes down    │ Webhook jobs queue up      │ UI functionality. Data   │
│              │ in Redis unprocessed.      │ reads/writes. Sessions.  │
│              │ Notifications stop.        │ Jobs accumulate in Redis │
│              │                            │ — processed on recovery. │
├──────────────┼────────────────────────────┼──────────────────────────┤
│ Frontend     │ UI inaccessible.           │ API fully functional.    │
│ goes down    │ Users see nothing.         │ Direct API calls work.   │
│              │                            │ All data safe.           │
└──────────────┴────────────────────────────┴──────────────────────────┘

---

## The Request Path

PART 1 — DEPLOYMENT WEBHOOK

1.
  Developer deploys payments-api
  Deployment system sends HTTP POST to Runmatic:
    POST /api/webhooks/deployment
    {service: "payments-api", version: "v1"}

2.
  Nginx receives request on port 3000
  Path is /api/* → forwards to API on port 8000 via Docker DNS

3.
  API receives the webhook
  Validates: is "payments-api" a known service?
  Queries PostgreSQL and returns results: SELECT id FROM services WHERE name = 'payments-api'
  

4.
  API drops job into Redis queue
  API returns 200 OK to deployment system
  API is done,  moves on to next request

5.
  Redis wakes up Worker (BLPOP was waiting)
  Worker receives job data

6.
  Worker queries PostgreSQL:
  SELECT id FROM runbooks WHERE service_id = 2
  PostgreSQL returns: runbook ids [2, 3, 4]

7.
  Worker updates all three runbooks to needs_review.
  UPDATE runbooks
  SET needs_review = true, needs_review_since = now()
  WHERE id IN (2, 3, 4)
  

8.
  Worker drops notification job into queue
  Worker calls BLPOP again — back to watching

--

PART 2 — USER OPENS DASHBOARD 

1.
  User opens browser, navigates to Runmatic dashboard
  Browser sends:
    GET localhost:3000/
  Nginx serves index.html (static file — no API call needed)
  Browser downloads and runs the React application

2.
  React app initialises
  Makes API call:
    GET localhost:3000/api/runbooks
  Nginx sees /api/* → forwards to API :8000

3.
  API receives GET /api/runbooks
  Checks Redis cache:
  If expired or invalidated, it goes to Postgresql to query data
  API queries PostgreSQL:
    SELECT * FROM runbooks ORDER BY staleness_days DESC
  PostgreSQL returns all runbooks
  — runbook ids 2, 3, 4 now show needs_review = true

4.
  API stores result in Redis cache
  API builds JSON response
  Sends response back to Nginx
  Nginx forwards to browser

5.
  React receives the runbook data
  Renders dashboard
  Three runbooks show "needs review" badge
  User sees the updated state

--

FULL SYSTEM VIEW:

Deployment    Nginx    API      Redis    Worker   PostgreSQL
system                                            
    │           │        │        │         │         │
    │──POST────►│        │        │         │         │
    │           │──fwd──►│        │         │         │
    │           │        │──SELECT─────────────────── ►│
    │           │        │◄── id=2 ───────────────────│
    │           │        │──INSERT─────────────────── ►│
    │           │        │──RPUSH─►│         │         │
    │           │        │         │──BLPOP──►│         │
    │◄──200─────│◄──200──│         │         │──SELECT►│
    │           │        │         │         │◄─ids────│
    │           │        │         │         │──UPDATE►│
    │           │        │         │         │◄─done───│
    │           │        │         │◄─RPUSH──│         │
    │           │        │         │         │         │
    │    [30 seconds later]        │         │         │
    │           │        │         │         │         │
Browser────GET─►│        │         │         │         │
    │◄──html────│        │         │         │         │
Browser────GET /api/runbooks──────►│         │         │
    │           │        │──GET────►│(miss)   │         │
    │           │        │──SELECT─────────────────── ►│
    │           │        │◄──rows─────────────────────│
    │           │        │──SET────►│         │         │
    │◄──JSON────│◄──JSON─│         │         │         │
    │ renders   │        │         │         │         │
    │ dashboard │        │         │         │         │


---






