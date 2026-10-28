"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.CloudBillingApi = void 0;
const billing_1 = require("@google-cloud/billing");
/** Cloud Billing API implementation. */
class CloudBillingApi {
    client = new billing_1.CloudBillingClient();
    async isBillingEnabled(projectId) {
        const [info] = await this.client.getProjectBillingInfo({
            name: `projects/${projectId}`,
        });
        return info.billingEnabled === true;
    }
    async disableBilling(projectId) {
        await this.client.updateProjectBillingInfo({
            name: `projects/${projectId}`,
            projectBillingInfo: { billingAccountName: "" },
        });
    }
}
exports.CloudBillingApi = CloudBillingApi;
//# sourceMappingURL=billing_client.js.map