"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AppError = void 0;
exports.toHttpsError = toHttpsError;
const https_1 = require("firebase-functions/v2/https");
const contracts_1 = require("../contracts");
/** A failure from the shared catalog (docs/ERRORS.md section 10). */
class AppError extends Error {
    code;
    details;
    constructor(code, details = {}) {
        super(code);
        this.code = code;
        this.details = details;
        this.name = "AppError";
    }
}
exports.AppError = AppError;
/**
 * Converts any thrown value to an HttpsError the client mapper understands.
 * Unexpected errors become SERVER_INTERNAL; nothing internal leaks out.
 */
function toHttpsError(error) {
    if (error instanceof https_1.HttpsError)
        return error;
    const code = error instanceof AppError ? error.code : "SERVER_INTERNAL";
    const entry = contracts_1.ERROR_CATALOG[code];
    const https = (entry.httpsCode ?? "internal");
    const details = error instanceof AppError ? error.details : {};
    return new https_1.HttpsError(https, code, { code, ...details });
}
//# sourceMappingURL=errors.js.map