"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.updateSaffSettings = exports.deletePack = exports.onImportUploaded = void 0;
const firestore_1 = require("firebase-admin/firestore");
const storage_1 = require("firebase-admin/storage");
const storage_2 = require("firebase-functions/v2/storage");
const zod_1 = require("zod");
const callable_1 = require("../../core/callable");
const config_1 = require("../../core/config");
const errors_1 = require("../../core/errors");
const logger_1 = require("../../core/logger");
const apkg_1 = require("../../domain/anki/apkg");
const cards_1 = require("../../domain/anki/cards");
const plain_text_1 = require("../../domain/anki/plain_text");
/** Whether [uid] may import (Plus), or the emulator-only dev switch is on (R-12). */
async function mayImport(uid) {
    if (process.env.FUNCTIONS_EMULATOR === "true" && process.env.DEV_PLUS === "true")
        return true;
    const e = await callable_1.db.doc(`users/${uid}/entitlement/current`).get();
    return e.get("limits")?.imports === true;
}
async function fail(importRef, code) {
    await importRef.update({ status: "failed", errorCode: code, finishedAt: firestore_1.FieldValue.serverTimestamp() });
}
/** Parses an uploaded Anki deck or text file into an imported pack. */
exports.onImportUploaded = (0, storage_2.onObjectFinalized)({ region: "us-central1", memory: "1GiB", maxInstances: 2, timeoutSeconds: 300 }, async (event) => {
    const path = event.data.name;
    const m = /^imports\/([^/]+)\/([^/]+)$/.exec(path);
    if (!m)
        return;
    const [, uid, importId] = m;
    const importRef = callable_1.db.doc(`imports/${importId}`);
    const imp = await importRef.get();
    const file = (0, storage_1.getStorage)().bucket(event.data.bucket).file(path);
    try {
        if (!imp.exists || imp.get("uid") !== uid)
            return;
        const c = (0, config_1.currentConstants)();
        await importRef.update({ status: "parsing" });
        if (!(await mayImport(uid)))
            return await fail(importRef, "PLUS_REQUIRED");
        const saffId = imp.get("saffId");
        const saff = await callable_1.db.doc(`saffs/${saffId}`).get();
        if (!saff.exists || !saff.get("memberIds").includes(uid)) {
            return await fail(importRef, "NOT_PARTICIPANT");
        }
        const existing = await callable_1.db.collection(`saffs/${saffId}/packs`).get();
        if (existing.size >= c.importsPerSaff)
            return await fail(importRef, "IMPORT_LIMIT");
        if (Number(event.data.size) > c.importMaxFile)
            return await fail(importRef, "IMPORT_TOO_LARGE");
        const [buf] = await file.download();
        const name = String(imp.get("fileName") ?? "").toLowerCase();
        let notes;
        if (name.endsWith(".apkg"))
            notes = await (0, apkg_1.parseApkg)(new Uint8Array(buf));
        else if (name.endsWith(".colpkg"))
            throw new apkg_1.ImportError("IMPORT_UNSUPPORTED_FORMAT");
        else if (/\.(txt|csv|tsv)$/.test(name))
            notes = (0, plain_text_1.parsePlainText)(buf.toString("utf8"));
        else
            throw new apkg_1.ImportError("IMPORT_UNSUPPORTED_FORMAT");
        const result = (0, cards_1.notesToCards)(notes, c.importMaxCards);
        if (result.cards.length === 0)
            throw new apkg_1.ImportError("IMPORT_EMPTY");
        const packRef = callable_1.db.collection(`saffs/${saffId}/packs`).doc();
        const title = String(imp.get("title") ?? name.replace(/\.[^.]+$/, "")).slice(0, 60) || "Imported deck";
        const batch = callable_1.db.batch();
        batch.set(packRef, {
            title,
            source: "anki",
            createdBy: uid,
            cardCount: result.cards.length,
            createdAt: firestore_1.FieldValue.serverTimestamp(),
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
            finishedAt: firestore_1.FieldValue.serverTimestamp(),
        });
        const member = await callable_1.db.doc(`saffs/${saffId}/members/${uid}`).get();
        batch.set(callable_1.db.doc(`saffs/${saffId}/messages/sys_pack_added_${packRef.id}`), {
            type: "pack_added",
            authorId: "system",
            systemPayload: { title, cards: result.cards.length, by: member.get("displayName") ?? "" },
            createdAt: firestore_1.FieldValue.serverTimestamp(),
            seenBy: {},
        });
        await batch.commit();
    }
    catch (e) {
        const code = e instanceof apkg_1.ImportError ? e.code : "IMPORT_CORRUPT";
        logger_1.log.warn("import_failed", { importId, code, error: String(e) });
        await fail(importRef, code);
    }
    finally {
        await file.delete({ ignoreNotFound: true }).catch(() => undefined);
    }
});
/** Deletes an imported pack (importer or owner). */
exports.deletePack = (0, callable_1.callable)("deletePack", zod_1.z.object({ saffId: zod_1.z.string().min(1), packId: zod_1.z.string().min(1) }), async (input, { uid }) => {
    const saff = await callable_1.db.doc(`saffs/${input.saffId}`).get();
    const pack = await callable_1.db.doc(`saffs/${input.saffId}/packs/${input.packId}`).get();
    if (!saff.exists || !pack.exists)
        throw new errors_1.AppError("NOT_FOUND");
    if (pack.get("createdBy") !== uid && saff.get("ownerId") !== uid)
        throw new errors_1.AppError("NOT_SAFF_OWNER");
    await callable_1.db.recursiveDelete(pack.ref);
    return { ok: true };
});
/** Changes the saff's card mix or mode schedule (owner in groups; either member in pairs). */
exports.updateSaffSettings = (0, callable_1.callable)("updateSaffSettings", zod_1.z.object({
    saffId: zod_1.z.string().min(1),
    cardMix: zod_1.z
        .object({ custom: zod_1.z.boolean().optional(), generalKnowledge: zod_1.z.boolean().optional() })
        .optional(),
    modeSchedule: zod_1.z
        .object({ type: zod_1.z.enum(["surprise", "order", "single"]), single: zod_1.z.string().optional(), order: zod_1.z.array(zod_1.z.string()).optional() })
        .optional(),
}), async (input, { uid }) => {
    const ref = callable_1.db.doc(`saffs/${input.saffId}`);
    const saff = await ref.get();
    if (!saff.exists)
        throw new errors_1.AppError("SAFF_NOT_FOUND");
    const members = saff.get("memberIds");
    if (!members.includes(uid))
        throw new errors_1.AppError("NOT_PARTICIPANT");
    if (members.length > 2 && saff.get("ownerId") !== uid)
        throw new errors_1.AppError("NOT_SAFF_OWNER");
    const update = {};
    for (const [k, v] of Object.entries(input.cardMix ?? {}))
        update[`cardMix.${k}`] = v;
    if (input.modeSchedule)
        update.modeSchedule = input.modeSchedule;
    await ref.update(update);
    return { ok: true };
});
//# sourceMappingURL=imports.js.map