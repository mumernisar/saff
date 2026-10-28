"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.handleBudgetMessage = handleBudgetMessage;
const firestore_1 = require("firebase-admin/firestore");
const contracts_1 = require("../../contracts");
const logger_1 = require("../../core/logger");
const billing_cap_1 = require("../../domain/billing_cap");
/**
 * Handles one budget notification. Writes `config/backend.status` first so
 * clients can tell why functions stopped, then unlinks billing. Safe to
 * repeat (docs/ARCHITECTURE.md section 9a).
 */
async function handleBudgetMessage(raw, deps) {
    const message = (0, billing_cap_1.parseBudgetMessage)(raw);
    if (message === null) {
        logger_1.log.warn("budget_message_invalid");
        return "ignored";
    }
    const enabled = await deps.billing.isBillingEnabled(deps.projectId);
    const decision = (0, billing_cap_1.decideCap)(message, contracts_1.PRODUCTION_CONSTANTS.billingCapUsd, enabled);
    if (decision === "ignore")
        return "ignored";
    await deps.db.doc("config/backend").set({ status: "billingDisabled", updatedAt: firestore_1.FieldValue.serverTimestamp() }, { merge: true });
    await deps.billing.disableBilling(deps.projectId);
    logger_1.log.error("billing_disabled", { costAmount: message.costAmount });
    return "disabled";
}
//# sourceMappingURL=cap_billing.js.map