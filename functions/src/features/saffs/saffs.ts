import { FieldValue } from "firebase-admin/firestore";
import { z } from "zod";
import { callable, db } from "../../core/callable";
import { currentConstants } from "../../core/config";
import { AppError } from "../../core/errors";
import { isInviteCode, newInviteCode } from "../../core/ids";
import { limitsFor } from "../users/limits";
import { applyRemoval, planRemoval, postSystemMessage } from "./membership";

const PHONE = /^\+[1-9]\d{7,14}$/;

async function freshCode(): Promise<string> {
  for (let i = 0; i < 10; i++) {
    const code = newInviteCode();
    if (!(await db.doc(`inviteCodes/${code}`).get()).exists) return code;
  }
  throw new AppError("SERVER_INTERNAL");
}

/** Creates or updates the caller's profile and contact number. */
export const setProfile = callable(
  "setProfile",
  z.object({
    displayName: z.string().trim().min(1).max(40),
    whatsapp: z.string().regex(PHONE),
    avatarColor: z.string().max(20).optional(),
  }),
  async (input, { uid }) => {
    const userRef = db.doc(`users/${uid}`);
    const existing = await userRef.get();
    const saffIds = (existing.get("saffIds") as string[] | undefined) ?? [];
    const color =
      input.avatarColor ??
      (existing.get("avatarColor") as string | undefined) ??
      String(Math.floor(Math.random() * 5));
    const batch = db.batch();
    batch.set(
      userRef,
      {
        displayName: input.displayName,
        avatarColor: color,
        ...(existing.exists
          ? {}
          : { saffIds: [], createdAt: FieldValue.serverTimestamp(), settings: {} }),
      },
      { merge: true },
    );
    batch.set(db.doc(`users/${uid}/private/contact`), { whatsapp: input.whatsapp });
    for (const id of saffIds) {
      batch.set(
        db.doc(`saffs/${id}/members/${uid}`),
        { displayName: input.displayName, avatarColor: color, whatsapp: input.whatsapp },
        { merge: true },
      );
    }
    await batch.commit();
    return { ok: true };
  },
);

/** Stores the caller's FCM token for this installation. */
export const registerDevice = callable(
  "registerDevice",
  z.object({ installationId: z.string().min(1).max(100), fcmToken: z.string().min(1) }),
  async (input, { uid }) => {
    await db.doc(`users/${uid}/devices/${input.installationId}`).set({
      fcmToken: input.fcmToken,
      updatedAt: FieldValue.serverTimestamp(),
    });
    return { ok: true };
  },
);

/** Creates a saff with the caller as owner. */
export const createSaff = callable(
  "createSaff",
  z.object({ name: z.string().trim().min(1).max(40).optional() }),
  async (input, { uid }) => {
    const c = currentConstants();
    const [user, contact, limits] = await Promise.all([
      db.doc(`users/${uid}`).get(),
      db.doc(`users/${uid}/private/contact`).get(),
      limitsFor(db, uid),
    ]);
    if (!user.exists) throw new AppError("PROFILE_NAME_INVALID");
    const saffIds = (user.get("saffIds") as string[]) ?? [];
    if (saffIds.length >= limits.maxSaffs) throw new AppError("SAFF_LIMIT");
    const name = input.name ?? `${user.get("displayName")}'s saff`;
    const code = await freshCode();
    const saffRef = db.collection("saffs").doc();
    const batch = db.batch();
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
      createdAt: FieldValue.serverTimestamp(),
    });
    batch.set(saffRef.collection("members").doc(uid), {
      displayName: user.get("displayName"),
      avatarColor: user.get("avatarColor"),
      whatsapp: contact.get("whatsapp") ?? "",
      role: "owner",
      joinedAt: FieldValue.serverTimestamp(),
      presence: {},
      stats: {},
    });
    batch.set(db.doc(`inviteCodes/${code}`), {
      saffId: saffRef.id,
      createdAt: FieldValue.serverTimestamp(),
    });
    batch.update(db.doc(`users/${uid}`), { saffIds: FieldValue.arrayUnion(saffRef.id) });
    await batch.commit();
    return { saffId: saffRef.id, inviteCode: code };
  },
);

async function saffForCode(code: string) {
  if (!isInviteCode(code)) throw new AppError("INVITE_INVALID");
  const invite = await db.doc(`inviteCodes/${code}`).get();
  if (!invite.exists) throw new AppError("INVITE_INVALID");
  const saffId = invite.get("saffId") as string;
  const saff = await db.doc(`saffs/${saffId}`).get();
  if (!saff.exists || saff.get("endedAt")) throw new AppError("INVITE_INVALID");
  return { saffId, saff };
}

