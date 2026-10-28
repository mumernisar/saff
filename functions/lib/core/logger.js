"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.log = void 0;
const firebase_functions_1 = require("firebase-functions");
/** Keys that must never be logged (docs/ERRORS.md section 9). */
const REDACTED = new Set(["message", "text", "answer", "name", "phone", "email", "token", "fcmToken"]);
function redact(fields) {
    return Object.fromEntries(Object.entries(fields).map(([k, v]) => [k, REDACTED.has(k) ? "[redacted]" : v]));
}
/** Structured logging with the standard fields and redaction. */
exports.log = {
    info: (event, fields = {}) => firebase_functions_1.logger.info(event, { event, ...redact(fields) }),
    warn: (event, fields = {}) => firebase_functions_1.logger.warn(event, { event, ...redact(fields) }),
    error: (event, fields = {}) => firebase_functions_1.logger.error(event, { event, ...redact(fields) }),
};
//# sourceMappingURL=logger.js.map