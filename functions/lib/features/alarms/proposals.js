"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.skipOccurrence = exports.leaveAlarm = exports.joinAlarm = exports.voteProposal = exports.createProposal = void 0;
exports.tally = tally;
exports.expireProposals = expireProposals;
const firestore_1 = require("firebase-admin/firestore");
const zod_1 = require("zod");
const callable_1 = require("../../core/callable");
const config_1 = require("../../core/config");
const errors_1 = require("../../core/errors");
const occurrences_1 = require("../../domain/alarms/occurrences");
const time_1 = require("../../domain/alarms/time");
const membership_1 = require("../saffs/membership");
const planning_1 = require("./planning");
const alarmPayload = zod_1.z.object({
    name: zod_1.z.string().trim().min(1).max(24),
    time: zod_1.z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/),
    days: zod_1.z.array(zod_1.z.number().int().min(1).max(7)).min(1).max(7),
    timezone: zod_1.z.string().refine(time_1.isValidTimezone),
    activeFrom: zod_1.z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
});
async function assertConflictFree(uid, spec, ignoreId) {
    const c = (0, config_1.currentConstants)();
    const mine = await (0, planning_1.alarmsOfUser)(callable_1.db, uid);
    const clash = (0, occurrences_1.findConflict)(spec, mine, Date.now(), c.alarmConflictWindowMs, 14, ignoreId);
    if (clash)
        throw new errors_1.AppError("ALARM_CONFLICT", { with: clash.label });
}
function expiryFor(spec) {
    const c = (0, config_1.currentConstants)();
    const now = Date.now();
    const first = spec ? (0, occurrences_1.ringMoments)(spec, now, now + 8 * 86_400_000)[0] : undefined;
    const at = first ? first.ringAtMs - c.nightLockLeadMs : now + 86_400_000;
    return firestore_1.Timestamp.fromMillis(Math.max(at, now + 60_000));
}
/** Creates an alarm proposal (create / change / delete) and its chat card. */
exports.createProposal = (0, callable_1.callable)("createProposal", zod_1.z.object({
    saffId: zod_1.z.string().min(1),
    type: zod_1.z.enum(["alarmCreate", "alarmChange", "alarmDelete"]),
    payload: alarmPayload.partial().optional(),
    targetId: zod_1.z.string().optional(),
    supersedes: zod_1.z.string().optional(),
}), async (input, { uid }) => {
    const c = (0, config_1.currentConstants)();
    const saffRef = callable_1.db.doc(`saffs/${input.saffId}`);
    const saffSnap = await saffRef.get();
    if (!saffSnap.exists)
        throw new errors_1.AppError("SAFF_NOT_FOUND");
    const memberIds = saffSnap.get("memberIds");
    if (!memberIds.includes(uid))
        throw new errors_1.AppError("NOT_PARTICIPANT");
    if (saffSnap.get("endedAt") || memberIds.length < 2)
        throw new errors_1.AppError("SAFF_TOO_SMALL");
    const isPair = memberIds.length === 2;
    let spec;
    let target;
    if (input.type === "alarmCreate") {
        if (saffSnap.get("overLimit"))
            throw new errors_1.AppError("SAFF_OVER_LIMIT");
        const parsed = alarmPayload.safeParse(input.payload);
        if (!parsed.success)
            throw new errors_1.AppError("ALARM_INVALID");
        spec = parsed.data;
        const alarms = await saffRef.collection("alarms").get();
        const live = alarms.docs.filter((d) => d.get("status") !== "deleted").length;
        if (live >= c.maxAlarmsPerSaff)
            throw new errors_1.AppError("ALARM_LIMIT");
    }
    else {
        if (!input.targetId)
            throw new errors_1.AppError("ALARM_INVALID");
        const a = await saffRef.collection("alarms").doc(input.targetId).get();
        if (!a.exists || a.get("status") === "deleted")
            throw new errors_1.AppError("NOT_FOUND");
        target = {
            id: a.id,
            participantIds: a.get("participantIds") ?? [],
            data: a.data(),
        };
        if (!isPair && !target.participantIds.includes(uid))
            throw new errors_1.AppError("NOT_PARTICIPANT");
        if (input.type === "alarmChange") {
            const merged = alarmPayload.safeParse({
                name: target.data.name,
                time: target.data.time,
                days: target.data.days,
                timezone: target.data.timezone,
                ...(input.payload ?? {}),
            });
            if (!merged.success)
                throw new errors_1.AppError("ALARM_INVALID");
            spec = merged.data;
        }
    }
    if (spec)
        await assertConflictFree(uid, spec, target?.id);
    const proposalRef = saffRef.collection("proposals").doc();
    const messageRef = saffRef.collection("messages").doc();
    const result = await callable_1.db.runTransaction(async (tx) => {
        // Supersede pending proposals on the same alarm, and the one being replaced.
        const pending = await tx.get(saffRef.collection("proposals").where("status", "==", "pending"));
        for (const p of pending.docs) {
            const sameTarget = target && p.get("targetId") === target.id;
            if (sameTarget || p.id === input.supersedes) {
                tx.update(p.ref, { status: "superseded" });
                (0, membership_1.postSystemMessage)(tx, callable_1.db, input.saffId, "proposal_outcome", `${p.id}`, {
                    proposalId: p.id,
                    status: "superseded",
                });
            }
        }
        let alarmId = target?.id;
        let required;
        if (input.type === "alarmCreate") {
            if (isPair) {
                required = memberIds;
            }
            else {
                required = [];
                const alarmRef = saffRef.collection("alarms").doc();
                alarmId = alarmRef.id;
                tx.set(alarmRef, {
                    ...spec,
                    status: "waiting",
                    participantIds: [uid],
                    createdBy: uid,
                    version: 1,
                    createdAt: firestore_1.FieldValue.serverTimestamp(),
                });
            }
        }
        else {
            required = isPair ? memberIds : target.participantIds;
        }
        tx.set(proposalRef, {
            type: input.type,
            payload: spec ?? {},
            ...(alarmId ? { targetId: alarmId } : {}),
            proposerId: uid,
            status: "pending",
            requiredIds: required,
            acceptedIds: [uid],
            ...(input.supersedes ? { supersedes: input.supersedes } : {}),
            expiresAt: expiryFor(spec),
            messageId: messageRef.id,
            createdAt: firestore_1.FieldValue.serverTimestamp(),
        });
        tx.set(proposalRef.collection("votes").doc(uid), {
            vote: "accept",
            at: firestore_1.FieldValue.serverTimestamp(),
        });
        tx.set(messageRef, {
            type: "proposal",
            authorId: uid,
            systemPayload: { proposalId: proposalRef.id, proposalType: input.type },
            createdAt: firestore_1.FieldValue.serverTimestamp(),
            seenBy: {},
        });
        return { proposalId: proposalRef.id, alarmId };
    });
    await tally(callable_1.db, input.saffId, result.proposalId);
    return result;
});
/** Records an accept or decline on a proposal. */
exports.voteProposal = (0, callable_1.callable)("voteProposal", zod_1.z.object({
    saffId: zod_1.z.string().min(1),
    proposalId: zod_1.z.string().min(1),
    vote: zod_1.z.enum(["accept", "decline"]),
}), async (input, { uid }) => {
    const saffRef = callable_1.db.doc(`saffs/${input.saffId}`);
    const propRef = saffRef.collection("proposals").doc(input.proposalId);
    const [saff, prop] = await Promise.all([saffRef.get(), propRef.get()]);
    if (!saff.exists || !prop.exists)
        throw new errors_1.AppError("NOT_FOUND");
    const memberIds = saff.get("memberIds");
    if (!memberIds.includes(uid))
        throw new errors_1.AppError("NOT_PARTICIPANT");
    const type = prop.get("type");
    const status = prop.get("status");
    const isPair = memberIds.length === 2;
    const joinsAfterStart = !isPair && type === "alarmCreate" && status === "accepted";
    if (status === "expired")
        throw new errors_1.AppError("PROPOSAL_EXPIRED");
    if (status === "superseded")
        throw new errors_1.AppError("PROPOSAL_SUPERSEDED");
    if (status !== "pending" && !joinsAfterStart)
        throw new errors_1.AppError("PROPOSAL_NOT_PENDING");
    const required = prop.get("requiredIds");
    if (required.length > 0 && !required.includes(uid))
        throw new errors_1.AppError("NOT_PARTICIPANT");
    if (input.vote === "accept" && type !== "alarmDelete") {
        const payload = prop.get("payload");
        await assertConflictFree(uid, payload, prop.get("targetId"));
    }
    const batch = callable_1.db.batch();
    batch.set(propRef.collection("votes").doc(uid), {
        vote: input.vote,
        at: firestore_1.FieldValue.serverTimestamp(),
    });
    if (input.vote === "accept") {
        batch.update(propRef, { acceptedIds: firestore_1.FieldValue.arrayUnion(uid) });
        if (!isPair && type === "alarmCreate") {
            batch.update(saffRef.collection("alarms").doc(prop.get("targetId")), {
                participantIds: firestore_1.FieldValue.arrayUnion(uid),
            });
        }
    }
    await batch.commit();
    await tally(callable_1.db, input.saffId, input.proposalId);
    return { ok: true };
});
/**
 * Evaluates a proposal against its votes and applies the outcome. Idempotent:
 * a resolved proposal is left alone.
 */
