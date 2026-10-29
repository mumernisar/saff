"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.ImportError = void 0;
exports.parseApkg = parseApkg;
exports.readNotes = readNotes;
const fflate_1 = require("fflate");
const fzstd_1 = require("fzstd");
const sql_js_1 = __importDefault(require("sql.js"));
/** Error carrying a catalog code. */
class ImportError extends Error {
    code;
    constructor(code) {
        super(code);
        this.code = code;
    }
}
exports.ImportError = ImportError;
/** Reads notes from an `.apkg` (zip) file. */
async function parseApkg(bytes) {
    let files;
    try {
        files = (0, fflate_1.unzipSync)(bytes);
    }
    catch {
        throw new ImportError("IMPORT_CORRUPT");
    }
    const SQL = await (0, sql_js_1.default)();
    const order = ["collection.anki21b", "collection.anki21", "collection.anki2"];
    for (const name of order) {
        let data = files[name];
        if (!data)
            continue;
        if (name.endsWith("b"))
            data = (0, fzstd_1.decompress)(data);
        const db = new SQL.Database(data);
        try {
            const notes = readNotes(db);
            // Old exports ship a decoy collection with one "please update Anki" note.
            if (notes.length === 1 && /update|newer version/i.test(notes[0].fields.join(" ")))
                continue;
            return notes;
        }
        finally {
            db.close();
        }
    }
    throw new ImportError(files["collection.colpkg"] ? "IMPORT_UNSUPPORTED_FORMAT" : "IMPORT_CORRUPT");
}
/** Reads notes from an open collection database (schema 11 and 18). */
function readNotes(db) {
    const kinds = new Map();
    try {
        const col = db.exec("SELECT models FROM col");
        const json = col[0]?.values[0]?.[0];
        if (typeof json === "string" && json) {
            const models = JSON.parse(json);
            for (const m of Object.values(models))
                kinds.set(Number(m.id), kindOf(m.name, m.type));
        }
    }
    catch {
        /* schema 18 has no models column */
    }
    try {
        const nt = db.exec("SELECT id, name FROM notetypes");
        for (const row of nt[0]?.values ?? [])
            kinds.set(Number(row[0]), kindOf(String(row[1]), 0));
    }
    catch {
        /* schema 11 has no notetypes table */
    }
    const out = [];
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
function kindOf(name, type) {
    const n = name.toLowerCase();
    if (type === 1 || n.includes("cloze"))
        return "cloze";
    if (n.includes("occlusion"))
        return "media";
    if (n.startsWith("basic"))
        return "basic";
    return "other";
}
//# sourceMappingURL=apkg.js.map