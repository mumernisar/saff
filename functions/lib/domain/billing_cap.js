"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.decideCap = decideCap;
exports.parseBudgetMessage = parseBudgetMessage;
/**
 * Pure decision (docs/ARCHITECTURE.md section 9a): disable billing once
 * spend passes the cap; ignore everything else, including repeats once
 * billing is already off.
 */
function decideCap(message, capUsd, billingEnabled) {
    if (!billingEnabled)
        return "ignore";
    return message.costAmount >= capUsd ? "disable" : "ignore";
}
/** Parses the JSON payload of a budget notification, or null if invalid. */
function parseBudgetMessage(raw) {
    if (typeof raw !== "object" || raw === null)
        return null;
    const cost = raw.costAmount;
    return typeof cost === "number" && Number.isFinite(cost)
        ? { costAmount: cost }
        : null;
}
//# sourceMappingURL=billing_cap.js.map