"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.freeLimits = freeLimits;
exports.computeEntitlement = computeEntitlement;
/** Limits of the free plan. */
function freeLimits(c) {
    return {
        maxOwnedSaffSize: c.maxSaffSizeFree,
        maxSaffs: c.maxSaffsPerUserFree,
        statsHistoryDays: c.statsHistoryFreeDays,
        imports: false,
        cosmetics: false,
    };
}
/** Computes the entitlement for [sub] at [nowMs] (docs/BACKEND.md section 8). */
function computeEntitlement(sub, nowMs, c) {
    const free = { plan: "free", status: "none", limits: freeLimits(c) };
    if (!sub || sub.state === "REVOKED")
        return free;
    const plus = {
        maxOwnedSaffSize: c.maxSaffSizePlus,
        maxSaffs: c.maxSaffsPerUserPlus,
        statsHistoryDays: 36500,
        imports: true,
        cosmetics: true,
    };
    if (sub.state === "ACTIVE" && sub.expiresAtMs > nowMs)
        return { plan: "plus", status: "active", limits: plus };
    if (sub.state === "IN_GRACE_PERIOD")
        return { plan: "plus", status: "grace", graceUntilMs: sub.expiresAtMs, limits: plus };
    const graceUntil = sub.expiresAtMs + c.plusGraceDays * 86_400_000;
    if (nowMs < graceUntil)
        return { plan: "plus", status: "grace", graceUntilMs: graceUntil, limits: plus };
    return { plan: "free", status: "expired", limits: freeLimits(c) };
}
//# sourceMappingURL=entitlement.js.map