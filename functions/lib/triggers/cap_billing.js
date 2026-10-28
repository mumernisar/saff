"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.capBilling = void 0;
const firestore_1 = require("firebase-admin/firestore");
const app_1 = require("firebase-admin/app");
const pubsub_1 = require("firebase-functions/v2/pubsub");
const billing_client_1 = require("../features/billing/billing_client");
const cap_billing_1 = require("../features/billing/cap_billing");
if ((0, app_1.getApps)().length === 0)
    (0, app_1.initializeApp)();
/** Cloud Billing budget notifications; unlinks billing past the cap. */
exports.capBilling = (0, pubsub_1.onMessagePublished)({ topic: "billing-budget", region: "us-central1" }, async (event) => {
    await (0, cap_billing_1.handleBudgetMessage)(event.data.message.json, {
        db: (0, firestore_1.getFirestore)(),
        billing: new billing_client_1.CloudBillingApi(),
        projectId: process.env.GCLOUD_PROJECT ?? "",
    });
});
//# sourceMappingURL=cap_billing.js.map