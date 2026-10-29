import type { Constants } from "../../contracts";

/** What the server knows about a user's subscription. */
export interface Subscription {
  /** Play state: ACTIVE, IN_GRACE_PERIOD, EXPIRED, REVOKED. */
  readonly state: "ACTIVE" | "IN_GRACE_PERIOD" | "EXPIRED" | "REVOKED";
  readonly expiresAtMs: number;
  readonly productId: string;
}

/** The stored entitlement (docs/DATA_MODEL.md `users/{uid}/entitlement`). */
export interface Entitlement {
  readonly plan: "free" | "plus";
  readonly status: "active" | "grace" | "expired" | "none";
  readonly graceUntilMs?: number;
  readonly limits: {
    readonly maxOwnedSaffSize: number;
    readonly maxSaffs: number;
    readonly statsHistoryDays: number;
    readonly imports: boolean;
    readonly cosmetics: boolean;
  };
}

/** Limits of the free plan. */
export function freeLimits(c: Constants): Entitlement["limits"] {
  return {
    maxOwnedSaffSize: c.maxSaffSizeFree,
    maxSaffs: c.maxSaffsPerUserFree,
    statsHistoryDays: c.statsHistoryFreeDays,
    imports: false,
    cosmetics: false,
  };
}

/** Computes the entitlement for [sub] at [nowMs] (docs/BACKEND.md section 8). */
export function computeEntitlement(sub: Subscription | null, nowMs: number, c: Constants): Entitlement {
  const free: Entitlement = { plan: "free", status: "none", limits: freeLimits(c) };
  if (!sub || sub.state === "REVOKED") return free;
  const plus: Entitlement["limits"] = {
    maxOwnedSaffSize: c.maxSaffSizePlus,
    maxSaffs: c.maxSaffsPerUserPlus,
    statsHistoryDays: 36500,
    imports: true,
    cosmetics: true,
  };
  if (sub.state === "ACTIVE" && sub.expiresAtMs > nowMs) return { plan: "plus", status: "active", limits: plus };
  if (sub.state === "IN_GRACE_PERIOD") return { plan: "plus", status: "grace", graceUntilMs: sub.expiresAtMs, limits: plus };
  const graceUntil = sub.expiresAtMs + c.plusGraceDays * 86_400_000;
  if (nowMs < graceUntil) return { plan: "plus", status: "grace", graceUntilMs: graceUntil, limits: plus };
  return { plan: "free", status: "expired", limits: freeLimits(c) };
}
