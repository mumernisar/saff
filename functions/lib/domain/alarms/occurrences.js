"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ringMoments = ringMoments;
exports.findConflict = findConflict;
const time_1 = require("./time");
/**
 * Ring moments of [alarm] whose instant lies in [fromMs, toMs], in order.
 * Deterministic: the same inputs give the same list (DST handled by Intl).
 */
function ringMoments(alarm, fromMs, toMs) {
    const [hh, mm] = alarm.time.split(":").map(Number);
    const out = [];
    const start = (0, time_1.localFields)(fromMs - 36 * 3600_000, alarm.timezone);
    const activeFromMs = alarm.activeFrom
        ? Date.parse(`${alarm.activeFrom}T00:00:00Z`)
        : Number.NEGATIVE_INFINITY;
    const days = Math.ceil((toMs - fromMs) / 86_400_000) + 3;
    for (let i = 0; i < days; i++) {
        const d = new Date(Date.UTC(start.year, start.month - 1, start.day + i));
        const y = d.getUTCFullYear();
        const m = d.getUTCMonth() + 1;
        const day = d.getUTCDate();
        if (!alarm.days.includes((0, time_1.isoWeekday)(y, m, day)))
            continue;
        if (d.getTime() < activeFromMs)
            continue;
        const at = (0, time_1.zonedToUtc)(y, m, day, hh, mm, alarm.timezone);
        if (at < fromMs || at > toMs)
            continue;
        out.push({ date: (0, time_1.dateKey)(y, m, day), ringAtMs: at });
    }
    return out.sort((a, b) => a.ringAtMs - b.ringAtMs);
}
/**
 * The first existing alarm whose ring moment is closer than [windowMs] to a
 * ring moment of [candidate], over the next [horizonDays] days; null if none.
 * [ignoreId] skips the alarm being changed.
 */
function findConflict(candidate, existing, nowMs, windowMs, horizonDays = 14, ignoreId) {
    const to = nowMs + horizonDays * 86_400_000;
    const mine = ringMoments(candidate, nowMs, to);
    for (const other of existing) {
        if (other.id === ignoreId)
            continue;
        const theirs = ringMoments(other, nowMs, to);
        for (const a of mine) {
            for (const b of theirs) {
                if (Math.abs(a.ringAtMs - b.ringAtMs) < windowMs)
                    return other;
            }
        }
    }
    return null;
}
//# sourceMappingURL=occurrences.js.map