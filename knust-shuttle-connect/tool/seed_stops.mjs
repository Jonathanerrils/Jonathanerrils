#!/usr/bin/env node
/**
 * Seed the `stops` collection with KNUST's main shuttle stops.
 *
 * ⚠️  COORDINATES ARE APPROXIMATE PLACEHOLDERS around KNUST campus.
 *     Verify every name and coordinate with the KNUST transport office
 *     (and walk each stop with a GPS app) before going live — the geofence
 *     check-in logic depends on them being right.
 *
 * Usage:
 *   1. Download a service-account key from the Firebase console
 *      (Project settings → Service accounts → Generate new private key).
 *   2. GOOGLE_APPLICATION_CREDENTIALS=./serviceAccountKey.json \
 *        node tool/seed_stops.mjs
 *
 * The script is idempotent: re-running it updates names/coordinates but
 * never touches live waitingCount values.
 */
import { initializeApp, applicationDefault } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

const DEFAULT_RADIUS_M = 75;

// id, name, latitude, longitude  — PLACEHOLDERS, verify before launch.
const STOPS = [
  ["commercial-area", "Commercial Area", 6.6829, -1.5772],
  ["brunei", "Brunei", 6.6797, -1.5722],
  ["ksb", "KSB (KNUST School of Business)", 6.6693, -1.5673],
  ["pharmacy-junction", "Pharmacy Junction", 6.6745, -1.5665],
  ["casford", "Casley Hayford (Casford)", 6.6786, -1.5741],
  ["library", "Prempeh II Library", 6.6752, -1.5723],
  ["indece", "Indece", 6.6821, -1.5701],
  ["hall-7", "Hall 7", 6.6942, -1.5606],
  ["gaza", "Gaza", 6.6870, -1.5570],
  ["medical-village", "Medical Village", 6.6800, -1.5495],
  ["college-of-engineering", "College of Engineering", 6.6720, -1.5650],
];

initializeApp({ credential: applicationDefault() });
const db = getFirestore();

const batch = db.batch();
for (const [id, name, latitude, longitude] of STOPS) {
  batch.set(
    db.collection("stops").doc(id),
    {
      name,
      latitude,
      longitude,
      geofenceRadiusMeters: DEFAULT_RADIUS_M,
      active: true,
    },
    { merge: true } // never clobber live waitingCount
  );
}
await batch.commit();
console.log(`Seeded ${STOPS.length} stops. Verify coordinates with the transport office!`);
