import type { RawNote } from "./cards";

/**
 * Parses Anki's "Notes in Plain Text" export or any 2-column file, honouring
 * the `#separator:`, `#html:` and `#tags column:` header lines.
 */
export function parsePlainText(text: string): RawNote[] {
  let separator = "\t";
  let tagsColumn: number | undefined;
  const rows: string[] = [];
  for (const line of text.replace(/\r\n/g, "\n").split("\n")) {
    if (line.startsWith("#")) {
      const m = /^#(\w[\w ]*):(.*)$/.exec(line);
      if (m) {
        const key = m[1]!.trim().toLowerCase();
        const value = m[2]!.trim();
        if (key === "separator") {
          separator =
            { tab: "\t", comma: ",", semicolon: ";", space: " ", pipe: "|", colon: ":" }[
              value.toLowerCase()
            ] ?? value.slice(0, 1) ?? "\t";
        }
        if (key === "tags column") tagsColumn = Number(value) - 1;
      }
      continue;
    }
    if (line.trim()) rows.push(line);
  }
  if (!text.includes("#separator") && !rows.some((r) => r.includes("\t"))) {
    separator = rows.some((r) => r.includes(";")) && !rows.some((r) => r.includes(","))
      ? ";"
      : ",";
  }
  return rows.map((row) => {
    const cols = splitRow(row, separator);
    const tags = tagsColumn !== undefined ? (cols[tagsColumn] ?? "").split(/\s+/).filter(Boolean) : [];
    const fields = cols.filter((_, i) => i !== tagsColumn);
    return { fields, tags, kind: "basic" as const };
  });
}

function splitRow(row: string, sep: string): string[] {
  const out: string[] = [];
  let cur = "";
  let quoted = false;
  for (let i = 0; i < row.length; i++) {
    const ch = row[i]!;
    if (ch === '"') {
      if (quoted && row[i + 1] === '"') {
        cur += '"';
        i++;
      } else {
        quoted = !quoted;
      }
    } else if (ch === sep && !quoted) {
      out.push(cur);
      cur = "";
    } else {
      cur += ch;
    }
  }
  out.push(cur);
  return out;
}
