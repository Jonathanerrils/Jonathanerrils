/**
 * KNUST Shuttle Connect — Cloud Functions.
 *
 * These functions are the server-side half of the count-accuracy logic:
 *  1. onCheckInWritten   — keeps stops/{id}.waitingCount in sync with the
 *                          checkins collection (clients can never write it).
 *  2. sweepCheckIns      — every 5 min: deletes expired check-ins (25-min TTL)
 *                          and applies shuttle-arrival decay (students who
 *                          didn't answer "Did you board?" within 5 min).
 *  3. onStopStatusChanged— notifies waiting students when a shuttle is en
 *                          route to / arrives at their stop (FCM topics).
 *  4. recountWaiting     — nightly self-heal: recomputes every count from
 *                          scratch so drift can never accumulate.
 */
import { onDocumentWritten, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/v2";
import { initializeApp } from "firebase-admin/app";
import {
  getFirestore,
  FieldValue,
  Timestamp,
  DocumentSnapshot,
} from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";

initializeApp();
const db = getFirestore();

/** Grace period after a shuttle arrives before unanswered check-ins clear. */
const BOARDING_GRACE_MINUTES = 5;
/** Batched deletes stay well under the 500-op Firestore batch limit. */
const BATCH_SIZE = 400;

const stopTopic = (stopId: string) => `stop_${stopId}`;

function stopIdOf(snap: DocumentSnapshot | undefined): string | null {
  if (!snap || !snap.exists) return null;
  return (snap.data()?.stopId as string | undefined) ?? null;
}

/**
 * 1. Maintain waitingCount. A check-in doc's id is the student uid, so a
 * stop switch arrives as a single update: -1 on the old stop, +1 on the new.
 * set(..., {merge}) instead of update() so a deleted stop doc can't wedge
 * the trigger.
 */
export const onCheckInWritten = onDocumentWritten(
  "checkins/{uid}",
  async (event) => {
    const beforeStop = stopIdOf(event.data?.before);
    const afterStop = stopIdOf(event.data?.after);
    if (beforeStop === afterStop) return; // expiry refresh — count unchanged

    const batch = db.batch();
    if (beforeStop) {
      batch.set(
        db.doc(`stops/${beforeStop}`),
        { waitingCount: FieldValue.increment(-1) },
        { merge: true }
      );
    }
    if (afterStop) {
      batch.set(
        db.doc(`stops/${afterStop}`),
        { waitingCount: FieldValue.increment(1) },
        { merge: true }
      );
    }
    await batch.commit();
  }
);

/**
 * 2. Five-minute sweep: auto-expiry + shuttle-arrival decay.
 * Deletions here re-trigger onCheckInWritten, which decrements the counts.
 */
export const sweepCheckIns = onSchedule("every 5 minutes", async () => {
  const now = Timestamp.now();

  // 2a. Expired check-ins (client sets expiresAt = createdAt + 25 min;
  // rules cap it at +30 min, so a tampered client gains almost nothing).
  const expired = await db
    .collection("checkins")
    .where("expiresAt", "<=", now)
    .limit(BATCH_SIZE)
    .get();
  if (!expired.empty) {
    const batch = db.batch();
    expired.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    logger.info(`Expired ${expired.size} stale check-ins`);
  }

  // 2b. Arrival decay: a shuttle arrived >5 min ago and the student never
  // answered "Did you board?" — clear everyone who was already waiting
  // when it arrived, then reset the stop's en-route status.
  const graceCutoff = Timestamp.fromMillis(
    now.toMillis() - BOARDING_GRACE_MINUTES * 60 * 1000
  );
  const arrivedStops = await db
    .collection("stops")
    .where("arrivedAt", "<=", graceCutoff)
    .get();

  for (const stopDoc of arrivedStops.docs) {
    const arrivedAt = stopDoc.data().arrivedAt as Timestamp;
    const waiting = await db
      .collection("checkins")
      .where("stopId", "==", stopDoc.id)
      .get();
    const batch = db.batch();
    let cleared = 0;
    waiting.docs.forEach((doc) => {
      const createdAt = doc.data().createdAt as Timestamp | undefined;
      // Only students who were waiting BEFORE the shuttle arrived — someone
      // who checked in after it left keeps their place in the count.
      if (!createdAt || createdAt.toMillis() <= arrivedAt.toMillis()) {
        batch.delete(doc.ref);
        cleared++;
      }
    });
    batch.update(stopDoc.ref, {
      enRouteBy: null,
      enRouteAt: null,
      arrivedAt: null,
    });
    await batch.commit();
    logger.info(`Arrival decay at ${stopDoc.id}: cleared ${cleared}`);
  }
});

/**
 * 3. Push notifications on stop status changes.
 * Students subscribe to topic `stop_{stopId}` when they check in there.
 */
export const onStopStatusChanged = onDocumentUpdated(
  "stops/{stopId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;
    const stopId = event.params.stopId;
    const stopName = (after.name as string) ?? stopId;

    const enRouteStarted = !before.enRouteBy && after.enRouteBy && !after.arrivedAt;
    const justArrived = !before.arrivedAt && after.arrivedAt;

    if (!enRouteStarted && !justArrived) return;

    const message = justArrived
      ? {
          title: `Shuttle arrived at ${stopName}`,
          body: "Did you board? Open the app and tap ‘I boarded’ — otherwise you’ll be removed from the queue in 5 minutes.",
        }
      : {
          title: "Shuttle on the way 🚌",
          body: `A shuttle is heading to ${stopName} now.`,
        };

    try {
      await getMessaging().send({
        topic: stopTopic(stopId),
        notification: message,
        android: { priority: "high" as const },
      });
    } catch (err) {
      // Notification failure must never break the driver's status update.
      logger.warn(`FCM send failed for ${stopId}`, err as Error);
    }
  }
);

/**
 * 4. Nightly self-heal: recompute every stop's waitingCount from the actual
 * check-in documents. Any drift (missed trigger, manual console edits)
 * disappears within a day.
 */
export const recountWaiting = onSchedule("every day 03:00", async () => {
  const [stops, checkins] = await Promise.all([
    db.collection("stops").get(),
    db.collection("checkins").get(),
  ]);

  const counts = new Map<string, number>();
  checkins.docs.forEach((doc) => {
    const stopId = doc.data().stopId as string | undefined;
    if (stopId) counts.set(stopId, (counts.get(stopId) ?? 0) + 1);
  });

  const batch = db.batch();
  stops.docs.forEach((stopDoc) => {
    const actual = counts.get(stopDoc.id) ?? 0;
    if ((stopDoc.data().waitingCount ?? 0) !== actual) {
      batch.update(stopDoc.ref, { waitingCount: actual });
    }
  });
  await batch.commit();
  logger.info("Nightly recount complete");
});
