"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.db = void 0;
exports.callable = callable;
const app_1 = require("firebase-admin/app");
const firestore_1 = require("firebase-admin/firestore");
const https_1 = require("firebase-functions/v2/https");
const errors_1 = require("./errors");
const logger_1 = require("./logger");
if ((0, app_1.getApps)().length === 0)
    (0, app_1.initializeApp)();
/** The shared Firestore handle. */
exports.db = (0, firestore_1.getFirestore)();
/**
 * Builds a callable: auth required, input validated by [schema], failures
 * converted to catalog errors (docs/BACKEND.md section 1).
 */
function callable(name, schema, handler) {
    return (0, https_1.onCall)({ region: "us-central1", maxInstances: 5, enforceAppCheck: false }, async (request) => {
        try {
            const uid = request.auth?.uid;
            if (!uid)
                throw new errors_1.AppError("UNAUTHENTICATED");
            const parsed = schema.safeParse(request.data ?? {});
            if (!parsed.success) {
                throw new errors_1.AppError("INVALID_ARGUMENT", {
                    field: parsed.error.issues[0]?.path.join(".") ?? "",
                });
            }
            return await handler(parsed.data, { uid, db: exports.db });
        }
        catch (e) {
            const mapped = (0, errors_1.toHttpsError)(e);
            if (!(e instanceof errors_1.AppError)) {
                logger_1.log.error("callable_failed", { fn: name, error: String(e) });
            }
            throw mapped;
        }
    });
}
//# sourceMappingURL=callable.js.map