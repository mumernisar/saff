import { FieldValue, Timestamp } from "firebase-admin/firestore";
import { z } from "zod";
import { callable, db } from "../../core/callable";
import { currentConstants } from "../../core/config";
import { AppError } from "../../core/errors";

/**
 * Plants a card for the other member of a pair (docs/PRODUCT.md section 5.2).
 * Templates: askMe (free text, planter reads it), quiz (typed), quizChoice.
 */
export const plantCard = callable(
  "plantCard",
  z.object({
    saffId: z.string().min(1),
    template: z.enum(["askMe", "quiz", "quizChoice"]),
    question: z.string().trim().min(1),
    answer: z.string().trim().max(200).optional(),
    options: z.array(z.string().trim().min(1).max(100)).length(4).optional(),
    correctIndex: z.number().int().min(0).max(3).optional(),
  }),
  async (input, { uid }) => {
    const c = currentConstants();
    if (input.question.length > c.plantMaxChars) throw new AppError("PLANT_TOO_LONG");
    const saffRef = db.doc(`saffs/${input.saffId}`);
    const saff = await saffRef.get();
    if (!saff.exists) throw new AppError("SAFF_NOT_FOUND");
    const memberIds = saff.get("memberIds") as string[];
    if (!memberIds.includes(uid)) throw new AppError("NOT_PARTICIPANT");
    if (memberIds.length !== 2) throw new AppError("PLANT_PAIRS_ONLY");
    const other = memberIds.find((m) => m !== uid)!;

    const planned = await saffRef.collection("occurrences").where("status", "==", "planned").get();
    const next = planned.docs
      .filter(
        (d) =>
          (d.get("requiredIds") as string[]).includes(uid) &&
          (d.get("requiredIds") as string[]).includes(other) &&
          (d.get("ringAt") as Timestamp).toMillis() > Date.now(),
      )
      .sort((a, b) => (a.get("ringAt") as Timestamp).toMillis() - (b.get("ringAt") as Timestamp).toMillis())[0];
    if (!next) throw new AppError("ROUND_LOCKED");

    let card: Record<string, unknown>;
    if (input.template === "askMe") {
      card = { type: "ask", question: input.question, answer: "" };
    } else if (input.template === "quiz") {
      if (!input.answer) throw new AppError("INVALID_ARGUMENT", { field: "answer" });
      card = { type: "typed", question: input.question, answer: input.answer, accept: [input.answer] };
    } else {
      if (!input.options || input.correctIndex === undefined) {
        throw new AppError("INVALID_ARGUMENT", { field: "options" });
      }
      card = {
        type: "choice",
        question: input.question,
        options: input.options,
        answer: input.options[input.correctIndex]!,
      };
    }

    await db.runTransaction(async (tx) => {
      const plants = await tx.get(next.ref.collection("plants").where("authorId", "==", uid));
      if (plants.size >= c.plantsPerNight) throw new AppError("PLANT_LIMIT");
      const n = plants.size + 1;
      const id = `${next.id}_${uid}_${n}`;
      tx.set(next.ref.collection("plants").doc(id), {
        authorId: uid,
        template: input.template,
        card: { ...card, id: `plant_${id}`, category: "planted", difficulty: "medium" },
        createdAt: FieldValue.serverTimestamp(),
      });
      tx.update(next.ref, {
        [`plantCounts.${uid}`]: n,
        teaserFor: FieldValue.arrayUnion(other),
      });
    });
    return { occurrenceId: next.id, left: c.plantsPerNight - (await countPlants(next.ref, uid)) };
  },
);

async function countPlants(
  occRef: FirebaseFirestore.DocumentReference,
  uid: string,
): Promise<number> {
  return (await occRef.collection("plants").where("authorId", "==", uid).get()).size;
}
