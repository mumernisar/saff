"use strict";
/** Anki notes → Saff cards (docs/CONTENT.md section 6.2). Pure and testable. */
Object.defineProperty(exports, "__esModule", { value: true });
exports.cleanHtml = cleanHtml;
exports.notesToCards = notesToCards;
const ENTITIES = {
    "&nbsp;": " ",
    "&amp;": "&",
    "&lt;": "<",
    "&gt;": ">",
    "&quot;": '"',
    "&#39;": "'",
};
/** Strips HTML, sounds and images; keeps line breaks. */
function cleanHtml(input) {
    const hadMedia = /\[sound:[^\]]*\]|<img\b/i.test(input);
    let s = input
        .replace(/\[sound:[^\]]*\]/gi, "")
        .replace(/<img\b[^>]*>/gi, "")
        .replace(/<br\s*\/?>/gi, "\n")
        .replace(/<\/(div|p|li)>/gi, "\n")
        .replace(/<[^>]*>/g, "");
    s = s.replace(/&(nbsp|amp|lt|gt|quot|#39);/g, (m) => ENTITIES[m] ?? m);
    // eslint-disable-next-line no-control-regex
    s = s.replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f]/g, "");
    return { text: s.replace(/[ \t]+/g, " ").replace(/\n{3,}/g, "\n\n").trim(), hadMedia };
}
function simpleId(n, q) {
    let h = 2166136261;
    for (let i = 0; i < q.length; i++)
        h = Math.imul(h ^ q.charCodeAt(i), 16777619);
    return `imp-${n}-${(h >>> 0).toString(36)}`;
}
function typedOrSelf(answer) {
    const words = answer.split(/\s+/).filter(Boolean).length;
    return words <= 4 && answer.length <= 40
        ? { type: "typed", accept: [answer] }
        : { type: "self" };
}
const CLOZE = /\{\{c(\d+)::(.*?)(?:::(.*?))?\}\}/gs;
/** Maps notes to cards, applying limits and collecting warnings. */
function notesToCards(notes, maxCards) {
    const cards = [];
    const warnings = new Set();
    let n = 0;
    const push = (q, a, tags, extra) => {
        if (!q || !a) {
            warnings.add("CARDS_SKIPPED_EMPTY");
            return;
        }
        if (cards.length >= maxCards) {
            warnings.add("TRUNCATED");
            return;
        }
        n++;
        const question = q.slice(0, 160);
        if (question.length < q.length)
            warnings.add("TRUNCATED");
        cards.push({
            id: simpleId(n, question),
            category: "custom",
            difficulty: "medium",
            question,
            answer: a.slice(0, 300),
            ...typedOrSelf(a),
            ...(extra ? { explanation: extra.slice(0, 300) } : {}),
            tags,
        });
    };
    for (const note of notes) {
        if (note.kind === "media") {
            warnings.add("MEDIA_SKIPPED");
            continue;
        }
        const cleaned = note.fields.map((f) => cleanHtml(f));
        if (cleaned.some((c) => c.hadMedia))
            warnings.add("MEDIA_SKIPPED");
        const f = cleaned.map((c) => c.text);
        if (note.kind === "cloze") {
            const source = note.fields[0] ?? "";
            const numbers = new Set([...source.matchAll(CLOZE)].map((m) => m[1]));
            for (const num of numbers) {
                const answers = [];
                const masked = source.replace(CLOZE, (_m, k, text) => {
                    if (k === num) {
                        answers.push(cleanHtml(text).text);
                        return "____";
                    }
                    return text;
                });
                push(cleanHtml(masked).text, answers.join(", "), note.tags, f[1]);
            }
            continue;
        }
        const rest = f.slice(2).filter(Boolean).join(" · ");
        push(f[0] ?? "", f[1] ?? "", note.tags, note.kind === "other" ? rest : undefined);
    }
    return { cards, warnings: [...warnings] };
}
//# sourceMappingURL=cards.js.map