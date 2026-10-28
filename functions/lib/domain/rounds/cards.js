"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.LINEUP = void 0;
exports.needsGateway = needsGateway;
exports.pickCards = pickCards;
exports.withShuffledOptions = withShuffledOptions;
const prng_1 = require("./prng");
/** The Card Duel lineup (docs/PRODUCT.md section 8.2), one entry per slot. */
exports.LINEUP = [
    { category: "quran", difficulty: "easy" },
    { category: "quran", difficulty: "medium" },
    { category: "story", difficulty: "medium" },
    { category: "story", difficulty: "hard" },
    { category: "hadith", difficulty: "medium" },
    { category: "hadith", difficulty: "hard" },
    { category: "deen", difficulty: "medium" },
    { category: "wildcard", difficulty: "easy" },
];
/** Whether the question or answer side of [c] still needs the content gateway. */
function needsGateway(c) {
    const re = /\{\{(ayah|arabic|word|meaning|blank|hadith)/;
    return (re.test(c.question) ||
        re.test(c.answer) ||
        (c.options ?? []).some((o) => re.test(o)));
}
/**
 * Picks the scored cards for a Card Duel: seeded, no repeats where possible,
 * slot categories first and relaxed in the documented order.
 */
function pickCards(input) {
    const rnd = (0, prng_1.mulberry32)((0, prng_1.hash32)(`${input.occurrenceId}:cards`));
    const usable = input.pool.filter((c) => !needsGateway(c));
    const chosen = [];
    const taken = new Set();
    const fresh = (c) => !input.seenIds.has(c.id) && !taken.has(c.id);
    const anyUnused = (c) => !taken.has(c.id);
    const take = (cands) => {
        if (cands.length === 0)
            return false;
        const c = (0, prng_1.shuffled)(cands, rnd)[0];
        chosen.push(c);
        taken.add(c.id);
        return true;
    };
    for (const slot of exports.LINEUP.slice(0, input.count)) {
        const inCategory = (c) => slot.category === "wildcard"
            ? c.category === "general" ||
                c.category === "quran" ||
                c.category === "deen" ||
                c.category === "story" ||
                c.category === "hadith"
            : c.category === slot.category;
        const wildcardOk = (c) => slot.category !== "wildcard" ||
            (input.revengeIds?.has(c.id) ?? false) ||
            (input.generalKnowledge && c.category === "general") ||
            c.category !== "general";
        const tiers = [
            (c) => fresh(c) && inCategory(c) && wildcardOk(c) && c.difficulty === slot.difficulty,
            (c) => fresh(c) && inCategory(c) && wildcardOk(c),
            (c) => fresh(c) && wildcardOk(c),
            // Dev packs are tiny; once everything was seen, allow repeats so rounds still fill.
            (c) => anyUnused(c) && inCategory(c),
            anyUnused,
        ];
        for (const tier of tiers) {
            if (take(usable.filter(tier)))
                break;
        }
    }
    return chosen;
}
/** Shuffles choice options once, seeded, so every member sees the same order. */
function withShuffledOptions(card, occurrenceId) {
    if (card.type !== "choice" || !card.options)
        return card;
    const rnd = (0, prng_1.mulberry32)((0, prng_1.hash32)(`${occurrenceId}:${card.id}`));
    return { ...card, options: (0, prng_1.shuffled)(card.options, rnd) };
}
//# sourceMappingURL=cards.js.map