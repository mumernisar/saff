import {
  FieldValue,
  Timestamp,
  type DocumentReference,
  type Firestore,
  type Transaction,
} from "firebase-admin/firestore";
import { AppError } from "../../core/errors";

/** Writes a system chat message with an idempotent id. */
export function postSystemMessage(
  tx: Transaction,
  db: Firestore,
  saffId: string,
  type: string,
  refId: string,
  payload: Record<string, unknown>,
): void {
  const ref = db.doc(`saffs/${saffId}/messages/sys_${type}_${refId}`);
  tx.set(ref, {
    type,
    authorId: "system",
    systemPayload: payload,
    createdAt: FieldValue.serverTimestamp(),
    seenBy: {},
  });
}

/**
 * Removes [uid] from [saffId] inside [tx]: member doc, memberIds, the user's
 * saffIds, alarm participation, ownership transfer, and ending a saff that
 * would be left with one member. Reads must all happen before writes, so the
 * caller passes the already-read saff and members.
 */
export interface RemovalPlan {
  readonly saffRef: DocumentReference;
  readonly memberIds: string[];
  readonly ownerId: string;
  readonly memberJoined: Map<string, Timestamp>;
  readonly alarmDocs: { ref: DocumentReference; participantIds: string[] }[];
  readonly occurrenceDocs: { ref: DocumentReference; participantIds: string[]; skippedIds: string[]; status: string }[];
}

/** Reads what [applyRemoval] needs. */
export async function planRemoval(
  tx: Transaction,
  db: Firestore,
  saffId: string,
): Promise<RemovalPlan> {
  const saffRef = db.doc(`saffs/${saffId}`);
  const [saff, members, alarms, occs] = await Promise.all([
    tx.get(saffRef),
    tx.get(db.collection(`saffs/${saffId}/members`)),
    tx.get(db.collection(`saffs/${saffId}/alarms`)),
    tx.get(
      db
        .collection(`saffs/${saffId}/occurrences`)
        .where("status", "in", ["planned", "locked"]),
    ),
  ]);
  if (!saff.exists) throw new AppError("SAFF_NOT_FOUND");
  return {
    saffRef,
    memberIds: saff.get("memberIds") as string[],
    ownerId: saff.get("ownerId") as string,
    memberJoined: new Map(
      members.docs.map((d) => [d.id, d.get("joinedAt") as Timestamp]),
    ),
    alarmDocs: alarms.docs.map((d) => ({
      ref: d.ref,
      participantIds: (d.get("participantIds") as string[]) ?? [],
    })),
    occurrenceDocs: occs.docs.map((d) => ({
      ref: d.ref,
      participantIds: (d.get("participantIds") as string[]) ?? [],
      skippedIds: (d.get("skippedIds") as string[]) ?? [],
      status: d.get("status") as string,
    })),
  };
}

/** Applies the removal of [uid] using a [RemovalPlan]. */
export function applyRemoval(
  tx: Transaction,
  db: Firestore,
  plan: RemovalPlan,
  saffId: string,
  uid: string,
  kind: "left" | "removed",
): void {
  const remaining = plan.memberIds.filter((m) => m !== uid);
  tx.delete(db.doc(`saffs/${saffId}/members/${uid}`));
  tx.update(db.doc(`users/${uid}`), { saffIds: FieldValue.arrayRemove(saffId) });
  const update: Record<string, unknown> = {
    memberIds: remaining,
    memberCount: remaining.length,
  };
  if (plan.ownerId === uid && remaining.length > 0) {
    const next = [...remaining].sort(
      (a, b) =>
        (plan.memberJoined.get(a)?.toMillis() ?? 0) -
        (plan.memberJoined.get(b)?.toMillis() ?? 0),
    )[0]!;
    update.ownerId = next;
    tx.update(db.doc(`saffs/${saffId}/members/${next}`), { role: "owner" });
  }
  const ends = remaining.length <= 1;
  if (ends) update.endedAt = FieldValue.serverTimestamp();
  tx.update(plan.saffRef, update);

  for (const a of plan.alarmDocs) {
    if (!a.participantIds.includes(uid) && !ends) continue;
    const participants = a.participantIds.filter((p) => p !== uid);
    tx.update(a.ref, {
      participantIds: participants,
      ...(ends || participants.length === 0 ? { status: "deleted" } : {}),
    });
  }
  for (const o of plan.occurrenceDocs) {
    if (ends) {
      tx.update(o.ref, { status: "cancelled" });
    } else if (o.participantIds.includes(uid)) {
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
