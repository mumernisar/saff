"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.officialCards = officialCards;
const promises_1 = require("node:fs/promises");
const node_path_1 = __importDefault(require("node:path"));
let cache;
function packsDir() {
    return (process.env.PACKS_DIR ??
        node_path_1.default.resolve(process.cwd(), "../../saff-cards/packs/duha-packs/dist"));
}
async function readJson(rel) {
    const dir = packsDir();
    if (dir.startsWith("http")) {
        const res = await fetch(`${dir}/${rel}`);
        if (!res.ok)
            throw new Error(`pack fetch ${rel}: ${res.status}`);
        return (await res.json());
    }
    return JSON.parse(await (0, promises_1.readFile)(node_path_1.default.join(dir, rel), "utf8"));
}
/**
 * Official `core` pack cards, cached for ten minutes. Surah (learning) packs
 * are excluded until the content gateway can resolve their placeholders.
 */
async function officialCards() {
    if (cache && Date.now() - cache.at < 600_000)
        return cache.cards;
    const index = await readJson("index.json");
    const cards = [];
    for (const p of index.packs.filter((x) => x.kind === "core")) {
        const pack = await readJson(p.path);
        for (const c of pack.cards) {
            if (c.status && c.status !== "approved")
                continue;
            cards.push(c);
        }
    }
    cache = { at: Date.now(), cards };
    return cards;
}
//# sourceMappingURL=packs.js.map