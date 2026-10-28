import { FieldValue, Timestamp, type Firestore } from "firebase-admin/firestore";
import { z } from "zod";
import { callable, db } from "../../core/callable";
import { currentConstants } from "../../core/config";
import { AppError } from "../../core/errors";
import { findConflict, ringMoments, type AlarmSpec } from "../../domain/alarms/occurrences";
import { isValidTimezone } from "../../domain/alarms/time";
import { postSystemMessage } from "../saffs/membership";
import { alarmsOfUser, planAlarm } from "./planning";

const alarmPayload = z.object({
  name: z.string().trim().min(1).max(24),
  time: z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/),
  days: z.array(z.number().int().min(1).max(7)).min(1).max(7),
  timezone: z.string().refine(isValidTimezone),
  activeFrom: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
});
type AlarmPayload = z.infer<typeof alarmPayload>;

async function assertConflictFree(
  uid: string,
  spec: AlarmSpec,
  ignoreId?: string,
): Promise<void> {
  const c = currentConstants();
  const mine = await alarmsOfUser(db, uid);
  const clash = findConflict(spec, mine, Date.now(), c.alarmConflictWindowMs, 14, ignoreId);
  if (clash) throw new AppError("ALARM_CONFLICT", { with: clash.label });
}

function expiryFor(spec: AlarmSpec | undefined): Timestamp {
  const c = currentConstants();
  const now = Date.now();
  const first = spec ? ringMoments(spec, now, now + 8 * 86_400_000)[0] : undefined;
  const at = first ? first.ringAtMs - c.nightLockLeadMs : now + 86_400_000;
  return Timestamp.fromMillis(Math.max(at, now + 60_000));
}

/** Creates an alarm proposal (create / change / delete) and its chat card. */
export const createProposal = callable(
  "createProposal",
  z.object({
    saffId: z.string().min(1),
    type: z.enum(["alarmCreate", "alarmChange", "alarmDelete"]),
    payload: alarmPayload.partial().optional(),
    targetId: z.string().optional(),
    supersedes: z.string().optional(),
  }),
  async (input, { uid }) => {
    const c = currentConstants();
    const saffRef = db.doc(`saffs/${input.saffId}`);
    const saffSnap = await saffRef.get();
    if (!saffSnap.exists) throw new AppError("SAFF_NOT_FOUND");
    const memberIds = saffSnap.get("memberIds") as string[];
    if (!memberIds.includes(uid)) throw new AppError("NOT_PARTICIPANT");
    if (saffSnap.get("endedAt") || memberIds.length < 2) throw new AppError("SAFF_TOO_SMALL");
    const isPair = memberIds.length === 2;

    let spec: AlarmPayload | undefined;
    let target:
      | { id: string; participantIds: string[]; data: Record<string, unknown> }
      | undefined;

    if (input.type === "alarmCreate") {
      if (saffSnap.get("overLimit")) throw new AppError("SAFF_OVER_LIMIT");
      const parsed = alarmPayload.safeParse(input.payload);
      if (!parsed.success) throw new AppError("ALARM_INVALID");
      spec = parsed.data;
      const alarms = await saffRef.collection("alarms").get();
      const live = alarms.docs.filter((d) => d.get("status") !== "deleted").length;
      if (live >= c.maxAlarmsPerSaff) throw new AppError("ALARM_LIMIT");
    } else {
      if (!input.targetId) throw new AppError("ALARM_INVALID");
      const a = await saffRef.collection("alarms").doc(input.targetId).get();
      if (!a.exists || a.get("status") === "deleted") throw new AppError("NOT_FOUND");
      target = {
        id: a.id,
        participantIds: (a.get("participantIds") as string[]) ?? [],
        data: a.data() as Record<string, unknown>,
      };
      if (!isPair && !target.participantIds.includes(uid)) throw new AppError("NOT_PARTICIPANT");
      if (input.type === "alarmChange") {
        const merged = alarmPayload.safeParse({
          name: target.data.name,
          time: target.data.time,
          days: target.data.days,
          timezone: target.data.timezone,
          ...(input.payload ?? {}),
        });
        if (!merged.success) throw new AppError("ALARM_INVALID");
        spec = merged.data;
      }
    }
    if (spec) await assertConflictFree(uid, spec, target?.id);

    const proposalRef = saffRef.collection("proposals").doc();
    const messageRef = saffRef.collection("messages").doc();
    const result = await db.runTransaction(async (tx) => {
      // Supersede pending proposals on the same alarm, and the one being replaced.
      const pending = await tx.get(
        saffRef.collection("proposals").where("status", "==", "pending"),
      );
      for (const p of pending.docs) {
        const sameTarget = target && p.get("targetId") === target.id;
        if (sameTarget || p.id === input.supersedes) {
          tx.update(p.ref, { status: "superseded" });
          postSystemMessage(tx, db, input.saffId, "proposal_outcome", `${p.id}`, {
            proposalId: p.id,
            status: "superseded",
          });
        }
      }
      let alarmId = target?.id;
      let required: string[];
      if (input.type === "alarmCreate") {
        if (isPair) {
          required = memberIds;
        } else {
          required = [];
          const alarmRef = saffRef.collection("alarms").doc();
          alarmId = alarmRef.id;
          tx.set(alarmRef, {
            ...spec,
            status: "waiting",
            participantIds: [uid],
            createdBy: uid,
            version: 1,
            createdAt: FieldValue.serverTimestamp(),
          });
        }
      } else {
        required = isPair ? memberIds : target!.participantIds;
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
        createdAt: FieldValue.serverTimestamp(),
      });
      tx.set(proposalRef.collection("votes").doc(uid), {
        vote: "accept",
        at: FieldValue.serverTimestamp(),
      });
      tx.set(messageRef, {
        type: "proposal",
        authorId: uid,
        systemPayload: { proposalId: proposalRef.id, proposalType: input.type },
        createdAt: FieldValue.serverTimestamp(),
        seenBy: {},
      });
      return { proposalId: proposalRef.id, alarmId };
    });
    await tally(db, input.saffId, result.proposalId);
    return result;
  },
);

