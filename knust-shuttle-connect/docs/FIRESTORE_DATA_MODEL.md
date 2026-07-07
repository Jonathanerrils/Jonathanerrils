# Firestore Data Model

Six collections: `users`, `stops`, `checkins`, `shuttles`, `trips`,
`analytics_daily`.
Payloads are deliberately tiny (a handful of scalar fields per doc) — the
whole student flow costs a few KB of data.

## `users/{uid}`

Profile + role. Doc id is the Firebase Auth uid.

| Field | Type | Notes |
|---|---|---|
| `email` | string | |
| `displayName` | string? | optional |
| `role` | string | `student` \| `driver` \| `admin`. Self-signup can only create `student`; rules block users from changing their own role. Admins promote accounts via console/Admin SDK. |
| `createdAt` | timestamp | server timestamp |

## `stops/{stopId}`

One doc per bus stop. `stopId` is a slug (`commercial-area`). Admin-editable
in-app; seeded by `tool/seed_stops.mjs`.

| Field | Type | Notes |
|---|---|---|
| `name` | string | display name |
| `latitude`, `longitude` | number | verify with the transport office |
| `geofenceRadiusMeters` | number | default 75, admin-adjustable per stop |
| `active` | bool | soft delete — inactive stops disappear from apps |
| `waitingCount` | number | **written only by Cloud Functions** (Admin SDK bypasses rules; clients can never write it) |
| `enRouteBy` | string? | uid of driver heading here (null = none) |
| `enRouteAt` | timestamp? | when en-route was marked |
| `arrivedAt` | timestamp? | set by "Arrived"; starts the 5-min boarding-decay clock |

Drivers may update only `enRouteBy` / `enRouteAt` / `arrivedAt` (enforced via
`diff().affectedKeys()` in rules).

## `checkins/{studentUid}`

**Doc id is the student uid** — this is what structurally guarantees one
active check-in per student: checking in elsewhere replaces the doc, and the
`onCheckInWritten` trigger converts that single write into `-1` on the old
stop and `+1` on the new one.

| Field | Type | Notes |
|---|---|---|
| `stopId` | string | must reference an existing stop (validated in rules) |
| `stopName` | string | denormalised for offline display |
| `createdAt` | timestamp | server timestamp |
| `updatedAt` | timestamp | server timestamp; rules require ≥ 55 s between updates (rate limit) |
| `expiresAt` | timestamp | createdAt + 25 min; rules cap at request.time + 30 min; `sweepCheckIns` deletes expired docs every 5 min |

Privacy: students read/write only their own doc; **drivers have no read
access at all** — they only see `stops.waitingCount`.

## `shuttles/{driverUid}`

Live position for on-duty drivers who opted in (Phase 2/3 map + ETA source).

| Field | Type | Notes |
|---|---|---|
| `onDuty` | bool | toggle in driver app |
| `latitude`, `longitude` | number | updated on ≥ 25 m movement |
| `heading`, `speed` | number | from GPS |
| `updatedAt` | timestamp | staleness check for the map |

## `trips/{tripId}`

Append-only service log, written by `onStopStatusChanged` the moment a
driver marks **Arrived**. Admin read-only; no client writes.

| Field | Type | Notes |
|---|---|---|
| `stopId`, `stopName` | string | stop that was served |
| `driverUid` | string? | which shuttle served it |
| `enRouteAt`, `arrivedAt` | timestamp? | response time = arrivedAt − enRouteAt |
| `waitingAtArrival` | number | queue size when the shuttle pulled in |
| `createdAt` | timestamp | |

## `analytics_daily/{stopId}_{yyyy-MM-dd}`

Per-stop, per-day demand counters bumped by `onCheckInWritten` on every new
check-in — the source for the admin Analytics tab (peak hours, daily
patterns). Ghana is UTC year-round, so UTC hour buckets are local hours.
Admin read-only; written only by Cloud Functions.

| Field | Type | Notes |
|---|---|---|
| `stopId` | string | |
| `date` | string | `yyyy-MM-dd` (query key) |
| `total` | number | check-ins that day |
| `hourly` | map | `h0`…`h23` → check-ins started in that hour |

## Count integrity — who writes what

```
student app ──creates/replaces/deletes──▶ checkins/{uid}
                                             │ (trigger)
                              onCheckInWritten: ±1 ──▶ stops.waitingCount
sweepCheckIns (5 min): expiry + arrival decay ──▶ deletes checkins
recountWaiting (nightly): full recount    ──▶ heals any drift
driver app ──en-route fields only──▶ stops/{id}
admin app  ──stop definitions──▶ stops/{id} (never waitingCount)
```
