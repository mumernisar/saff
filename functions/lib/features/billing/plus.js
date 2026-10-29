"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.claimOwnership = exports.verifyPurchase = exports.devSetPlus = void 0;
exports.applyEntitlement = applyEntitlement;
const firestore_1 = require("firebase-admin/firestore");
const zod_1 = require("zod");
const callable_1 = require("../../core/callable");
const config_1 = require("../../core/config");
const errors_1 = require("../../core/errors");
const entitlement_1 = require("../../domain/billing/entitlement");
/** Writes the entitlement of [uid] and recomputes the limits of saffs they own. */
async function applyEntitlement(db, uid, sub, nowMs = Date.now()) {
    const c = (0, config_1.currentConstants)();
    const e = (0, entitlement_1.computeEntitlement)(sub, nowMs, c);
    await db.doc(`users/${uid}/entitlement/current`).set({
        plan: e.plan,
        status: e.status,
        ...(e.graceUntilMs ? { graceUntil: firestore_1.Timestamp.fromMillis(e.graceUntilMs) } : {}),
        ...(sub ? { productId: sub.productId, expiresAt: firestore_1.Timestamp.fromMillis(sub.expiresAtMs) } : {}),
        limits: e.limits,
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    });
    const owned = await db.collection("saffs").where("ownerId", "==", uid).get();
    for (const s of owned.docs) {
        const limit = Math.max(c.maxSaffSizeFree, e.limits.maxOwnedSaffSize);
        const count = s.get("memberCount");
        await s.ref.update({ memberLimit: limit, overLimit: count > limit });
    }
}
/** Dev only (R-13): grants or revokes Plus in the Functions emulator. */
exports.devSetPlus = (0, callable_1.callable)("devSetPlus", zod_1.z.object({ on: zod_1.z.boolean() }), async (input, { uid }) => {
    if (process.env.FUNCTIONS_EMULATOR !== "true")
        throw new errors_1.AppError("PERMISSION_DENIED");
    await applyEntitlement(callable_1.db, uid, input.on
        ? { state: "ACTIVE", expiresAtMs: Date.now() + 30 * 86_400_000, productId: "dev" }
        : null);
    return { ok: true };
});
/**
 * Purchase verification needs the Google Play Developer API and a service
 * account (owner action, `OWNER_DECISIONS.md`); until then it reports billing
 * as unavailable instead of trusting the client.
 */
exports.verifyPurchase = (0, callable_1.callable)("verifyPurchase", zod_1.z.object({ productId: zod_1.z.string(), purchaseToken: zod_1.z.string() }), async () => {
    throw new errors_1.AppError("BILLING_UNAVAILABLE");
});
/** A Plus member takes over an over-limit saff (docs/PRODUCT.md section 15.4). */
exports.claimOwnership = (0, callable_1.callable)("claimOwnership", zod_1.z.object({ saffId: zod_1.z.string().min(1) }), async (input, { uid }) => {
    const ref = callable_1.db.doc(`saffs/${input.saffId}`);
    const [saff, ent] = await Promise.all([ref.get(), callable_1.db.doc(`users/${uid}/entitlement/current`).get()]);
    if (!saff.exists)
        throw new errors_1.AppError("SAFF_NOT_FOUND");
    if (!saff.get("memberIds").includes(uid))
        throw new errors_1.AppError("NOT_PARTICIPANT");
    if (ent.get("plan") !== "plus")
        throw new errors_1.AppError("PLUS_REQUIRED");
    if (!saff.get("overLimit"))
        throw new errors_1.AppError("SAFF_NOT_OVER_LIMIT");
    const previous = saff.get("ownerId");
    await callable_1.db.runTransaction(async (tx) => {
        tx.update(ref, { ownerId: uid });
        tx.update(ref.collection("members").doc(uid), { role: "owner" });
        tx.update(ref.collection("members").doc(previous), { role: "member" });
    });
    await applyEntitlement(callable_1.db, uid, {
        state: "ACTIVE",
        expiresAtMs: ent.get("expiresAt")?.toMillis() ?? Date.now() + 86_400_000,
        productId: ent.get("productId") ?? "plus",
    });
    return { ok: true };
});
//# sourceMappingURL=plus.js.map