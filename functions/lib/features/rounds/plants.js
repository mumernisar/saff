"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.plantCard = void 0;
const firestore_1 = require("firebase-admin/firestore");
const zod_1 = require("zod");
const callable_1 = require("../../core/callable");
const config_1 = require("../../core/config");
const errors_1 = require("../../core/errors");
/**
 * Plants a card for the other member of a pair (docs/PRODUCT.md section 5.2).
 * Templates: askMe (free text, planter reads it), quiz (typed), quizChoice.
 */
exports.plantCard = (0, callable_1.callable)("plantCard", zod_1.z.object({
    saffId: zod_1.z.string().min(1),
    template: zod_1.z.enum(["askMe", "quiz", "quizChoice"]),
    question: zod_1.z.string().trim().min(1),
    answer: zod_1.z.string().trim().max(200).optional(),
    options: zod_1.z.array(zod_1.z.string().trim().min(1).max(100)).length(4).optional(),
    correctIndex: zod_1.z.number().int().min(0).max(3).optional(),
}), async (input, { uid }) => {
    const c = (0, config_1.currentConstants)();
    if (input.question.length > c.plantMaxChars)
        throw new errors_1.AppError("PLANT_TOO_LONG");
    const saffRef = callable_1.db.doc(`saffs/${input.saffId}`);
    const saff = await saffRef.get();
    if (!saff.exists)
        throw new errors_1.AppError("SAFF_NOT_FOUND");
    const memberIds = saff.get("memberIds");
    if (!memberIds.includes(uid))
        throw new errors_1.AppError("NOT_PARTICIPANT");
    if (memberIds.length !== 2)
        throw new errors_1.AppError("PLANT_PAIRS_ONLY");
    const other = memberIds.find((m) => m !== uid);
    const planned = await saffRef.collection("occurrences").where("status", "==", "planned").get();
    const next = planned.docs
        .filter((d) => d.get("requiredIds").includes(uid) &&
        d.get("requiredIds").includes(other) &&
        d.get("ringAt").toMillis() > Date.now())
        .sort((a, b) => a.get("ringAt").toMillis() - b.get("ringAt").toMillis())[0];
    if (!next)
        throw new errors_1.AppError("ROUND_LOCKED");
    let card;
    if (input.template === "askMe") {
        card = { type: "ask", question: input.question, answer: "" };
    }
    else if (input.template === "quiz") {
        if (!input.answer)
            throw new errors_1.AppError("INVALID_ARGUMENT", { field: "answer" });
        card = { type: "typed", question: input.question, answer: input.answer, accept: [input.answer] };
    }
    else {
        if (!input.options || input.correctIndex === undefined) {
            throw new errors_1.AppError("INVALID_ARGUMENT", { field: "options" });
        }
        card = {
            type: "choice",
            question: input.question,
            options: input.options,
            answer: input.options[input.correctIndex],
        };
    }
    await callable_1.db.runTransaction(async (tx) => {
        const plants = await tx.get(next.ref.collection("plants").where("authorId", "==", uid));
        if (plants.size >= c.plantsPerNight)
            throw new errors_1.AppError("PLANT_LIMIT");
        const n = plants.size + 1;
        const id = `${next.id}_${uid}_${n}`;
        tx.set(next.ref.collection("plants").doc(id), {
            authorId: uid,
            template: input.template,
            card: { ...card, id: `plant_${id}`, category: "planted", difficulty: "medium" },
            createdAt: firestore_1.FieldValue.serverTimestamp(),
        });
        tx.update(next.ref, {
            [`plantCounts.${uid}`]: n,
            teaserFor: firestore_1.FieldValue.arrayUnion(other),
        });
    });
    return { occurrenceId: next.id, left: c.plantsPerNight - (await countPlants(next.ref, uid)) };
});
async function countPlants(occRef, uid) {
    return (await occRef.collection("plants").where("authorId", "==", uid).get()).size;
}
//# sourceMappingURL=plants.js.map