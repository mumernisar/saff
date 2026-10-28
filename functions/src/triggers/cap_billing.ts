import { getFirestore } from "firebase-admin/firestore";
import { initializeApp, getApps } from "firebase-admin/app";
import { onMessagePublished } from "firebase-functions/v2/pubsub";
import { CloudBillingApi } from "../features/billing/billing_client";
import { handleBudgetMessage } from "../features/billing/cap_billing";

if (getApps().length === 0) initializeApp();

/** Cloud Billing budget notifications; unlinks billing past the cap. */
export const capBilling = onMessagePublished(
  { topic: "billing-budget", region: "us-central1" },
  async (event) => {
    await handleBudgetMessage(event.data.message.json, {
      db: getFirestore(),
      billing: new CloudBillingApi(),
      projectId: process.env.GCLOUD_PROJECT ?? "",
    });
  },
);
