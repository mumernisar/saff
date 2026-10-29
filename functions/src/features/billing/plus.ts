import { FieldValue, Timestamp, type Firestore } from "firebase-admin/firestore";
import { z } from "zod";
import { callable, db } from "../../core/callable";
import { currentConstants } from "../../core/config";
import { AppError } from "../../core/errors";
import { computeEntitlement, type Subscription } from "../../domain/billing/entitlement";

/** Writes the entitlement of [uid] and recomputes the limits of saffs they own. */
export async function applyEntitlement(
  db: Firestore,
  uid: string,
  sub: Subscription | null,
  nowMs = Date.now(),
): Promise<void> {
  const c = currentConstants();
  const e = computeEntitlement(sub, nowMs, c);
  await db.doc(`users/${uid}/entitlement/current`).set({
    plan: e.plan,
    status: e.status,
    ...(e.graceUntilMs ? { graceUntil: Timestamp.fromMillis(e.graceUntilMs) } : {}),
    ...(sub ? { productId: sub.productId, expiresAt: Timestamp.fromMillis(sub.expiresAtMs) } : {}),
    limits: e.limits,
    updatedAt: FieldValue.serverTimestamp(),
  });
  const owned = await db.collection("saffs").where("ownerId", "==", uid).get();
  for (const s of owned.docs) {
    const limit = Math.max(c.maxSaffSizeFree, e.limits.maxOwnedSaffSize);
    const count = s.get("memberCount") as number;
    await s.ref.update({ memberLimit: limit, overLimit: count > limit });
  }
}

/** Dev only (R-13): grants or revokes Plus in the Functions emulator. */
export const devSetPlus = callable(
  "devSetPlus",
  z.object({ on: z.boolean() }),
  async (input, { uid }) => {
    if (process.env.FUNCTIONS_EMULATOR !== "true") throw new AppError("PERMISSION_DENIED");
    await applyEntitlement(
      db,
      uid,
      input.on
        ? { state: "ACTIVE", expiresAtMs: Date.now() + 30 * 86_400_000, productId: "dev" }
        : null,
    );
    return { ok: true };
  },
);

/**
 * Purchase verification needs the Google Play Developer API and a service
 * account (owner action, `OWNER_DECISIONS.md`); until then it reports billing
 * as unavailable instead of trusting the client.
 */
export const verifyPurchase = callable(
  "verifyPurchase",
  z.object({ productId: z.string(), purchaseToken: z.string() }),
  async () => {
    throw new AppError("BILLING_UNAVAILABLE");
  },
);

/** A Plus member takes over an over-limit saff (docs/PRODUCT.md section 15.4). */
export const claimOwnership = callable(
  "claimOwnership",
  z.object({ saffId: z.string().min(1) }),
  async (input, { uid }) => {
    const ref = db.doc(`saffs/${input.saffId}`);
    const [saff, ent] = await Promise.all([ref.get(), db.doc(`users/${uid}/entitlement/current`).get()]);
    if (!saff.exists) throw new AppError("SAFF_NOT_FOUND");
    if (!(saff.get("memberIds") as string[]).includes(uid)) throw new AppError("NOT_PARTICIPANT");
    if (ent.get("plan") !== "plus") throw new AppError("PLUS_REQUIRED");
    if (!saff.get("overLimit")) throw new AppError("SAFF_NOT_OVER_LIMIT");
    const previous = saff.get("ownerId") as string;
    await db.runTransaction(async (tx) => {
      tx.update(ref, { ownerId: uid });
      tx.update(ref.collection("members").doc(uid), { role: "owner" });
      tx.update(ref.collection("members").doc(previous), { role: "member" });
    });
    await applyEntitlement(db, uid, {
      state: "ACTIVE",
      expiresAtMs: (ent.get("expiresAt") as Timestamp | undefined)?.toMillis() ?? Date.now() + 86_400_000,
      productId: (ent.get("productId") as string) ?? "plus",
    });
    return { ok: true };
  },
);
