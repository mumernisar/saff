import { FieldValue } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { onObjectFinalized } from "firebase-functions/v2/storage";
import { z } from "zod";
import { callable, db } from "../../core/callable";
import { currentConstants } from "../../core/config";
import { AppError } from "../../core/errors";
import { log } from "../../core/logger";
import { ImportError, parseApkg } from "../../domain/anki/apkg";
import { notesToCards } from "../../domain/anki/cards";
import { parsePlainText } from "../../domain/anki/plain_text";

/** Whether [uid] may import (Plus), or the emulator-only dev switch is on (R-12). */
async function mayImport(uid: string): Promise<boolean> {
  if (process.env.FUNCTIONS_EMULATOR === "true" && process.env.DEV_PLUS === "true") return true;
  const e = await db.doc(`users/${uid}/entitlement/current`).get();
  return (e.get("limits") as { imports?: boolean } | undefined)?.imports === true;
}

async function fail(importRef: FirebaseFirestore.DocumentReference, code: string) {
  await importRef.update({ status: "failed", errorCode: code, finishedAt: FieldValue.serverTimestamp() });
}

/** Parses an uploaded Anki deck or text file into an imported pack. */
export const onImportUploaded = onObjectFinalized(
  { region: "us-central1", memory: "1GiB", maxInstances: 2, timeoutSeconds: 300 },
  async (event) => {
    const path = event.data.name;
    const m = /^imports\/([^/]+)\/([^/]+)$/.exec(path);
    if (!m) return;
    const [, uid, importId] = m as unknown as [string, string, string];
    const importRef = db.doc(`imports/${importId}`);
    const imp = await importRef.get();
    const file = getStorage().bucket(event.data.bucket).file(path);
    try {
      if (!imp.exists || imp.get("uid") !== uid) return;
      const c = currentConstants();
      await importRef.update({ status: "parsing" });
      if (!(await mayImport(uid))) return await fail(importRef, "PLUS_REQUIRED");
      const saffId = imp.get("saffId") as string;
      const saff = await db.doc(`saffs/${saffId}`).get();
      if (!saff.exists || !(saff.get("memberIds") as string[]).includes(uid)) {
        return await fail(importRef, "NOT_PARTICIPANT");
      }
      const existing = await db.collection(`saffs/${saffId}/packs`).get();
      if (existing.size >= c.importsPerSaff) return await fail(importRef, "IMPORT_LIMIT");
      if (Number(event.data.size) > c.importMaxFile) return await fail(importRef, "IMPORT_TOO_LARGE");

      const [buf] = await file.download();
      const name = String(imp.get("fileName") ?? "").toLowerCase();
      let notes;
      if (name.endsWith(".apkg")) notes = await parseApkg(new Uint8Array(buf));
      else if (name.endsWith(".colpkg")) throw new ImportError("IMPORT_UNSUPPORTED_FORMAT");
      else if (/\.(txt|csv|tsv)$/.test(name)) notes = parsePlainText(buf.toString("utf8"));
      else throw new ImportError("IMPORT_UNSUPPORTED_FORMAT");

      const result = notesToCards(notes, c.importMaxCards);
      if (result.cards.length === 0) throw new ImportError("IMPORT_EMPTY");

      const packRef = db.collection(`saffs/${saffId}/packs`).doc();
      const title = String(imp.get("title") ?? name.replace(/\.[^.]+$/, "")).slice(0, 60) || "Imported deck";
      const batch = db.batch();
      batch.set(packRef, {
        title,
        source: "anki",
        createdBy: uid,
        cardCount: result.cards.length,
        createdAt: FieldValue.serverTimestamp(),
        version: 1,
      });
      for (let i = 0; i < result.cards.length; i += 500) {
        batch.set(packRef.collection("chunks").doc(String(i / 500)), {
          cards: result.cards.slice(i, i + 500),
        });
      }
      batch.update(importRef, {
        status: "done",
        packId: packRef.id,
        counts: { notes: notes.length, cards: result.cards.length },
        warnings: result.warnings,
        sample: result.cards.slice(0, 5).map((x) => ({ question: x.question, answer: x.answer })),
        finishedAt: FieldValue.serverTimestamp(),
      });
      const member = await db.doc(`saffs/${saffId}/members/${uid}`).get();
      batch.set(db.doc(`saffs/${saffId}/messages/sys_pack_added_${packRef.id}`), {
        type: "pack_added",
        authorId: "system",
        systemPayload: { title, cards: result.cards.length, by: member.get("displayName") ?? "" },
        createdAt: FieldValue.serverTimestamp(),
        seenBy: {},
      });
      await batch.commit();
    } catch (e) {
      const code = e instanceof ImportError ? e.code : "IMPORT_CORRUPT";
      log.warn("import_failed", { importId, code, error: String(e) });
      await fail(importRef, code);
    } finally {
      await file.delete({ ignoreNotFound: true }).catch(() => undefined);
    }
  },
);

/** Deletes an imported pack (importer or owner). */
export const deletePack = callable(
  "deletePack",
  z.object({ saffId: z.string().min(1), packId: z.string().min(1) }),
  async (input, { uid }) => {
    const saff = await db.doc(`saffs/${input.saffId}`).get();
    const pack = await db.doc(`saffs/${input.saffId}/packs/${input.packId}`).get();
    if (!saff.exists || !pack.exists) throw new AppError("NOT_FOUND");
    if (pack.get("createdBy") !== uid && saff.get("ownerId") !== uid) throw new AppError("NOT_SAFF_OWNER");
    await db.recursiveDelete(pack.ref);
    return { ok: true };
  },
);

/** Changes the saff's card mix or mode schedule (owner in groups; either member in pairs). */
export const updateSaffSettings = callable(
  "updateSaffSettings",
  z.object({
    saffId: z.string().min(1),
    cardMix: z
      .object({ custom: z.boolean().optional(), generalKnowledge: z.boolean().optional() })
      .optional(),
    modeSchedule: z
      .object({ type: z.enum(["surprise", "order", "single"]), single: z.string().optional(), order: z.array(z.string()).optional() })
      .optional(),
  }),
  async (input, { uid }) => {
    const ref = db.doc(`saffs/${input.saffId}`);
    const saff = await ref.get();
    if (!saff.exists) throw new AppError("SAFF_NOT_FOUND");
    const members = saff.get("memberIds") as string[];
    if (!members.includes(uid)) throw new AppError("NOT_PARTICIPANT");
    if (members.length > 2 && saff.get("ownerId") !== uid) throw new AppError("NOT_SAFF_OWNER");
    const update: Record<string, unknown> = {};
    for (const [k, v] of Object.entries(input.cardMix ?? {})) update[`cardMix.${k}`] = v;
    if (input.modeSchedule) update.modeSchedule = input.modeSchedule;
    await ref.update(update);
    return { ok: true };
  },
);
