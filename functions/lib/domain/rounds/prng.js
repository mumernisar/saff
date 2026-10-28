"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.hash32 = hash32;
exports.mulberry32 = mulberry32;
exports.shuffled = shuffled;
/** 32-bit FNV-1a hash of a string. */
function hash32(s) {
    let h = 0x811c9dc5;
    for (let i = 0; i < s.length; i++) {
        h ^= s.charCodeAt(i);
        h = Math.imul(h, 0x01000193);
    }
    return h >>> 0;
}
/** mulberry32: small seeded PRNG returning floats in [0, 1). */
function mulberry32(seed) {
    let a = seed >>> 0;
    return () => {
        a = (a + 0x6d2b79f5) >>> 0;
        let t = a;
        t = Math.imul(t ^ (t >>> 15), t | 1);
        t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
}
/** Seeded Fisher-Yates shuffle returning a new array. */
function shuffled(items, rnd) {
    const a = [...items];
    for (let i = a.length - 1; i > 0; i--) {
        const j = Math.floor(rnd() * (i + 1));
        [a[i], a[j]] = [a[j], a[i]];
    }
    return a;
}
//# sourceMappingURL=prng.js.map