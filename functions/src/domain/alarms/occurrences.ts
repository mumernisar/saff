import { dateKey, isoWeekday, localFields, zonedToUtc } from "./time";

/** The parts of an alarm the planner needs. */
export interface AlarmSpec {
  readonly time: string; // HH:mm
  readonly days: readonly number[]; // ISO 1-7
  readonly timezone: string;
  readonly activeFrom?: string; // yyyy-MM-dd
}

/** One planned ring moment. */
export interface PlannedRing {
  readonly date: string; // yyyyMMdd, local date in the alarm's timezone
  readonly ringAtMs: number;
}

/**
 * Ring moments of [alarm] whose instant lies in [fromMs, toMs], in order.
 * Deterministic: the same inputs give the same list (DST handled by Intl).
 */
export function ringMoments(
  alarm: AlarmSpec,
  fromMs: number,
  toMs: number,
): PlannedRing[] {
  const [hh, mm] = alarm.time.split(":").map(Number) as [number, number];
  const out: PlannedRing[] = [];
  const start = localFields(fromMs - 36 * 3600_000, alarm.timezone);
  const activeFromMs = alarm.activeFrom
    ? Date.parse(`${alarm.activeFrom}T00:00:00Z`)
    : Number.NEGATIVE_INFINITY;
  const days = Math.ceil((toMs - fromMs) / 86_400_000) + 3;
  for (let i = 0; i < days; i++) {
    const d = new Date(Date.UTC(start.year, start.month - 1, start.day + i));
    const y = d.getUTCFullYear();
    const m = d.getUTCMonth() + 1;
    const day = d.getUTCDate();
    if (!alarm.days.includes(isoWeekday(y, m, day))) continue;
    if (d.getTime() < activeFromMs) continue;
    const at = zonedToUtc(y, m, day, hh, mm, alarm.timezone);
    if (at < fromMs || at > toMs) continue;
    out.push({ date: dateKey(y, m, day), ringAtMs: at });
  }
  return out.sort((a, b) => a.ringAtMs - b.ringAtMs);
}

/** A user's alarm, for conflict checks. */
export interface ConflictAlarm extends AlarmSpec {
  readonly id: string;
  readonly label: string;
}

/**
 * The first existing alarm whose ring moment is closer than [windowMs] to a
 * ring moment of [candidate], over the next [horizonDays] days; null if none.
 * [ignoreId] skips the alarm being changed.
 */
export function findConflict(
  candidate: AlarmSpec,
  existing: readonly ConflictAlarm[],
  nowMs: number,
  windowMs: number,
  horizonDays = 14,
  ignoreId?: string,
): ConflictAlarm | null {
  const to = nowMs + horizonDays * 86_400_000;
  const mine = ringMoments(candidate, nowMs, to);
  for (const other of existing) {
    if (other.id === ignoreId) continue;
    const theirs = ringMoments(other, nowMs, to);
    for (const a of mine) {
      for (const b of theirs) {
        if (Math.abs(a.ringAtMs - b.ringAtMs) < windowMs) return other;
      }
    }
  }
  return null;
}