/** Records an accept or decline on a proposal. */
export const voteProposal = callable(
  "voteProposal",
  z.object({
    saffId: z.string().min(1),
    proposalId: z.string().min(1),
    vote: z.enum(["accept", "decline"]),
  }),
  async (input, { uid }) => {
    const saffRef = db.doc(`saffs/${input.saffId}`);
    const propRef = saffRef.collection("proposals").doc(input.proposalId);
    const [saff, prop] = await Promise.all([saffRef.get(), propRef.get()]);
    if (!saff.exists || !prop.exists) throw new AppError("NOT_FOUND");
    const memberIds = saff.get("memberIds") as string[];
    if (!memberIds.includes(uid)) throw new AppError("NOT_PARTICIPANT");
    const type = prop.get("type") as string;
    const status = prop.get("status") as string;
    const isPair = memberIds.length === 2;
    const joinsAfterStart = !isPair && type === "alarmCreate" && status === "accepted";
    if (status === "expired") throw new AppError("PROPOSAL_EXPIRED");
    if (status === "superseded") throw new AppError("PROPOSAL_SUPERSEDED");
    if (status !== "pending" && !joinsAfterStart) throw new AppError("PROPOSAL_NOT_PENDING");
    const required = prop.get("requiredIds") as string[];
    if (required.length > 0 && !required.includes(uid)) throw new AppError("NOT_PARTICIPANT");

    if (input.vote === "accept" && type !== "alarmDelete") {
      const payload = prop.get("payload") as AlarmPayload;
      await assertConflictFree(uid, payload, prop.get("targetId") as string | undefined);
    }
    const batch = db.batch();
    batch.set(propRef.collection("votes").doc(uid), {
      vote: input.vote,
      at: FieldValue.serverTimestamp(),
    });
    if (input.vote === "accept") {
      batch.update(propRef, { acceptedIds: FieldValue.arrayUnion(uid) });
      if (!isPair && type === "alarmCreate") {
        batch.update(saffRef.collection("alarms").doc(prop.get("targetId") as string), {
          participantIds: FieldValue.arrayUnion(uid),
        });
      }
    }
    await batch.commit();
    await tally(db, input.saffId, input.proposalId);
    return { ok: true };
  },
);

