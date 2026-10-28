"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.pushToUser = pushToUser;
const messaging_1 = require("firebase-admin/messaging");
const logger_1 = require("../../core/logger");
/** Data-only push to every device of [uid]; failures are logged, never thrown. */
async function pushToUser(db, uid, data, options = {}) {
    const devices = await db.collection(`users/${uid}/devices`).get();
    for (const d of devices.docs) {
        const token = d.get("fcmToken");
        try {
            await (0, messaging_1.getMessaging)().send({
                token,
                data,
                ...(options.notification ? { notification: options.notification } : {}),
                android: {
                    priority: options.highPriority === false ? "normal" : "high",
                },
            });
        }
        catch (e) {
            logger_1.log.warn("push_failed", { uid, type: data.type, error: String(e) });
        }
    }
}
//# sourceMappingURL=push.js.map