"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.postSystemMessage = postSystemMessage;
exports.planRemoval = planRemoval;
exports.applyRemoval = applyRemoval;
const firestore_1 = require("firebase-admin/firestore");
const errors_1 = require("../../core/errors");
/** Writes a system chat message with an idempotent id. */
function postSystemMessage(tx, db, saffId, type, refId, payload) {
    const ref = db.doc(`saffs/${saffId}/messages/sys_${type}_${refId}`);
    tx.set(ref, {
        type,
        authorId: "system",
        systemPayload: payload,
        createdAt: firestore_1.FieldValue.serverTimestamp(),
        seenBy: {},
    });
}
/** Reads what [applyRemoval] needs. */
async function planRemoval(tx, db, saffId) {
    const saffRef = db.doc(`saffs/${saffId}`);
    const [saff, members, alarms, occs] = await Promise.all([
        tx.get(saffRef),
        tx.get(db.collection(`saffs/${saffId}/members`)),
        tx.get(db.collection(`saffs/${saffId}/alarms`)),
        tx.get(db
            .collection(`saffs/${saffId}/occurrences`)
            .where("status", "in", ["planned", "locked"])),
    ]);
    if (!saff.exists)
        throw new errors_1.AppError("SAFF_NOT_FOUND");
    return {
        saffRef,
        memberIds: saff.get("memberIds"),
        ownerId: saff.get("ownerId"),
        memberJoined: new Map(members.docs.map((d) => [d.id, d.get("joinedAt")])),
        alarmDocs: alarms.docs.map((d) => ({
            ref: d.ref,
            participantIds: d.get("participantIds") ?? [],
        })),
        occurrenceDocs: occs.docs.map((d) => ({
            ref: d.ref,
            participantIds: d.get("participantIds") ?? [],
            skippedIds: d.get("skippedIds") ?? [],
            status: d.get("status"),
        })),
    };
}
/** Applies the removal of [uid] using a [RemovalPlan]. */
function applyRemoval(tx, db, plan, saffId, uid, kind) {
    const remaining = plan.memberIds.filter((m) => m !== uid);
    tx.delete(db.doc(`saffs/${saffId}/members/${uid}`));
    tx.update(db.doc(`users/${uid}`), { saffIds: firestore_1.FieldValue.arrayRemove(saffId) });
    const update = {
        memberIds: remaining,
        memberCount: remaining.length,
    };
    if (plan.ownerId === uid && remaining.length > 0) {
        const next = [...remaining].sort((a, b) => (plan.memberJoined.get(a)?.toMillis() ?? 0) -
            (plan.memberJoined.get(b)?.toMillis() ?? 0))[0];
        update.ownerId = next;
        tx.update(db.doc(`saffs/${saffId}/members/${next}`), { role: "owner" });
    }
    const ends = remaining.length <= 1;
    if (ends)
        update.endedAt = firestore_1.FieldValue.serverTimestamp();
    tx.update(plan.saffRef, update);
    for (const a of plan.alarmDocs) {
        if (!a.participantIds.includes(uid) && !ends)
            continue;
        const participants = a.participantIds.filter((p) => p !== uid);
        tx.update(a.ref, {
            participantIds: participants,
            ...(ends || participants.length === 0 ? { status: "deleted" } : {}),
        });
    }
    for (const o of plan.occurrenceDocs) {
        if (ends) {
            tx.update(o.ref, { status: "cancelled" });
        }
        else if (o.participantIds.includes(uid)) {
            const participants = o.participantIds.filter((p) => p !== uid);
            const skipped = o.skippedIds.filter((p) => p !== uid);
            tx.update(o.ref, {
                participantIds: participants,
                skippedIds: skipped,
                requiredIds: participants.filter((p) => !skipped.includes(p)),
                ...(participants.length === 0 ? { status: "cancelled" } : {}),
            });
        }
    }
    postSystemMessage(tx, db, saffId, kind === "left" ? "member_left" : "member_removed", `${uid}_${Date.now()}`, {
        uid,
    });
}
//# sourceMappingURL=membership.js.map