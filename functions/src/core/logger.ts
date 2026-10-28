import { logger } from "firebase-functions";

/** Fields every log entry may carry. */
export interface LogFields {
  readonly saffId?: string;
  readonly occurrenceId?: string;
  readonly requestId?: string;
  readonly code?: string;
}

/** Keys that must never be logged (docs/ERRORS.md section 9). */
const REDACTED = new Set(["message", "text", "answer", "name", "phone", "email", "token", "fcmToken"]);

function redact(fields: Record<string, unknown>): Record<string, unknown> {
  return Object.fromEntries(
    Object.entries(fields).map(([k, v]) => [k, REDACTED.has(k) ? "[redacted]" : v]),
  );
}

/** Structured logging with the standard fields and redaction. */
export const log = {
  info: (event: string, fields: LogFields & Record<string, unknown> = {}) =>
    logger.info(event, { event, ...redact(fields) }),
  warn: (event: string, fields: LogFields & Record<string, unknown> = {}) =>
    logger.warn(event, { event, ...redact(fields) }),
  error: (event: string, fields: LogFields & Record<string, unknown> = {}) =>
    logger.error(event, { event, ...redact(fields) }),
};
