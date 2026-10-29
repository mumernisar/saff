import { unzipSync } from "fflate";
import { decompress } from "fzstd";
import initSqlJs, { type Database } from "sql.js";
import type { RawNote } from "./cards";

/** Error carrying a catalog code. */
export class ImportError extends Error {
  constructor(readonly code: "IMPORT_CORRUPT" | "IMPORT_UNSUPPORTED_FORMAT" | "IMPORT_EMPTY") {
    super(code);
  }
}

/** Reads notes from an `.apkg` (zip) file. */
export async function parseApkg(bytes: Uint8Array): Promise<RawNote[]> {
  let files: Record<string, Uint8Array>;
  try {
    files = unzipSync(bytes);
  } catch {
    throw new ImportError("IMPORT_CORRUPT");
  }
  const SQL = await initSqlJs();
  const order = ["collection.anki21b", "collection.anki21", "collection.anki2"];
  for (const name of order) {
    let data = files[name];
    if (!data) continue;
    if (name.endsWith("b")) data = decompress(data);
    const db = new SQL.Database(data);
    try {
      const notes = readNotes(db);
      // Old exports ship a decoy collection with one "please update Anki" note.
      if (notes.length === 1 && /update|newer version/i.test(notes[0]!.fields.join(" "))) continue;
      return notes;
    } finally {
      db.close();
    }
  }
  throw new ImportError(files["collection.colpkg"] ? "IMPORT_UNSUPPORTED_FORMAT" : "IMPORT_CORRUPT");
}

/** Reads notes from an open collection database (schema 11 and 18). */
export function readNotes(db: Database): RawNote[] {
  const kinds = new Map<number, RawNote["kind"]>();
  try {
    const col = db.exec("SELECT models FROM col");
    const json = col[0]?.values[0]?.[0];
    if (typeof json === "string" && json) {
      const models = JSON.parse(json) as Record<string, { id: number | string; name: string; type: number }>;
      for (const m of Object.values(models)) kinds.set(Number(m.id), kindOf(m.name, m.type));
    }
  } catch {
    /* schema 18 has no models column */
  }
  try {
    const nt = db.exec("SELECT id, name FROM notetypes");
    for (const row of nt[0]?.values ?? []) kinds.set(Number(row[0]), kindOf(String(row[1]), 0));
  } catch {
    /* schema 11 has no notetypes table */
  }
  const out: RawNote[] = [];
  const res = db.exec("SELECT mid, flds, tags FROM notes");
  for (const row of res[0]?.values ?? []) {
    out.push({
      fields: String(row[1]).split("\x1f"),
      tags: String(row[2]).split(/\s+/).filter(Boolean),
      kind: kinds.get(Number(row[0])) ?? "basic",
    });
  }
  return out;
}

function kindOf(name: string, type: number): RawNote["kind"] {
  const n = name.toLowerCase();
  if (type === 1 || n.includes("cloze")) return "cloze";
  if (n.includes("occlusion")) return "media";
  if (n.startsWith("basic")) return "basic";
  return "other";
}
