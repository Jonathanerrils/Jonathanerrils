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

## 9. Phase 2 — maps & phone-OTP sign-in
- [ ] Phone sign-in with a Firebase *test number* → OTP screen appears, correct code signs in, a `users` doc with `role: student` is created on first sign-in.
- [ ] Wrong OTP code → clear error, can retry; "Wrong number / resend" returns to the phone field.
- [ ] Local formats (`0551234567`, `055 123 4567`) normalise to `+233…`; garbage input is rejected before any SMS is sent.
- [ ] Student map: every stop shows a numbered badge matching the list counts, colour-coded; checking in elsewhere updates badges live.
- [ ] Driver on duty with location sharing on → an azure shuttle marker appears on the student map and moves; toggling off duty (or 5 min of silence) removes it.
- [ ] ETA card shows a plausible "~N min" for the student's stop and updates as the shuttle moves.
- [ ] Driver map: tapping a badge's info bubble marks that stop en route (list view reflects it).
- [ ] Map screens are opt-in only — the default student flow never loads map tiles.

## 10. Phase 3 — analytics & service log
- [ ] Each new check-in bumps `analytics_daily/{stopId}_{date}` (total + the right `hN` hour bucket); switching stops credits the *new* stop only.
- [ ] Admin → Analytics tab: today's totals match reality, stops sorted busiest-first, peak hour label matches the tallest bar, long-press a bar shows hour + count.
- [ ] Previous-day arrow shows historical days; days with no data say so instead of erroring.
- [ ] Driver taps **Arrived** → a `trips` doc appears with `waitingAtArrival` equal to the count at that moment and the right driver uid.
- [ ] Student checked-in card shows "~N min" once a shuttle is live, and the number updates as the shuttle moves; no shuttle stream runs while not checked in.
- [ ] As a non-admin, reading `analytics_daily` or `trips` is denied by rules.

## 11. Roles & privacy
- [ ] Student account never sees the driver dashboard and vice versa.
- [ ] As a driver, attempt to read `checkins` (console/REST with driver auth) → denied; drivers see only aggregate counts.
- [ ] Self-signup with a non-KNUST email domain → rejected client-side.
- [ ] A user PATCHing their own `users` doc to `role: admin` → rejected by rules.
- [ ] Driver location doc updates only while the on-duty toggle is on; toggling off writes `onDuty: false` and stops updates.
