import { getMessaging } from "firebase-admin/messaging";
import type { Firestore } from "firebase-admin/firestore";
import { log } from "../../core/logger";

/** Data-only push to every device of [uid]; failures are logged, never thrown. */
export async function pushToUser(
  db: Firestore,
  uid: string,
  data: Record<string, string>,
  options: { notification?: { title: string; body: string }; highPriority?: boolean } = {},
): Promise<void> {
  const devices = await db.collection(`users/${uid}/devices`).get();
  for (const d of devices.docs) {
    const token = d.get("fcmToken") as string;
    try {
      await getMessaging().send({
        token,
        data,
        ...(options.notification ? { notification: options.notification } : {}),
        android: {
          priority: options.highPriority === false ? "normal" : "high",
        },
      });
    } catch (e) {
      log.warn("push_failed", { uid, type: data.type, error: String(e) });
    }
  }
}
