import { getApps, initializeApp } from "firebase-admin/app";
import { getFirestore, type Firestore } from "firebase-admin/firestore";
import { onCall, type CallableRequest } from "firebase-functions/v2/https";
import type { ZodType } from "zod";
import { AppError, toHttpsError } from "./errors";
import { log } from "./logger";

if (getApps().length === 0) initializeApp();

/** The shared Firestore handle. */
export const db: Firestore = getFirestore();

/** What every callable handler receives. */
export interface Ctx {
  readonly uid: string;
  readonly db: Firestore;
}

/**
 * Builds a callable: auth required, input validated by [schema], failures
 * converted to catalog errors (docs/BACKEND.md section 1).
 */
export function callable<I, O>(
  name: string,
  schema: ZodType<I>,
  handler: (input: I, ctx: Ctx) => Promise<O>,
) {
  return onCall(
    { region: "us-central1", maxInstances: 5, enforceAppCheck: false },
    async (request: CallableRequest) => {
      try {
        const uid = request.auth?.uid;
        if (!uid) throw new AppError("UNAUTHENTICATED");
        const parsed = schema.safeParse(request.data ?? {});
        if (!parsed.success) {
          throw new AppError("INVALID_ARGUMENT", {
            field: parsed.error.issues[0]?.path.join(".") ?? "",
          });
        }
        return await handler(parsed.data, { uid, db });
      } catch (e) {
        const mapped = toHttpsError(e);
        if (!(e instanceof AppError)) {
          log.error("callable_failed", { fn: name, error: String(e) });
        }
        throw mapped;
      }
    },
  );
}
