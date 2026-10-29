"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.gradeAskMe = void 0;
const firestore_1 = require("firebase-admin/firestore");
const zod_1 = require("zod");
const callable_1 = require("../../core/callable");
const errors_1 = require("../../core/errors");
/**
 * The planter grades an ask-me answer after the reveal (docs/PRODUCT.md 5.2).
 * Bonus, never scored: the grade only shows in the review.
 */
exports.gradeAskMe = (0, callable_1.callable)("gradeAskMe", zod_1.z.object({
    saffId: zod_1.z.string().min(1),
    occurrenceId: zod_1.z.string().min(1),
    cardId: zod_1.z.string().min(1),
    correct: zod_1.z.boolean(),
}), async (input, { uid }) => {
    const roundRef = callable_1.db.doc(`saffs/${input.saffId}/rounds/${input.occurrenceId}`);
    const round = await roundRef.get();
    if (!round.exists)
        throw new errors_1.AppError("NOT_FOUND");
    if (round.get("status") !== "revealed")
        throw new errors_1.AppError("ROUND_NOT_READY");
    const card = (round.get("bonusCards") ?? []).find((c) => c.id === input.cardId);
    if (!card || card.authorId !== uid)
        throw new errors_1.AppError("NOT_PARTICIPANT");
    await roundRef
        .collection("askMeGrades")
        .doc(input.cardId)
        .set({ correct: input.correct, by: uid, at: firestore_1.FieldValue.serverTimestamp() });
    return { ok: true };
});
//# sourceMappingURL=ask_me.js.map