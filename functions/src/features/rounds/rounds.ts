import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { onRequest } from "firebase-functions/v2/https";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { z } from "zod";
import { callable, db } from "../../core/callable";
import { currentConstants } from "../../core/config";
import { AppError } from "../../core/errors";
import { gradeResult, reveal, runSweep } from "./lifecycle";
import { pushToUser } from "./push";

/** Grades a result as soon as it is written, then reveals if everyone is in. */
export const onResultCreated = onDocumentCreated(
  {
    document: "saffs/{saffId}/rounds/{occId}/results/{uid}",
    region: "us-central1",
    maxInstances: 5,
  },
  async (event) => {
    const { saffId, occId, uid } = event.params;
    await gradeResult(db, saffId, occId, uid);
    await reveal(db, saffId, occId);
  },
);

/** Every minute: lock rounds, run offline checks and deadlines, expire proposals. */
export const sweeper = onSchedule(
  { schedule: "every 1 minutes", region: "us-central1", maxInstances: 1 },
  async () => {
    await runSweep(db);
  },
);

/**
 * Dev ticker endpoint (docs/DEV_RELAXATIONS.md R-11): the Scheduler does not
 * run in the emulator, so `tools/demo/ticker.sh` calls this every few seconds.
 * Refuses to run anywhere but the Functions emulator.
 */
export const tick = onRequest({ region: "us-central1" }, async (_req, res) => {
  if (process.env.FUNCTIONS_EMULATOR !== "true") {
    res.status(404).send("not found");
    return;
  }
  res.json(await runSweep(db));
});

/** Asks a member who has not started to ring again. */
export const nudge = callable(
  "nudge",
  z.object({
    saffId: z.string().min(1),
    occurrenceId: z.string().min(1),
    targetUid: z.string().min(1),
  }),
  async (input, { uid }) => {
    const c = currentConstants();
    const roundRef = db.doc(`saffs/${input.saffId}/rounds/${input.occurrenceId}`);
    const [round, occ, presence, nudges, sender] = await Promise.all([
      roundRef.get(),
      db.doc(`saffs/${input.saffId}/occurrences/${input.occurrenceId}`).get(),
      roundRef.collection("presence").doc(input.targetUid).get(),
      roundRef.collection("nudges").where("fromId", "==", uid).where("toId", "==", input.targetUid).get(),
      db.doc(`saffs/${input.saffId}/members/${uid}`).get(),
    ]);
    if (!round.exists || round.get("status") !== "locked") throw new AppError("ROUND_CLOSED");
    const required = occ.get("requiredIds") as string[];
    if (!required.includes(uid) || !required.includes(input.targetUid)) {
      throw new AppError("NOT_PARTICIPANT");
    }
    const status = presence.get("status") as string | undefined;
    if (status === "done" || status === "playing") throw new AppError("NUDGE_TARGET_DONE");
    if (nudges.size >= c.nudgesPerTarget) throw new AppError("NUDGE_LIMIT");
    const lastAt = Math.max(0, ...nudges.docs.map((d) => (d.get("at") as Timestamp).toMillis()));
    if (Date.now() - lastAt < c.nudgeIntervalMs) throw new AppError("NUDGE_TOO_SOON");
    await roundRef.collection("nudges").add({
      fromId: uid,
      toId: input.targetUid,
      at: FieldValue.serverTimestamp(),
    });
    await pushToUser(
      db,
      input.targetUid,
      {
        type: "nudge",
        saffId: input.saffId,
        occurrenceId: input.occurrenceId,
        fromName: (sender.get("displayName") as string) ?? "",
        v: "1",
      },
      { highPriority: true },
    );
    return { left: c.nudgesPerTarget - nudges.size - 1 };
  },
);
