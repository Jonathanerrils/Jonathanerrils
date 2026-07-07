# Testing Checklist — Count Accuracy

Automated tests: `flutter test` covers the geofence maths and the check-in
use case (GPS verification, rate limit, expiry flags). Everything below is
the manual/emulator pass for the server-side halves. Use two phones (or one
phone + one emulator with spoofed location) plus the Firebase console.

## 1. GPS verification
- [ ] Stand (or spoof location) **inside** a stop's geofence → check-in succeeds; confirmation shows stop name + live count.
- [ ] Attempt check-in from **outside** the geofence (pick a far stop from the list) → rejected with "You must be at [stop]…"; Firestore shows no `checkins` doc.
- [ ] Deny location permission → app explains, offers retry, still shows the stop list.

## 2. One active check-in per student
- [ ] Check in at stop A, then walk to stop B and check in there → stop A's count −1, stop B's +1 (watch the driver dashboard), and `checkins/{uid}` shows only stop B.
- [ ] There is never more than one `checkins` doc per uid (doc id = uid).

## 3. Auto-expiry (25 min)
- [ ] Check in, force-quit the app, wait 30 min → `sweepCheckIns` has deleted the doc and the stop count went down (check Functions logs).
- [ ] Emulator shortcut: manually set `expiresAt` in the past → next 5-min sweep removes it.
- [ ] While expired-but-not-yet-swept, the student app already shows "not checked in" (client-side expiry filter).

## 4. Geofence-exit removal
- [ ] Check in, then walk/spoof ~150 m away (radius 75 m + 50 m buffer) → check-in disappears and count decrements without touching the app.
- [ ] Hover near the geofence edge (±10 m) → no flapping in/out (buffer works).

## 5. Shuttle-arrival decay
- [ ] Driver taps **En route** → checked-in students at that stop get the "Shuttle on the way" push within seconds.
- [ ] Driver taps **Arrived** → students get the "Did you board?" push.
- [ ] Student taps **I boarded / Cancel** → their check-in clears immediately.
- [ ] Student ignores the prompt → within ~5–10 min (5-min grace + sweep interval) their check-in is cleared and the stop's en-route status resets.
- [ ] A student who checks in *after* the shuttle arrived is **not** cleared by the decay.

## 6. Rate limiting
- [ ] Check in, cancel, immediately try again → blocked with a "please wait" message until 60 s have passed.
- [ ] Bypass the client (Firestore console/REST as the student) and update the check-in twice within 55 s → second write rejected by rules.

## 7. Count integrity under abuse/failure
- [ ] Try writing `waitingCount` directly as a student and as a driver → both rejected by rules.
- [ ] Driver tries to edit a stop's coordinates → rejected (en-route fields only).
- [ ] Manually corrupt a `waitingCount` in the console → nightly `recountWaiting` (or trigger it manually) restores the true value.

## 8. Real-time & offline behaviour
- [ ] With driver dashboard open, a student check-in appears in the count in **< 3 s**.
- [ ] Airplane mode: student app still shows the cached stop list with the "Showing saved data (last updated …)" banner — never a blank screen.
- [ ] Check in while offline at a valid stop → action queues; on reconnect the check-in syncs and counts update.
- [ ] Kill and reopen the app offline → cached stops render instantly.

## 9. Roles & privacy
- [ ] Student account never sees the driver dashboard and vice versa.
- [ ] As a driver, attempt to read `checkins` (console/REST with driver auth) → denied; drivers see only aggregate counts.
- [ ] Self-signup with a non-KNUST email domain → rejected client-side.
- [ ] A user PATCHing their own `users` doc to `role: admin` → rejected by rules.
- [ ] Driver location doc updates only while the on-duty toggle is on; toggling off writes `onDuty: false` and stops updates.
