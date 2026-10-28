"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.renameSaff = exports.regenerateInvite = exports.removeMember = exports.leaveSaff = exports.joinSaff = exports.previewInvite = exports.createSaff = exports.registerDevice = exports.setProfile = void 0;
const firestore_1 = require("firebase-admin/firestore");
const zod_1 = require("zod");
const callable_1 = require("../../core/callable");
const config_1 = require("../../core/config");
const errors_1 = require("../../core/errors");
const ids_1 = require("../../core/ids");
const limits_1 = require("../users/limits");
const membership_1 = require("./membership");
const PHONE = /^\+[1-9]\d{7,14}$/;
async function freshCode() {
    for (let i = 0; i < 10; i++) {
        const code = (0, ids_1.newInviteCode)();
        if (!(await callable_1.db.doc(`inviteCodes/${code}`).get()).exists)
            return code;
    }
    throw new errors_1.AppError("SERVER_INTERNAL");
}
/** Creates or updates the caller's profile and contact number. */
exports.setProfile = (0, callable_1.callable)("setProfile", zod_1.z.object({
    displayName: zod_1.z.string().trim().min(1).max(40),
    whatsapp: zod_1.z.string().regex(PHONE),
    avatarColor: zod_1.z.string().max(20).optional(),
}), async (input, { uid }) => {
    const userRef = callable_1.db.doc(`users/${uid}`);
    const existing = await userRef.get();
    const saffIds = existing.get("saffIds") ?? [];
    const color = input.avatarColor ??
        existing.get("avatarColor") ??
        String(Math.floor(Math.random() * 5));
    const batch = callable_1.db.batch();
    batch.set(userRef, {
        displayName: input.displayName,
        avatarColor: color,
        ...(existing.exists
            ? {}
            : { saffIds: [], createdAt: firestore_1.FieldValue.serverTimestamp(), settings: {} }),
    }, { merge: true });
    batch.set(callable_1.db.doc(`users/${uid}/private/contact`), { whatsapp: input.whatsapp });
    for (const id of saffIds) {
        batch.set(callable_1.db.doc(`saffs/${id}/members/${uid}`), { displayName: input.displayName, avatarColor: color, whatsapp: input.whatsapp }, { merge: true });
    }
    await batch.commit();
    return { ok: true };
});
/** Stores the caller's FCM token for this installation. */
exports.registerDevice = (0, callable_1.callable)("registerDevice", zod_1.z.object({ installationId: zod_1.z.string().min(1).max(100), fcmToken: zod_1.z.string().min(1) }), async (input, { uid }) => {
    await callable_1.db.doc(`users/${uid}/devices/${input.installationId}`).set({
        fcmToken: input.fcmToken,
        updatedAt: firestore_1.FieldValue.serverTimestamp(),
    });
    return { ok: true };
});
/** Creates a saff with the caller as owner. */
exports.createSaff = (0, callable_1.callable)("createSaff", zod_1.z.object({ name: zod_1.z.string().trim().min(1).max(40).optional() }), async (input, { uid }) => {
    const c = (0, config_1.currentConstants)();
    const [user, contact, limits] = await Promise.all([
        callable_1.db.doc(`users/${uid}`).get(),
        callable_1.db.doc(`users/${uid}/private/contact`).get(),
        (0, limits_1.limitsFor)(callable_1.db, uid),
    ]);
    if (!user.exists)
        throw new errors_1.AppError("PROFILE_NAME_INVALID");
    const saffIds = user.get("saffIds") ?? [];
    if (saffIds.length >= limits.maxSaffs)
        throw new errors_1.AppError("SAFF_LIMIT");
    const name = input.name ?? `${user.get("displayName")}'s saff`;
    const code = await freshCode();
    const saffRef = callable_1.db.collection("saffs").doc();
    const batch = callable_1.db.batch();
    batch.set(saffRef, {
        name,
        ownerId: uid,
        memberIds: [uid],
        memberCount: 1,
        memberLimit: Math.max(c.maxSaffSizeFree, limits.maxOwnedSaffSize),
        overLimit: false,
        inviteCode: code,
        modeSchedule: { type: "surprise", order: [] },
        cardMix: { packs: [], custom: false, generalKnowledge: true },
        streak: { current: 0, longest: 0 },
        createdAt: firestore_1.FieldValue.serverTimestamp(),
    });
    batch.set(saffRef.collection("members").doc(uid), {
        displayName: user.get("displayName"),
        avatarColor: user.get("avatarColor"),
        whatsapp: contact.get("whatsapp") ?? "",
        role: "owner",
        joinedAt: firestore_1.FieldValue.serverTimestamp(),
        presence: {},
        stats: {},
    });
    batch.set(callable_1.db.doc(`inviteCodes/${code}`), {
        saffId: saffRef.id,
        createdAt: firestore_1.FieldValue.serverTimestamp(),
    });
    batch.update(callable_1.db.doc(`users/${uid}`), { saffIds: firestore_1.FieldValue.arrayUnion(saffRef.id) });
    await batch.commit();
    return { saffId: saffRef.id, inviteCode: code };
});
async function saffForCode(code) {
    if (!(0, ids_1.isInviteCode)(code))
        throw new errors_1.AppError("INVITE_INVALID");
    const invite = await callable_1.db.doc(`inviteCodes/${code}`).get();
    if (!invite.exists)
        throw new errors_1.AppError("INVITE_INVALID");
    const saffId = invite.get("saffId");
    const saff = await callable_1.db.doc(`saffs/${saffId}`).get();
    if (!saff.exists || saff.get("endedAt"))
        throw new errors_1.AppError("INVITE_INVALID");
    return { saffId, saff };
}
/** What the "Join X's saff?" confirmation screen shows. */
exports.previewInvite = (0, callable_1.callable)("previewInvite", zod_1.z.object({ code: zod_1.z.string().trim().toUpperCase() }), async (input) => {
    const { saffId, saff } = await saffForCode(input.code);
    const members = await callable_1.db.collection(`saffs/${saffId}/members`).get();
    const owner = members.docs.find((d) => d.id === saff.get("ownerId"));
    return {
        saffId,
        name: saff.get("name"),
        ownerName: owner?.get("displayName") ?? "",
        memberCount: saff.get("memberCount"),
        memberLimit: saff.get("memberLimit"),
        members: members.docs.map((d) => ({
            name: d.get("displayName"),
            avatarColor: d.get("avatarColor"),
        })),
    };
});
/** Joins a saff by invite code. */
exports.joinSaff = (0, callable_1.callable)("joinSaff", zod_1.z.object({ code: zod_1.z.string().trim().toUpperCase() }), async (input, { uid }) => {
    const { saffId } = await saffForCode(input.code);
    const limits = await (0, limits_1.limitsFor)(callable_1.db, uid);
    await callable_1.db.runTransaction(async (tx) => {
        const saffRef = callable_1.db.doc(`saffs/${saffId}`);
        const [saff, user, contact] = await Promise.all([
            tx.get(saffRef),
            tx.get(callable_1.db.doc(`users/${uid}`)),
            tx.get(callable_1.db.doc(`users/${uid}/private/contact`)),
        ]);
        if (!user.exists)
            throw new errors_1.AppError("PROFILE_NAME_INVALID");
        const memberIds = saff.get("memberIds");
        if (memberIds.includes(uid))
            throw new errors_1.AppError("ALREADY_MEMBER");
        if (saff.get("overLimit") || saff.get("memberCount") >= saff.get("memberLimit")) {
            throw new errors_1.AppError("SAFF_FULL");
        }
        const saffIds = user.get("saffIds") ?? [];
        if (saffIds.length >= limits.maxSaffs)
            throw new errors_1.AppError("SAFF_LIMIT");
        tx.update(saffRef, {
            memberIds: firestore_1.FieldValue.arrayUnion(uid),
            memberCount: memberIds.length + 1,
        });
        tx.set(callable_1.db.doc(`saffs/${saffId}/members/${uid}`), {
            displayName: user.get("displayName"),
            avatarColor: user.get("avatarColor"),
            whatsapp: contact.get("whatsapp") ?? "",
            role: "member",
            joinedAt: firestore_1.FieldValue.serverTimestamp(),
            presence: {},
            stats: {},
        });
        tx.update(callable_1.db.doc(`users/${uid}`), { saffIds: firestore_1.FieldValue.arrayUnion(saffId) });
        (0, membership_1.postSystemMessage)(tx, callable_1.db, saffId, "member_joined", uid, { uid });
    });
    return { saffId };
});
/** Leaves a saff. */
exports.leaveSaff = (0, callable_1.callable)("leaveSaff", zod_1.z.object({ saffId: zod_1.z.string().min(1) }), async (input, { uid }) => {
    await callable_1.db.runTransaction(async (tx) => {
        const plan = await (0, membership_1.planRemoval)(tx, callable_1.db, input.saffId);
        if (!plan.memberIds.includes(uid))
            throw new errors_1.AppError("NOT_PARTICIPANT");
        (0, membership_1.applyRemoval)(tx, callable_1.db, plan, input.saffId, uid, "left");
    });
    return { ok: true };
});
/** Removes a member (owner only). */
exports.removeMember = (0, callable_1.callable)("removeMember", zod_1.z.object({ saffId: zod_1.z.string().min(1), uid: zod_1.z.string().min(1) }), async (input, { uid }) => {
    await callable_1.db.runTransaction(async (tx) => {
        const plan = await (0, membership_1.planRemoval)(tx, callable_1.db, input.saffId);
        if (plan.ownerId !== uid || input.uid === uid)
            throw new errors_1.AppError("NOT_SAFF_OWNER");
        if (!plan.memberIds.includes(input.uid))
            throw new errors_1.AppError("NOT_PARTICIPANT");
        (0, membership_1.applyRemoval)(tx, callable_1.db, plan, input.saffId, input.uid, "removed");
    });
    return { ok: true };
});
/** Issues a new invite code (owner only). */
exports.regenerateInvite = (0, callable_1.callable)("regenerateInvite", zod_1.z.object({ saffId: zod_1.z.string().min(1) }), async (input, { uid }) => {
    const saffRef = callable_1.db.doc(`saffs/${input.saffId}`);
    const saff = await saffRef.get();
    if (!saff.exists)
        throw new errors_1.AppError("SAFF_NOT_FOUND");
    if (saff.get("ownerId") !== uid)
        throw new errors_1.AppError("NOT_SAFF_OWNER");
    const code = await freshCode();
    const batch = callable_1.db.batch();
    batch.delete(callable_1.db.doc(`inviteCodes/${saff.get("inviteCode")}`));
    batch.set(callable_1.db.doc(`inviteCodes/${code}`), {
        saffId: input.saffId,
        createdAt: firestore_1.FieldValue.serverTimestamp(),
    });
    batch.update(saffRef, { inviteCode: code });
    await batch.commit();
    return { inviteCode: code };
});
/** Renames a saff (owner only; resolves docs contradiction D-6). */
exports.renameSaff = (0, callable_1.callable)("renameSaff", zod_1.z.object({ saffId: zod_1.z.string().min(1), name: zod_1.z.string().trim().min(1).max(40) }), async (input, { uid }) => {
    const ref = callable_1.db.doc(`saffs/${input.saffId}`);
    const saff = await ref.get();
    if (!saff.exists)
        throw new errors_1.AppError("SAFF_NOT_FOUND");
    if (saff.get("ownerId") !== uid)
        throw new errors_1.AppError("NOT_SAFF_OWNER");
    await ref.update({ name: input.name });
    return { ok: true };
});
//# sourceMappingURL=saffs.js.map