import { randomInt } from "node:crypto";

const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

/** A 6-character invite code (docs/DATA_MODEL.md section 1). */
export function newInviteCode(): string {
  let s = "";
  for (let i = 0; i < 6; i++) s += ALPHABET[randomInt(ALPHABET.length)];
  return s;
}

/** Whether [s] looks like an invite code. */
export function isInviteCode(s: string): boolean {
  return /^[A-HJ-NP-Z2-9]{6}$/.test(s);
}
