/** Pure stats helpers (docs/PRODUCT.md section 11). */

/** One member's outcome in a revealed occurrence. */
export interface MemberOutcome {
  readonly uid: string;
  readonly woke: boolean;
  readonly skipped: boolean;
  readonly ranked: boolean;
  readonly points: number;
  readonly wakeMs: number | null;
  readonly snoozed: boolean;
}

/** Calendar colour of a day for the saff (flows.md frames 8d-8f). */
export function dayStatus(outcomes: readonly MemberOutcome[]): "green" | "red" | "grey" {
  const active = outcomes.filter((o) => !o.skipped);
  if (active.length === 0) return "grey";
  return active.every((o) => o.woke) ? "green" : "red";
}

/** Pairwise head-to-head results among ranked members. */
export function headToHead(
  outcomes: readonly MemberOutcome[],
): { a: string; b: string; result: "a" | "b" | "draw" }[] {
  const ranked = outcomes.filter((o) => o.ranked && o.woke && !o.skipped);
  const out: { a: string; b: string; result: "a" | "b" | "draw" }[] = [];
  for (let i = 0; i < ranked.length; i++) {
    for (let j = i + 1; j < ranked.length; j++) {
      const x = ranked[i]!;
      const y = ranked[j]!;
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
export const STREAK_BADGES: readonly { id: string; at: number }[] = [
  { id: "streak_7", at: 7 },
  { id: "streak_30", at: 30 },
  { id: "streak_100", at: 100 },
  { id: "streak_365", at: 365 },
];

/** Badge ids newly earned given counters before/after. */
export function newBadges(input: {
  readonly saffStreak: number;
  readonly roundsWoke: number;
  readonly lightning: number;
  readonly noSnooze: number;
  readonly have: ReadonlySet<string>;
}): string[] {
  const out: string[] = [];
  const add = (id: string, ok: boolean) => {
    if (ok && !input.have.has(id)) out.push(id);
  };
  add("first_light", input.roundsWoke >= 1);
  for (const b of STREAK_BADGES) add(b.id, input.saffStreak >= b.at);
  add("lightning", input.lightning >= 5);
  add("zero_snooze", input.noSnooze >= 30);
  return out;
}
