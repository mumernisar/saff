"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.newInviteCode = newInviteCode;
exports.isInviteCode = isInviteCode;
const node_crypto_1 = require("node:crypto");
const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
/** A 6-character invite code (docs/DATA_MODEL.md section 1). */
function newInviteCode() {
    let s = "";
    for (let i = 0; i < 6; i++)
        s += ALPHABET[(0, node_crypto_1.randomInt)(ALPHABET.length)];
    return s;
}
/** Whether [s] looks like an invite code. */
function isInviteCode(s) {
    return /^[A-HJ-NP-Z2-9]{6}$/.test(s);
}
//# sourceMappingURL=ids.js.map