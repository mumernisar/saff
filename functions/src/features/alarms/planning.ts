import { FieldValue, Timestamp, type Firestore } from "firebase-admin/firestore";
import { currentConstants } from "../../core/config";
import { ringMoments, type AlarmSpec, type ConflictAlarm } from "../../domain/alarms/occurrences";

/** Days of occurrences kept planned ahead (docs say 48 h; see stage notes). */
export const PLAN_HORIZON_MS = 7 * 86_400_000;

/**
 * Ensures occurrence docs for [alarmId] cover the next week: creates missing
 * ones, refreshes planned ones when the alarm changed, cancels stale ones.
 * Idempotent; safe to call after any alarm change.
 */
export async function planAlarm(
  db: Firestore,
  saffId: string,
  alarmId: string,
  nowMs = Date.now(),
): Promise<void> {
  const c = currentConstants();
  const alarmRef = db.doc(`saffs/${saffId}/alarms/${alarmId}`);
  const alarm = await alarmRef.get();
  const col = db.collection(`saffs/${saffId}/occurrences`);
  const existing = await col.where("alarmId", "==", alarmId).get();
  const batch = db.batch();

  const live = alarm.exists && alarm.get("status") === "active";
  const wanted = new Map<string, number>();
  if (live) {
    const spec = alarm.data() as unknown as AlarmSpec;
    for (const m of ringMoments(spec, nowMs - c.revealDeadlineMs, nowMs + PLAN_HORIZON_MS)) {
      wanted.set(`${alarmId}_${m.date}`, m.ringAtMs);
    }
  }
  const participants = (alarm.get("participantIds") as string[] | undefined) ?? [];
  const version = (alarm.get("version") as number | undefined) ?? 1;

  for (const doc of existing.docs) {
    const status = doc.get("status") as string;
    if (status !== "planned") continue;
    const ringAt = wanted.get(doc.id);
    if (ringAt === undefined) {
      batch.update(doc.ref, { status: "cancelled" });
    }
  }
  for (const [id, ringAt] of wanted) {
    const ref = col.doc(id);
    const snap = existing.docs.find((d) => d.id === id);
    const skipped = (snap?.get("skippedIds") as string[] | undefined) ?? [];
    const data = {
      alarmId,
      alarmVersion: version,
      date: id.split("_")[1]!,
      ringAt: Timestamp.fromMillis(ringAt),
      lockAt: Timestamp.fromMillis(ringAt - c.nightLockLeadMs),
      deadlineAt: Timestamp.fromMillis(ringAt + c.revealDeadlineMs),
      alarmName: alarm.get("name") as string,
      participantIds: participants,
      skippedIds: skipped,
      requiredIds: participants.filter((p) => !skipped.includes(p)),
    };
    if (!snap) {
      batch.set(ref, { ...data, status: "planned", createdAt: FieldValue.serverTimestamp() });
    } else if (snap.get("status") === "planned") {
      batch.update(ref, data);
    }
  }
  await batch.commit();
}

/** All alarms [uid] participates in, across their saffs, for conflict checks. */
export async function alarmsOfUser(db: Firestore, uid: string): Promise<ConflictAlarm[]> {
  const user = await db.doc(`users/${uid}`).get();
  const saffIds = (user.get("saffIds") as string[] | undefined) ?? [];
  const out: ConflictAlarm[] = [];
  for (const saffId of saffIds) {
    const [saff, alarms] = await Promise.all([
      db.doc(`saffs/${saffId}`).get(),
      db
        .collection(`saffs/${saffId}/alarms`)
        .where("participantIds", "array-contains", uid)
        .get(),
    ]);
    for (const a of alarms.docs) {
      const status = a.get("status") as string;
      if (status !== "active" && status !== "waiting") continue;
      out.push({
        id: a.id,
        label: `${a.get("name")} in ${saff.get("name")}`,
        time: a.get("time") as string,
        days: a.get("days") as number[],
        timezone: a.get("timezone") as string,
        activeFrom: a.get("activeFrom") as string | undefined,
      });
    }
  }
  return out;
}
