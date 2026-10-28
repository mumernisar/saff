"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.limitsFor = limitsFor;
const config_1 = require("../../core/config");
/** Reads the server-written entitlement and returns the user's limits. */
async function limitsFor(db, uid) {
    const c = (0, config_1.currentConstants)();
    const snap = await db.doc(`users/${uid}/entitlement/current`).get();
    const limits = snap.get("limits");
    return {
        maxSaffs: limits?.maxSaffs ?? c.maxSaffsPerUserFree,
        maxOwnedSaffSize: limits?.maxOwnedSaffSize ?? c.maxSaffSizeFree,
    };
}
//# sourceMappingURL=limits.js.map