async function tally(db, saffId, proposalId) {
    const c = (0, config_1.currentConstants)();
    const saffRef = db.doc(`saffs/${saffId}`);
    const propRef = saffRef.collection("proposals").doc(proposalId);
    const replan = await db.runTransaction(async (tx) => {
        const [saff, prop, votes] = await Promise.all([
            tx.get(saffRef),
            tx.get(propRef),
            tx.get(propRef.collection("votes")),
        ]);
        const status = prop.get("status");
        const type = prop.get("type");
        const memberIds = saff.get("memberIds");
        const isPair = memberIds.length === 2;
        const accepted = new Set(prop.get("acceptedIds") ?? []);
        const declined = votes.docs.filter((v) => v.get("vote") === "decline").map((v) => v.id);
        const required = prop.get("requiredIds");
        const targetId = prop.get("targetId");
        const payload = prop.get("payload");
        const alarmRef = targetId ? saffRef.collection("alarms").doc(targetId) : undefined;
        const alarm = alarmRef ? await tx.get(alarmRef) : undefined;
        if (status !== "pending")
            return undefined;
        const outcome = (s) => (0, membership_1.postSystemMessage)(tx, db, saffId, "proposal_outcome", proposalId, {
            proposalId,
            status: s,
        });
        if (type === "alarmCreate" && !isPair) {
            // Group alarm: opt-in; starts at MIN_GROUP_ALARM_PARTICIPANTS.
            const participants = alarm?.get("participantIds") ?? [];
            if (alarm?.get("status") === "waiting" && participants.length >= c.minGroupAlarmParticipants) {
                tx.update(alarmRef, { status: "active" });
                tx.update(propRef, { status: "accepted" });
                outcome("accepted");
                return targetId;
            }
            return undefined;
        }
        if (declined.length > 0 && declined.some((d) => required.includes(d) || required.length === 0)) {
            if (required.length > 0) {
                tx.update(propRef, { status: "declined" });
                outcome("declined");
            }
            return undefined;
        }
        if (!required.every((r) => accepted.has(r)))
            return undefined;
        // Everyone required has accepted.
        if (type === "alarmCreate") {
            const ref = saffRef.collection("alarms").doc();
            tx.set(ref, {
                ...payload,
                status: "active",
                participantIds: required,
                createdBy: prop.get("proposerId"),
                version: 1,
                createdAt: firestore_1.FieldValue.serverTimestamp(),
            });
            tx.update(propRef, { status: "accepted", targetId: ref.id });
            outcome("accepted");
            return ref.id;
        }
        if (type === "alarmChange" && alarmRef) {
            tx.update(alarmRef, { ...payload, version: firestore_1.FieldValue.increment(1) });
            tx.update(propRef, { status: "accepted" });
            outcome("accepted");
            return targetId;
        }
        if (type === "alarmDelete" && alarmRef) {
            tx.update(alarmRef, { status: "deleted" });
            tx.update(propRef, { status: "accepted" });
            outcome("accepted");
            return targetId;
        }
        return undefined;
    });
    if (replan)
        await (0, planning_1.planAlarm)(db, saffId, replan);
}
/** Joins a group alarm from its details (opt-in). */
exports.joinAlarm = (0, callable_1.callable)("joinAlarm", zod_1.z.object({ saffId: zod_1.z.string().min(1), alarmId: zod_1.z.string().min(1) }), async (input, { uid }) => {
    const saffRef = callable_1.db.doc(`saffs/${input.saffId}`);
    const [saff, alarm] = await Promise.all([
        saffRef.get(),
        saffRef.collection("alarms").doc(input.alarmId).get(),
    ]);
    if (!saff.exists || !alarm.exists)
        throw new errors_1.AppError("NOT_FOUND");
    if (!saff.get("memberIds").includes(uid))
        throw new errors_1.AppError("NOT_PARTICIPANT");
    if (alarm.get("status") === "deleted")
        throw new errors_1.AppError("NOT_FOUND");
    await assertConflictFree(uid, alarm.data(), alarm.id);
    const c = (0, config_1.currentConstants)();
    const participants = new Set(alarm.get("participantIds") ?? []);
    participants.add(uid);
    await alarm.ref.update({
        participantIds: [...participants],
        ...(alarm.get("status") === "waiting" && participants.size >= c.minGroupAlarmParticipants
            ? { status: "active" }
            : {}),
    });
    await (0, planning_1.planAlarm)(callable_1.db, input.saffId, input.alarmId);
    return { ok: true };
});
/** Leaves a group alarm (effective from the next lock). */
exports.leaveAlarm = (0, callable_1.callable)("leaveAlarm", zod_1.z.object({ saffId: zod_1.z.string().min(1), alarmId: zod_1.z.string().min(1) }), async (input, { uid }) => {
    const saffRef = callable_1.db.doc(`saffs/${input.saffId}`);
    const [saff, alarm] = await Promise.all([
        saffRef.get(),
        saffRef.collection("alarms").doc(input.alarmId).get(),
    ]);
    if (!saff.exists || !alarm.exists)
        throw new errors_1.AppError("NOT_FOUND");
    if (saff.get("memberIds").length === 2)
        throw new errors_1.AppError("ALARM_INVALID");
    const participants = (alarm.get("participantIds") ?? []).filter((p) => p !== uid);
    if (participants.length === alarm.get("participantIds").length) {
        throw new errors_1.AppError("NOT_PARTICIPANT");
    }
    await alarm.ref.update({
        participantIds: participants,
        ...(participants.length === 0 ? { status: "deleted" } : {}),
    });
    await (0, planning_1.planAlarm)(callable_1.db, input.saffId, input.alarmId);
    return { ok: true };
});
/** Expires pending proposals whose time has passed (called by the sweeper). */
async function expireProposals(db, nowMs) {
    const snap = await db
        .collectionGroup("proposals")
        .where("status", "==", "pending")
        .where("expiresAt", "<=", firestore_1.Timestamp.fromMillis(nowMs))
        .get();
    for (const p of snap.docs) {
        const saffId = p.ref.parent.parent.id;
        const batch = db.batch();
        batch.update(p.ref, { status: "expired" });
        batch.set(db.doc(`saffs/${saffId}/messages/sys_proposal_outcome_${p.id}`), {
            type: "proposal_outcome",
            authorId: "system",
            systemPayload: { proposalId: p.id, status: "expired" },
            createdAt: firestore_1.FieldValue.serverTimestamp(),
            seenBy: {},
        });
        const targetId = p.get("targetId");
        if (p.get("type") === "alarmCreate" && targetId) {
            const alarm = await db.doc(`saffs/${saffId}/alarms/${targetId}`).get();
            if (alarm.get("status") === "waiting")
                batch.update(alarm.ref, { status: "deleted" });
        }
        await batch.commit();
    }
    return snap.size;
}
/** Skips one occurrence for the caller (docs/PRODUCT.md section 4.3). */
exports.skipOccurrence = (0, callable_1.callable)("skipOccurrence", zod_1.z.object({ saffId: zod_1.z.string().min(1), occurrenceId: zod_1.z.string().min(1) }), async (input, { uid }) => {
    const c = (0, config_1.currentConstants)();
    const occRef = callable_1.db.doc(`saffs/${input.saffId}/occurrences/${input.occurrenceId}`);
    await callable_1.db.runTransaction(async (tx) => {
        const occ = await tx.get(occRef);
        if (!occ.exists)
            throw new errors_1.AppError("NOT_FOUND");
        const participants = occ.get("participantIds");
        if (!participants.includes(uid))
            throw new errors_1.AppError("NOT_PARTICIPANT");
        const ringAt = occ.get("ringAt").toMillis();
        if (occ.get("status") !== "planned" || ringAt - Date.now() < c.skipMinNoticeMs) {
            throw new errors_1.AppError("SKIP_TOO_LATE");
        }
        const monthKey = occ.get("date").slice(0, 6);
        const memberRef = callable_1.db.doc(`saffs/${input.saffId}/members/${uid}`);
        const member = await tx.get(memberRef);
        const used = member.get(`stats.skips.${monthKey}`) ?? 0;
        if (used >= c.skipsPerMonth)
            throw new errors_1.AppError("SKIP_LIMIT");
        const skipped = new Set(occ.get("skippedIds") ?? []);
        skipped.add(uid);
        const required = participants.filter((p) => !skipped.has(p));
        tx.update(occRef, {
            skippedIds: [...skipped],
            requiredIds: required,
            ...(required.length === 0 ? { status: "cancelled" } : {}),
        });
        tx.set(occRef.collection("skips").doc(uid), { at: firestore_1.FieldValue.serverTimestamp() });
        tx.update(memberRef, { [`stats.skips.${monthKey}`]: used + 1 });
        (0, membership_1.postSystemMessage)(tx, callable_1.db, input.saffId, "skip", `${input.occurrenceId}_${uid}`, {
            uid,
            occurrenceId: input.occurrenceId,
            date: occ.get("date"),
        });
    });
    return { ok: true };
});
//# sourceMappingURL=proposals.js.map