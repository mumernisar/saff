import { getAuth } from "firebase-admin/auth";
import { z } from "zod";
import { callable, db } from "../../core/callable";
import { applyRemoval, planRemoval } from "../saffs/membership";

/**
 * Deletes the caller's account (docs/SECURITY.md section 6): leaves every
 * saff, removes the user's documents, then the Auth user. Messages stay and
 * show as "Deleted user"; they are not rewritten.
 */
export const deleteAccount = callable("deleteAccount", z.object({}), async (_input, { uid }) => {
  const user = await db.doc(`users/${uid}`).get();
  const saffIds = (user.get("saffIds") as string[] | undefined) ?? [];
  for (const saffId of saffIds) {
    await db.runTransaction(async (tx) => {
      const plan = await planRemoval(tx, db, saffId);
      if (!plan.memberIds.includes(uid)) return;
      applyRemoval(tx, db, plan, saffId, uid, "left");
    });
  }
  await db.recursiveDelete(db.doc(`users/${uid}`));
  await getAuth().deleteUser(uid);
  return { ok: true };
});
