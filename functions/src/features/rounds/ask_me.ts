import { FieldValue } from "firebase-admin/firestore";
import { z } from "zod";
import { callable, db } from "../../core/callable";
import { AppError } from "../../core/errors";

/**
 * The planter grades an ask-me answer after the reveal (docs/PRODUCT.md 5.2).
 * Bonus, never scored: the grade only shows in the review.
 */
export const gradeAskMe = callable(
  "gradeAskMe",
  z.object({
    saffId: z.string().min(1),
    occurrenceId: z.string().min(1),
    cardId: z.string().min(1),
    correct: z.boolean(),
  }),
  async (input, { uid }) => {
    const roundRef = db.doc(`saffs/${input.saffId}/rounds/${input.occurrenceId}`);
    const round = await roundRef.get();
    if (!round.exists) throw new AppError("NOT_FOUND");
    if (round.get("status") !== "revealed") throw new AppError("ROUND_NOT_READY");
    const card = ((round.get("bonusCards") as { id: string; authorId?: string }[]) ?? []).find(
      (c) => c.id === input.cardId,
    );
    if (!card || card.authorId !== uid) throw new AppError("NOT_PARTICIPANT");
    await roundRef
      .collection("askMeGrades")
      .doc(input.cardId)
      .set({ correct: input.correct, by: uid, at: FieldValue.serverTimestamp() });
    return { ok: true };
  },
);
