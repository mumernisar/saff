import type { Firestore } from "firebase-admin/firestore";
import { Timestamp } from "firebase-admin/firestore";

const TTL_MS = 24 * 60 * 60 * 1000;

/**
 * Runs `compute` once per `requestId`; a repeat returns the stored response
 * (docs/ERRORS.md section 6, DATA_MODEL `requests/{requestId}`). The record
 * expires after 24 h through the Firestore TTL policy on `expiresAt`.
 */
export async function runOnce<T extends Record<string, unknown>>(
  db: Firestore,
  options: { requestId: string; uid: string; fn: string },
  compute: () => Promise<T>,
): Promise<T> {
  const ref = db.collection("requests").doc(options.requestId);
  const existing = await ref.get();
  if (existing.exists) {
    return existing.get("response") as T;
  }
  const response = await compute();
  // A transaction makes the first writer win if two calls race.
  return db.runTransaction(async (tx) => {
    const again = await tx.get(ref);
    if (again.exists) return again.get("response") as T;
    tx.set(ref, {
      uid: options.uid,
      fn: options.fn,
      response,
      expiresAt: Timestamp.fromMillis(Date.now() + TTL_MS),
    });
    return response;
  });
}
