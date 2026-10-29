"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.deleteAccount = void 0;
const auth_1 = require("firebase-admin/auth");
const zod_1 = require("zod");
const callable_1 = require("../../core/callable");
const membership_1 = require("../saffs/membership");
/**
 * Deletes the caller's account (docs/SECURITY.md section 6): leaves every
 * saff, removes the user's documents, then the Auth user. Messages stay and
 * show as "Deleted user"; they are not rewritten.
 */
exports.deleteAccount = (0, callable_1.callable)("deleteAccount", zod_1.z.object({}), async (_input, { uid }) => {
    const user = await callable_1.db.doc(`users/${uid}`).get();
    const saffIds = user.get("saffIds") ?? [];
    for (const saffId of saffIds) {
        await callable_1.db.runTransaction(async (tx) => {
            const plan = await (0, membership_1.planRemoval)(tx, callable_1.db, saffId);
            if (!plan.memberIds.includes(uid))
                return;
            (0, membership_1.applyRemoval)(tx, callable_1.db, plan, saffId, uid, "left");
        });
    }
    await callable_1.db.recursiveDelete(callable_1.db.doc(`users/${uid}`));
    await (0, auth_1.getAuth)().deleteUser(uid);
    return { ok: true };
});
//# sourceMappingURL=delete_account.js.map