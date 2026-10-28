import { HttpsError, type FunctionsErrorCode } from "firebase-functions/v2/https";
import { ERROR_CATALOG, type FailureCode } from "../contracts";

/** A failure from the shared catalog (docs/ERRORS.md section 10). */
export class AppError extends Error {
  constructor(
    readonly code: FailureCode,
    readonly details: Record<string, string | number | boolean> = {},
  ) {
    super(code);
    this.name = "AppError";
  }
}

/**
 * Converts any thrown value to an HttpsError the client mapper understands.
 * Unexpected errors become SERVER_INTERNAL; nothing internal leaks out.
 */
export function toHttpsError(error: unknown): HttpsError {
  if (error instanceof HttpsError) return error;
  const code: FailureCode =
    error instanceof AppError ? error.code : "SERVER_INTERNAL";
  const entry = ERROR_CATALOG[code];
  const https = (entry.httpsCode ?? "internal") as FunctionsErrorCode;
  const details = error instanceof AppError ? error.details : {};
  return new HttpsError(https, code, { code, ...details });
}
