"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.runOnce = runOnce;
const firestore_1 = require("firebase-admin/firestore");
const TTL_MS = 24 * 60 * 60 * 1000;
/**
 * Runs `compute` once per `requestId`; a repeat returns the stored response
 * (docs/ERRORS.md section 6, DATA_MODEL `requests/{requestId}`). The record
 * expires after 24 h through the Firestore TTL policy on `expiresAt`.
 */
async function runOnce(db, options, compute) {
    const ref = db.collection("requests").doc(options.requestId);
    const existing = await ref.get();
    if (existing.exists) {
        return existing.get("response");
    }
    const response = await compute();
    // A transaction makes the first writer win if two calls race.
    return db.runTransaction(async (tx) => {
        const again = await tx.get(ref);
        if (again.exists)
            return again.get("response");
        tx.set(ref, {
            uid: options.uid,
            fn: options.fn,
            response,
            expiresAt: firestore_1.Timestamp.fromMillis(Date.now() + TTL_MS),
        });
        return response;
    });
}
//# sourceMappingURL=idempotency.js.map