/** What the "Join X's saff?" confirmation screen shows. */
export const previewInvite = callable(
  "previewInvite",
  z.object({ code: z.string().trim().toUpperCase() }),
  async (input) => {
    const { saffId, saff } = await saffForCode(input.code);
    const members = await db.collection(`saffs/${saffId}/members`).get();
    const owner = members.docs.find((d) => d.id === saff.get("ownerId"));
    return {
      saffId,
      name: saff.get("name") as string,
      ownerName: (owner?.get("displayName") as string) ?? "",
      memberCount: saff.get("memberCount") as number,
      memberLimit: saff.get("memberLimit") as number,
      members: members.docs.map((d) => ({
        name: d.get("displayName") as string,
        avatarColor: d.get("avatarColor") as string,
      })),
    };
  },
);

/** Joins a saff by invite code. */
export const joinSaff = callable(
  "joinSaff",
  z.object({ code: z.string().trim().toUpperCase() }),
  async (input, { uid }) => {
    const { saffId } = await saffForCode(input.code);
    const limits = await limitsFor(db, uid);
    await db.runTransaction(async (tx) => {
      const saffRef = db.doc(`saffs/${saffId}`);
      const [saff, user, contact] = await Promise.all([
        tx.get(saffRef),
        tx.get(db.doc(`users/${uid}`)),
        tx.get(db.doc(`users/${uid}/private/contact`)),
      ]);
      if (!user.exists) throw new AppError("PROFILE_NAME_INVALID");
      const memberIds = saff.get("memberIds") as string[];
      if (memberIds.includes(uid)) throw new AppError("ALREADY_MEMBER");
      if (saff.get("overLimit") || (saff.get("memberCount") as number) >= (saff.get("memberLimit") as number)) {
        throw new AppError("SAFF_FULL");
      }
      const saffIds = (user.get("saffIds") as string[]) ?? [];
      if (saffIds.length >= limits.maxSaffs) throw new AppError("SAFF_LIMIT");
      tx.update(saffRef, {
        memberIds: FieldValue.arrayUnion(uid),
        memberCount: memberIds.length + 1,
      });
      tx.set(db.doc(`saffs/${saffId}/members/${uid}`), {
        displayName: user.get("displayName"),
        avatarColor: user.get("avatarColor"),
        whatsapp: contact.get("whatsapp") ?? "",
        role: "member",
        joinedAt: FieldValue.serverTimestamp(),
        presence: {},
        stats: {},
      });
      tx.update(db.doc(`users/${uid}`), { saffIds: FieldValue.arrayUnion(saffId) });
      postSystemMessage(tx, db, saffId, "member_joined", uid, { uid });
    });
    return { saffId };
  },
);

/** Leaves a saff. */
export const leaveSaff = callable(
  "leaveSaff",
  z.object({ saffId: z.string().min(1) }),
  async (input, { uid }) => {
    await db.runTransaction(async (tx) => {
      const plan = await planRemoval(tx, db, input.saffId);
      if (!plan.memberIds.includes(uid)) throw new AppError("NOT_PARTICIPANT");
      applyRemoval(tx, db, plan, input.saffId, uid, "left");
    });
    return { ok: true };
  },
);

/** Removes a member (owner only). */
export const removeMember = callable(
  "removeMember",
  z.object({ saffId: z.string().min(1), uid: z.string().min(1) }),
  async (input, { uid }) => {
    await db.runTransaction(async (tx) => {
      const plan = await planRemoval(tx, db, input.saffId);
      if (plan.ownerId !== uid || input.uid === uid) throw new AppError("NOT_SAFF_OWNER");
      if (!plan.memberIds.includes(input.uid)) throw new AppError("NOT_PARTICIPANT");
      applyRemoval(tx, db, plan, input.saffId, input.uid, "removed");
    });
    return { ok: true };
  },
);

/** Issues a new invite code (owner only). */
export const regenerateInvite = callable(
  "regenerateInvite",
  z.object({ saffId: z.string().min(1) }),
  async (input, { uid }) => {
    const saffRef = db.doc(`saffs/${input.saffId}`);
    const saff = await saffRef.get();
    if (!saff.exists) throw new AppError("SAFF_NOT_FOUND");
    if (saff.get("ownerId") !== uid) throw new AppError("NOT_SAFF_OWNER");
    const code = await freshCode();
    const batch = db.batch();
    batch.delete(db.doc(`inviteCodes/${saff.get("inviteCode")}`));
    batch.set(db.doc(`inviteCodes/${code}`), {
      saffId: input.saffId,
      createdAt: FieldValue.serverTimestamp(),
    });
    batch.update(saffRef, { inviteCode: code });
    await batch.commit();
    return { inviteCode: code };
  },
);

/** Renames a saff (owner only; resolves docs contradiction D-6). */
export const renameSaff = callable(
  "renameSaff",
  z.object({ saffId: z.string().min(1), name: z.string().trim().min(1).max(40) }),
  async (input, { uid }) => {
    const ref = db.doc(`saffs/${input.saffId}`);
    const saff = await ref.get();
    if (!saff.exists) throw new AppError("SAFF_NOT_FOUND");
    if (saff.get("ownerId") !== uid) throw new AppError("NOT_SAFF_OWNER");
    await ref.update({ name: input.name });
    return { ok: true };
  },
);
