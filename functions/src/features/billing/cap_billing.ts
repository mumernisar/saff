import type { Firestore } from "firebase-admin/firestore";
import { FieldValue } from "firebase-admin/firestore";
import { PRODUCTION_CONSTANTS } from "../../contracts";
import { log } from "../../core/logger";
import { decideCap, parseBudgetMessage } from "../../domain/billing_cap";
import type { BillingClient } from "./billing_client";

/**
 * Handles one budget notification. Writes `config/backend.status` first so
 * clients can tell why functions stopped, then unlinks billing. Safe to
 * repeat (docs/ARCHITECTURE.md section 9a).
 */
export async function handleBudgetMessage(
  raw: unknown,
  deps: { db: Firestore; billing: BillingClient; projectId: string },
): Promise<"ignored" | "disabled"> {
  const message = parseBudgetMessage(raw);
  if (message === null) {
    log.warn("budget_message_invalid");
    return "ignored";
  }
  const enabled = await deps.billing.isBillingEnabled(deps.projectId);
  const decision = decideCap(message, PRODUCTION_CONSTANTS.billingCapUsd, enabled);
  if (decision === "ignore") return "ignored";

  await deps.db.doc("config/backend").set(
    { status: "billingDisabled", updatedAt: FieldValue.serverTimestamp() },
    { merge: true },
  );
  await deps.billing.disableBilling(deps.projectId);
  log.error("billing_disabled", { costAmount: message.costAmount });
  return "disabled";
}
