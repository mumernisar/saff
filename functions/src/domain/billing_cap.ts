/** The part of a Cloud Billing budget notification the cap needs. */
export interface BudgetMessage {
  readonly costAmount: number;
}

/** What the cap should do for a budget message. */
export type CapDecision = "ignore" | "disable";

/**
 * Pure decision (docs/ARCHITECTURE.md section 9a): disable billing once
 * spend passes the cap; ignore everything else, including repeats once
 * billing is already off.
 */
export function decideCap(
  message: BudgetMessage,
  capUsd: number,
  billingEnabled: boolean,
): CapDecision {
  if (!billingEnabled) return "ignore";
  return message.costAmount >= capUsd ? "disable" : "ignore";
}

/** Parses the JSON payload of a budget notification, or null if invalid. */
export function parseBudgetMessage(raw: unknown): BudgetMessage | null {
  if (typeof raw !== "object" || raw === null) return null;
  const cost = (raw as Record<string, unknown>).costAmount;
  return typeof cost === "number" && Number.isFinite(cost)
    ? { costAmount: cost }
    : null;
}
