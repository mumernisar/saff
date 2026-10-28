"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.nudge = exports.tick = exports.sweeper = exports.onResultCreated = void 0;
const firestore_1 = require("firebase-admin/firestore");
const firestore_2 = require("firebase-functions/v2/firestore");
const https_1 = require("firebase-functions/v2/https");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const zod_1 = require("zod");
const callable_1 = require("../../core/callable");
const config_1 = require("../../core/config");
const errors_1 = require("../../core/errors");
const lifecycle_1 = require("./lifecycle");
const push_1 = require("./push");
/** Grades a result as soon as it is written, then reveals if everyone is in. */
exports.onResultCreated = (0, firestore_2.onDocumentCreated)({
    document: "saffs/{saffId}/rounds/{occId}/results/{uid}",
    region: "us-central1",
    maxInstances: 5,
}, async (event) => {
    const { saffId, occId, uid } = event.params;
    await (0, lifecycle_1.gradeResult)(callable_1.db, saffId, occId, uid);
    await (0, lifecycle_1.reveal)(callable_1.db, saffId, occId);
});
/** Every minute: lock rounds, run offline checks and deadlines, expire proposals. */
exports.sweeper = (0, scheduler_1.onSchedule)({ schedule: "every 1 minutes", region: "us-central1", maxInstances: 1 }, async () => {
    await (0, lifecycle_1.runSweep)(callable_1.db);
});
/**
 * Dev ticker endpoint (docs/DEV_RELAXATIONS.md R-11): the Scheduler does not
 * run in the emulator, so `tools/demo/ticker.sh` calls this every few seconds.
 * Refuses to run anywhere but the Functions emulator.
 */
exports.tick = (0, https_1.onRequest)({ region: "us-central1" }, async (_req, res) => {
    if (process.env.FUNCTIONS_EMULATOR !== "true") {
        res.status(404).send("not found");
        return;
    }
    res.json(await (0, lifecycle_1.runSweep)(callable_1.db));
});
/** Asks a member who has not started to ring again. */
exports.nudge = (0, callable_1.callable)("nudge", zod_1.z.object({
    saffId: zod_1.z.string().min(1),
    occurrenceId: zod_1.z.string().min(1),
    targetUid: zod_1.z.string().min(1),
}), async (input, { uid }) => {
    const c = (0, config_1.currentConstants)();
    const roundRef = callable_1.db.doc(`saffs/${input.saffId}/rounds/${input.occurrenceId}`);
    const [round, occ, presence, nudges, sender] = await Promise.all([
        roundRef.get(),
        callable_1.db.doc(`saffs/${input.saffId}/occurrences/${input.occurrenceId}`).get(),
        roundRef.collection("presence").doc(input.targetUid).get(),
        roundRef.collection("nudges").where("fromId", "==", uid).where("toId", "==", input.targetUid).get(),
        callable_1.db.doc(`saffs/${input.saffId}/members/${uid}`).get(),
    ]);
    if (!round.exists || round.get("status") !== "locked")
        throw new errors_1.AppError("ROUND_CLOSED");
    const required = occ.get("requiredIds");
    if (!required.includes(uid) || !required.includes(input.targetUid)) {
        throw new errors_1.AppError("NOT_PARTICIPANT");
    }
    const status = presence.get("status");
    if (status === "done" || status === "playing")
        throw new errors_1.AppError("NUDGE_TARGET_DONE");
    if (nudges.size >= c.nudgesPerTarget)
        throw new errors_1.AppError("NUDGE_LIMIT");
    const lastAt = Math.max(0, ...nudges.docs.map((d) => d.get("at").toMillis()));
    if (Date.now() - lastAt < c.nudgeIntervalMs)
        throw new errors_1.AppError("NUDGE_TOO_SOON");
    await roundRef.collection("nudges").add({
        fromId: uid,
        toId: input.targetUid,
        at: firestore_1.FieldValue.serverTimestamp(),
    });
    await (0, push_1.pushToUser)(callable_1.db, input.targetUid, {
        type: "nudge",
        saffId: input.saffId,
        occurrenceId: input.occurrenceId,
        fromName: sender.get("displayName") ?? "",
        v: "1",
    }, { highPriority: true });
    return { left: c.nudgesPerTarget - nudges.size - 1 };
});
//# sourceMappingURL=rounds.js.map