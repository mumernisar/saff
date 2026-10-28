import { hash32, mulberry32, shuffled } from "./prng";

/** A card as stored in a pack and copied into a round. */
export interface PackCard {
  readonly id: string;
  readonly category: string;
  readonly topic?: string;
  readonly difficulty: "easy" | "medium" | "hard";
  readonly type: "choice" | "typed" | "self";
  readonly question: string;
  readonly answer: string;
  readonly explanation?: string;
  readonly talk?: string;
  readonly source?: string;
  readonly options?: readonly string[];
  readonly accept?: readonly string[];
  readonly covers?: string;
}

/** The Card Duel lineup (docs/PRODUCT.md section 8.2), one entry per slot. */
export const LINEUP: readonly { category: string; difficulty: "easy" | "medium" | "hard" }[] = [
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
export function needsGateway(c: PackCard): boolean {
  const re = /\{\{(ayah|arabic|word|meaning|blank|hadith)/;
  return (
    re.test(c.question) ||
    re.test(c.answer) ||
    (c.options ?? []).some((o) => re.test(o))
  );
}

export interface PickInput {
  readonly pool: readonly PackCard[];
  readonly seenIds: ReadonlySet<string>;
  readonly occurrenceId: string;
  readonly count: number;
  readonly generalKnowledge: boolean;
  /** Cards members got wrong at least REVENGE_DELAY ago. */
  readonly revengeIds?: ReadonlySet<string>;
}

/**
 * Picks the scored cards for a Card Duel: seeded, no repeats where possible,
 * slot categories first and relaxed in the documented order.
 */
export function pickCards(input: PickInput): PackCard[] {
  const rnd = mulberry32(hash32(`${input.occurrenceId}:cards`));
  const usable = input.pool.filter((c) => !needsGateway(c));
  const chosen: PackCard[] = [];
  const taken = new Set<string>();
  const fresh = (c: PackCard) => !input.seenIds.has(c.id) && !taken.has(c.id);
  const anyUnused = (c: PackCard) => !taken.has(c.id);

  const take = (cands: PackCard[]): boolean => {
    if (cands.length === 0) return false;
    const c = shuffled(cands, rnd)[0]!;
    chosen.push(c);
    taken.add(c.id);
    return true;
  };

  for (const slot of LINEUP.slice(0, input.count)) {
    const inCategory = (c: PackCard) =>
      slot.category === "wildcard"
        ? c.category === "general" ||
          c.category === "quran" ||
          c.category === "deen" ||
          c.category === "story" ||
          c.category === "hadith"
        : c.category === slot.category;
    const wildcardOk = (c: PackCard) =>
      slot.category !== "wildcard" ||
      (input.revengeIds?.has(c.id) ?? false) ||
      (input.generalKnowledge && c.category === "general") ||
      c.category !== "general";

    const tiers: ((c: PackCard) => boolean)[] = [
      (c) => fresh(c) && inCategory(c) && wildcardOk(c) && c.difficulty === slot.difficulty,
      (c) => fresh(c) && inCategory(c) && wildcardOk(c),
      (c) => fresh(c) && wildcardOk(c),
      // Dev packs are tiny; once everything was seen, allow repeats so rounds still fill.
      (c) => anyUnused(c) && inCategory(c),
      anyUnused,
    ];
    for (const tier of tiers) {
      if (take(usable.filter(tier))) break;
    }
  }
  return chosen;
}

/** Shuffles choice options once, seeded, so every member sees the same order. */
export function withShuffledOptions(card: PackCard, occurrenceId: string): PackCard {
  if (card.type !== "choice" || !card.options) return card;
  const rnd = mulberry32(hash32(`${occurrenceId}:${card.id}`));
  return { ...card, options: shuffled(card.options, rnd) };
}
