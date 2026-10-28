"use strict";
/** Wall-clock <-> UTC conversion for IANA timezones, using Intl only. */
Object.defineProperty(exports, "__esModule", { value: true });
exports.localFields = localFields;
exports.offsetMs = offsetMs;
exports.zonedToUtc = zonedToUtc;
exports.isoWeekday = isoWeekday;
exports.dateKey = dateKey;
exports.isValidTimezone = isValidTimezone;
const fmtCache = new Map();
function formatter(tz) {
    let f = fmtCache.get(tz);
    if (!f) {
        f = new Intl.DateTimeFormat("en-US", {
            timeZone: tz,
            hourCycle: "h23",
            year: "numeric",
            month: "2-digit",
            day: "2-digit",
            hour: "2-digit",
            minute: "2-digit",
            second: "2-digit",
        });
        fmtCache.set(tz, f);
    }
    return f;
}
/** Local wall-clock fields of [ms] in [tz]. */
function localFields(ms, tz) {
    const parts = {};
    for (const p of formatter(tz).formatToParts(new Date(ms))) {
        if (p.type !== "literal")
            parts[p.type] = Number(p.value);
    }
    return {
        year: parts.year,
        month: parts.month,
        day: parts.day,
        hour: parts.hour,
        minute: parts.minute,
        second: parts.second,
    };
}
/** Offset of [tz] from UTC at [ms], in milliseconds. */
function offsetMs(ms, tz) {
    const f = localFields(ms, tz);
    const asUtc = Date.UTC(f.year, f.month - 1, f.day, f.hour, f.minute, f.second);
    return asUtc - Math.floor(ms / 1000) * 1000;
}
/** The UTC instant at which [tz] shows the given wall-clock time. */
function zonedToUtc(year, month, day, hour, minute, tz) {
    const naive = Date.UTC(year, month - 1, day, hour, minute, 0);
    let guess = naive - offsetMs(naive, tz);
    // A second pass settles instants near a DST change.
    guess = naive - offsetMs(guess, tz);
    return guess;
}
/** ISO weekday (1 = Monday .. 7 = Sunday) of a calendar date. */
function isoWeekday(year, month, day) {
    const d = new Date(Date.UTC(year, month - 1, day)).getUTCDay();
    return d === 0 ? 7 : d;
}
/** `yyyyMMdd` of a calendar date. */
function dateKey(year, month, day) {
    return `${year}${String(month).padStart(2, "0")}${String(day).padStart(2, "0")}`;
}
/** Whether [tz] is a valid IANA timezone. */
function isValidTimezone(tz) {
    try {
        new Intl.DateTimeFormat("en-US", { timeZone: tz });
        return true;
    }
    catch {
        return false;
    }
}
//# sourceMappingURL=time.js.map