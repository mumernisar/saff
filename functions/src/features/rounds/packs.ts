import { readFile } from "node:fs/promises";
import path from "node:path";
import type { PackCard } from "../../domain/rounds/cards";

interface PackIndex {
  packs: { id: string; kind: string; path: string; version: number }[];
}

let cache: { at: number; cards: PackCard[] } | undefined;

function packsDir(): string {
  return (
    process.env.PACKS_DIR ??
    path.resolve(process.cwd(), "../../saff-cards/packs/duha-packs/dist")
  );
}

async function readJson<T>(rel: string): Promise<T> {
  const dir = packsDir();
  if (dir.startsWith("http")) {
    const res = await fetch(`${dir}/${rel}`);
    if (!res.ok) throw new Error(`pack fetch ${rel}: ${res.status}`);
    return (await res.json()) as T;
  }
  return JSON.parse(await readFile(path.join(dir, rel), "utf8")) as T;
}

/**
 * Official `core` pack cards, cached for ten minutes. Surah (learning) packs
 * are excluded until the content gateway can resolve their placeholders.
 */
export async function officialCards(): Promise<PackCard[]> {
  if (cache && Date.now() - cache.at < 600_000) return cache.cards;
  const index = await readJson<PackIndex>("index.json");
  const cards: PackCard[] = [];
  for (const p of index.packs.filter((x) => x.kind === "core")) {
    const pack = await readJson<{ cards: (PackCard & { status?: string })[] }>(p.path);
    for (const c of pack.cards) {
      if (c.status && c.status !== "approved") continue;
      cards.push(c);
    }
  }
  cache = { at: Date.now(), cards };
  return cards;
}
