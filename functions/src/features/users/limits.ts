import type { Firestore } from "firebase-admin/firestore";
import { currentConstants } from "../../core/config";

/** Per-user limits; free defaults when no entitlement exists yet. */
export interface UserLimits {
  readonly maxSaffs: number;
  readonly maxOwnedSaffSize: number;
}

/** Reads the server-written entitlement and returns the user's limits. */
export async function limitsFor(db: Firestore, uid: string): Promise<UserLimits> {
  const c = currentConstants();
  const snap = await db.doc(`users/${uid}/entitlement/current`).get();
  const limits = snap.get("limits") as
    | { maxSaffs?: number; maxOwnedSaffSize?: number }
    | undefined;
  return {
    maxSaffs: limits?.maxSaffs ?? c.maxSaffsPerUserFree,
    maxOwnedSaffSize: limits?.maxOwnedSaffSize ?? c.maxSaffSizeFree,
  };
}
