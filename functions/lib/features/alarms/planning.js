"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.PLAN_HORIZON_MS = void 0;
exports.planAlarm = planAlarm;
exports.alarmsOfUser = alarmsOfUser;
const firestore_1 = require("firebase-admin/firestore");
const config_1 = require("../../core/config");
const occurrences_1 = require("../../domain/alarms/occurrences");
/** Days of occurrences kept planned ahead (docs say 48 h; see stage notes). */
exports.PLAN_HORIZON_MS = 7 * 86_400_000;
/**
 * Ensures occurrence docs for [alarmId] cover the next week: creates missing
 * ones, refreshes planned ones when the alarm changed, cancels stale ones.
 * Idempotent; safe to call after any alarm change.
 */
async function planAlarm(db, saffId, alarmId, nowMs = Date.now()) {
    const c = (0, config_1.currentConstants)();
    const alarmRef = db.doc(`saffs/${saffId}/alarms/${alarmId}`);
    const alarm = await alarmRef.get();
    const col = db.collection(`saffs/${saffId}/occurrences`);
    const existing = await col.where("alarmId", "==", alarmId).get();
    const batch = db.batch();
    const live = alarm.exists && alarm.get("status") === "active";
    const wanted = new Map();
    if (live) {
        const spec = alarm.data();
        for (const m of (0, occurrences_1.ringMoments)(spec, nowMs - c.revealDeadlineMs, nowMs + exports.PLAN_HORIZON_MS)) {
            wanted.set(`${alarmId}_${m.date}`, m.ringAtMs);
        }
    }
    const participants = alarm.get("participantIds") ?? [];
    const version = alarm.get("version") ?? 1;
    for (const doc of existing.docs) {
        const status = doc.get("status");
        if (status !== "planned")
            continue;
        const ringAt = wanted.get(doc.id);
        if (ringAt === undefined) {
            batch.update(doc.ref, { status: "cancelled" });
        }
    }
    for (const [id, ringAt] of wanted) {
        const ref = col.doc(id);
        const snap = existing.docs.find((d) => d.id === id);
        const skipped = snap?.get("skippedIds") ?? [];
        const data = {
            alarmId,
            alarmVersion: version,
            date: id.split("_")[1],
            ringAt: firestore_1.Timestamp.fromMillis(ringAt),
            lockAt: firestore_1.Timestamp.fromMillis(ringAt - c.nightLockLeadMs),
            deadlineAt: firestore_1.Timestamp.fromMillis(ringAt + c.revealDeadlineMs),
            alarmName: alarm.get("name"),
            participantIds: participants,
            skippedIds: skipped,
            requiredIds: participants.filter((p) => !skipped.includes(p)),
        };
        if (!snap) {
            batch.set(ref, { ...data, status: "planned", createdAt: firestore_1.FieldValue.serverTimestamp() });
        }
        else if (snap.get("status") === "planned") {
            batch.update(ref, data);
        }
    }
    await batch.commit();
}
/** All alarms [uid] participates in, across their saffs, for conflict checks. */
async function alarmsOfUser(db, uid) {
    const user = await db.doc(`users/${uid}`).get();
    const saffIds = user.get("saffIds") ?? [];
    const out = [];
    for (const saffId of saffIds) {
        const [saff, alarms] = await Promise.all([
            db.doc(`saffs/${saffId}`).get(),
            db
                .collection(`saffs/${saffId}/alarms`)
                .where("participantIds", "array-contains", uid)
                .get(),
        ]);
        for (const a of alarms.docs) {
            const status = a.get("status");
            if (status !== "active" && status !== "waiting")
                continue;
            out.push({
                id: a.id,
                label: `${a.get("name")} in ${saff.get("name")}`,
                time: a.get("time"),
                days: a.get("days"),
                timezone: a.get("timezone"),
                activeFrom: a.get("activeFrom"),
            });
        }
    }
    return out;
}
//# sourceMappingURL=planning.js.map