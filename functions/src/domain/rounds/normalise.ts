/** Typed-answer normalisation and matching (docs/PRODUCT.md section 8.4). */

const ARABIC_DIACRITICS = /[ؐ-ًؚ-ٰٟۖ-ۭ]/g;

/** Normalises an answer for comparison. */
export function normalise(input: string): string {
  let s = input.toLowerCase().normalize("NFKC");
  s = s.replace(ARABIC_DIACRITICS, "");
  s = s.replace(/[ʿʾ‘’`]/g, "'");
  // Transliteration folds.
  s = s.replace(/aa/g, "a").replace(/ee/g, "i").replace(/oo/g, "u");
  // Drop apostrophes that are not inside a word, then other punctuation.
  s = s.replace(/(^|\s)'+|'+(\s|$)/g, " ");
  s = s.replace(/[^\p{L}\p{N}\s']/gu, " ");
  s = s.replace(/'/g, "");
  s = s.replace(/\s+/g, " ").trim();
  s = s.replace(/^(the|a|an) /, "");
  return s;
}

/** Damerau-Levenshtein (optimal string alignment) distance. */
export function editDistance(a: string, b: string): number {
  const d: number[][] = Array.from({ length: a.length + 1 }, (_, i) => [i]);
  for (let j = 1; j <= b.length; j++) d[0]![j] = j;
  for (let i = 1; i <= a.length; i++) {
    for (let j = 1; j <= b.length; j++) {
      const cost = a[i - 1] === b[j - 1] ? 0 : 1;
      d[i]![j] = Math.min(d[i - 1]![j]! + 1, d[i]![j - 1]! + 1, d[i - 1]![j - 1]! + cost);
      if (i > 1 && j > 1 && a[i - 1] === b[j - 2] && a[i - 2] === b[j - 1]) {
        d[i]![j] = Math.min(d[i]![j]!, d[i - 2]![j - 2]! + 1);
      }
    }
  }
  return d[a.length]![b.length]!;
}

/** Whether [answer] matches any entry of [accept]. */
export function matchesTyped(answer: string, accept: readonly string[]): boolean {
  const n = normalise(answer);
  if (!n) return false;
  for (const entry of accept) {
    const e = normalise(entry);
    if (n === e) return true;
    const tolerance = e.length >= 10 ? 2 : e.length >= 5 ? 1 : 0;
    if (tolerance > 0 && editDistance(n, e) <= tolerance) return true;
  }
  return false;
}