/**
 * Evaluates a proposal against its votes and applies the outcome. Idempotent:
 * a resolved proposal is left alone.
 */
export async function tally(db: Firestore, saffId: string, proposalId: string): Promise<void> {
  const c = currentConstants();
  const saffRef = db.doc(`saffs/${saffId}`);
  const propRef = saffRef.collection("proposals").doc(proposalId);
  const replan = await db.runTransaction(async (tx) => {
    const [saff, prop, votes] = await Promise.all([
      tx.get(saffRef),
      tx.get(propRef),
      tx.get(propRef.collection("votes")),
    ]);
    const status = prop.get("status") as string;
    const type = prop.get("type") as string;
    const memberIds = saff.get("memberIds") as string[];
    const isPair = memberIds.length === 2;
    const accepted = new Set((prop.get("acceptedIds") as string[]) ?? []);
    const declined = votes.docs.filter((v) => v.get("vote") === "decline").map((v) => v.id);
    const required = prop.get("requiredIds") as string[];
    const targetId = prop.get("targetId") as string | undefined;
    const payload = prop.get("payload") as AlarmPayload;
    const alarmRef = targetId ? saffRef.collection("alarms").doc(targetId) : undefined;
    const alarm = alarmRef ? await tx.get(alarmRef) : undefined;
    if (status !== "pending") return undefined;

    const outcome = (s: string) =>
      postSystemMessage(tx, db, saffId, "proposal_outcome", proposalId, {
        proposalId,
        status: s,
      });

    if (type === "alarmCreate" && !isPair) {
      // Group alarm: opt-in; starts at MIN_GROUP_ALARM_PARTICIPANTS.
      const participants = (alarm?.get("participantIds") as string[]) ?? [];
      if (alarm?.get("status") === "waiting" && participants.length >= c.minGroupAlarmParticipants) {
        tx.update(alarmRef!, { status: "active" });
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
    if (!required.every((r) => accepted.has(r))) return undefined;

    // Everyone required has accepted.
    if (type === "alarmCreate") {
      const ref = saffRef.collection("alarms").doc();
      tx.set(ref, {
        ...payload,
        status: "active",
        participantIds: required,
        createdBy: prop.get("proposerId"),
        version: 1,
        createdAt: FieldValue.serverTimestamp(),
      });
      tx.update(propRef, { status: "accepted", targetId: ref.id });
      outcome("accepted");
      return ref.id;
    }
    if (type === "alarmChange" && alarmRef) {
      tx.update(alarmRef, { ...payload, version: FieldValue.increment(1) });
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
  if (replan) await planAlarm(db, saffId, replan);
}

/** Joins a group alarm from its details (opt-in). */
export const joinAlarm = callable(
  "joinAlarm",
  z.object({ saffId: z.string().min(1), alarmId: z.string().min(1) }),
  async (input, { uid }) => {
    const saffRef = db.doc(`saffs/${input.saffId}`);
    const [saff, alarm] = await Promise.all([
      saffRef.get(),
      saffRef.collection("alarms").doc(input.alarmId).get(),
    ]);
    if (!saff.exists || !alarm.exists) throw new AppError("NOT_FOUND");
    if (!(saff.get("memberIds") as string[]).includes(uid)) throw new AppError("NOT_PARTICIPANT");
    if (alarm.get("status") === "deleted") throw new AppError("NOT_FOUND");
    await assertConflictFree(uid, alarm.data() as unknown as AlarmSpec, alarm.id);
    const c = currentConstants();
    const participants = new Set((alarm.get("participantIds") as string[]) ?? []);
    participants.add(uid);
    await alarm.ref.update({
      participantIds: [...participants],
      ...(alarm.get("status") === "waiting" && participants.size >= c.minGroupAlarmParticipants
        ? { status: "active" }
        : {}),
    });
    await planAlarm(db, input.saffId, input.alarmId);
    return { ok: true };
  },
);

/** Leaves a group alarm (effective from the next lock). */
export const leaveAlarm = callable(
  "leaveAlarm",
  z.object({ saffId: z.string().min(1), alarmId: z.string().min(1) }),
  async (input, { uid }) => {
    const saffRef = db.doc(`saffs/${input.saffId}`);
    const [saff, alarm] = await Promise.all([
      saffRef.get(),
      saffRef.collection("alarms").doc(input.alarmId).get(),
    ]);
    if (!saff.exists || !alarm.exists) throw new AppError("NOT_FOUND");
    if ((saff.get("memberIds") as string[]).length === 2) throw new AppError("ALARM_INVALID");
    const participants = ((alarm.get("participantIds") as string[]) ?? []).filter((p) => p !== uid);
    if (participants.length === (alarm.get("participantIds") as string[]).length) {
      throw new AppError("NOT_PARTICIPANT");
    }
    await alarm.ref.update({
      participantIds: participants,
      ...(participants.length === 0 ? { status: "deleted" } : {}),
    });
    await planAlarm(db, input.saffId, input.alarmId);
    return { ok: true };
  },
);

/** Expires pending proposals whose time has passed (called by the sweeper). */
export async function expireProposals(db: Firestore, nowMs: number): Promise<number> {
  const snap = await db
    .collectionGroup("proposals")
    .where("status", "==", "pending")
    .where("expiresAt", "<=", Timestamp.fromMillis(nowMs))
    .get();
  for (const p of snap.docs) {
    const saffId = p.ref.parent.parent!.id;
    const batch = db.batch();
    batch.update(p.ref, { status: "expired" });
    batch.set(db.doc(`saffs/${saffId}/messages/sys_proposal_outcome_${p.id}`), {
      type: "proposal_outcome",
      authorId: "system",
      systemPayload: { proposalId: p.id, status: "expired" },
      createdAt: FieldValue.serverTimestamp(),
      seenBy: {},
    });
    const targetId = p.get("targetId") as string | undefined;
    if (p.get("type") === "alarmCreate" && targetId) {
      const alarm = await db.doc(`saffs/${saffId}/alarms/${targetId}`).get();
      if (alarm.get("status") === "waiting") batch.update(alarm.ref, { status: "deleted" });
    }
    await batch.commit();
  }
  return snap.size;
}

/** Skips one occurrence for the caller (docs/PRODUCT.md section 4.3). */
export const skipOccurrence = callable(
  "skipOccurrence",
  z.object({ saffId: z.string().min(1), occurrenceId: z.string().min(1) }),
  async (input, { uid }) => {
    const c = currentConstants();
    const occRef = db.doc(`saffs/${input.saffId}/occurrences/${input.occurrenceId}`);
    await db.runTransaction(async (tx) => {
      const occ = await tx.get(occRef);
      if (!occ.exists) throw new AppError("NOT_FOUND");
      const participants = occ.get("participantIds") as string[];
      if (!participants.includes(uid)) throw new AppError("NOT_PARTICIPANT");
      const ringAt = (occ.get("ringAt") as Timestamp).toMillis();
      if (occ.get("status") !== "planned" || ringAt - Date.now() < c.skipMinNoticeMs) {
        throw new AppError("SKIP_TOO_LATE");
      }
      const monthKey = (occ.get("date") as string).slice(0, 6);
      const memberRef = db.doc(`saffs/${input.saffId}/members/${uid}`);
      const member = await tx.get(memberRef);
      const used = (member.get(`stats.skips.${monthKey}`) as number | undefined) ?? 0;
      if (used >= c.skipsPerMonth) throw new AppError("SKIP_LIMIT");
      const skipped = new Set((occ.get("skippedIds") as string[]) ?? []);
      skipped.add(uid);
      const required = participants.filter((p) => !skipped.has(p));
      tx.update(occRef, {
        skippedIds: [...skipped],
        requiredIds: required,
        ...(required.length === 0 ? { status: "cancelled" } : {}),
      });
      tx.set(occRef.collection("skips").doc(uid), { at: FieldValue.serverTimestamp() });
      tx.update(memberRef, { [`stats.skips.${monthKey}`]: used + 1 });
      postSystemMessage(tx, db, input.saffId, "skip", `${input.occurrenceId}_${uid}`, {
        uid,
        occurrenceId: input.occurrenceId,
        date: occ.get("date"),
      });
    });
    return { ok: true };
  },
);
