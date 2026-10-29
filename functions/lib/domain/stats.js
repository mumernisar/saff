"use strict";
/** Pure stats helpers (docs/PRODUCT.md section 11). */
Object.defineProperty(exports, "__esModule", { value: true });
exports.STREAK_BADGES = void 0;
exports.dayStatus = dayStatus;
exports.headToHead = headToHead;
exports.newBadges = newBadges;
/** Calendar colour of a day for the saff (flows.md frames 8d-8f). */
function dayStatus(outcomes) {
    const active = outcomes.filter((o) => !o.skipped);
    if (active.length === 0)
        return "grey";
    return active.every((o) => o.woke) ? "green" : "red";
}
/** Pairwise head-to-head results among ranked members. */
function headToHead(outcomes) {
    const ranked = outcomes.filter((o) => o.ranked && o.woke && !o.skipped);
    const out = [];
    for (let i = 0; i < ranked.length; i++) {
        for (let j = i + 1; j < ranked.length; j++) {
            const x = ranked[i];
            const y = ranked[j];
            const [a, b] = x.uid < y.uid ? [x, y] : [y, x];
            out.push({
                a: a.uid,
                b: b.uid,
                result: a.points === b.points ? "draw" : a.points > b.points ? "a" : "b",
            });
        }
    }
    return out;
}
/** Streak milestones that earn a badge. */
exports.STREAK_BADGES = [
    { id: "streak_7", at: 7 },
    { id: "streak_30", at: 30 },
    { id: "streak_100", at: 100 },
    { id: "streak_365", at: 365 },
];
/** Badge ids newly earned given counters before/after. */
function newBadges(input) {
    const out = [];
    const add = (id, ok) => {
        if (ok && !input.have.has(id))
            out.push(id);
    };
    add("first_light", input.roundsWoke >= 1);
    for (const b of exports.STREAK_BADGES)
        add(b.id, input.saffStreak >= b.at);
    add("lightning", input.lightning >= 5);
    add("zero_snooze", input.noSnooze >= 30);
    return out;
}
//# sourceMappingURL=stats.js.map