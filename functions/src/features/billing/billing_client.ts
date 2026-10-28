import { CloudBillingClient } from "@google-cloud/billing";

/** The two Cloud Billing calls the cap needs; swappable for a fake. */
export interface BillingClient {
  isBillingEnabled(projectId: string): Promise<boolean>;
  disableBilling(projectId: string): Promise<void>;
}

/** Cloud Billing API implementation. */
export class CloudBillingApi implements BillingClient {
  private readonly client = new CloudBillingClient();

  async isBillingEnabled(projectId: string): Promise<boolean> {
    const [info] = await this.client.getProjectBillingInfo({
      name: `projects/${projectId}`,
    });
    return info.billingEnabled === true;
  }

  async disableBilling(projectId: string): Promise<void> {
    await this.client.updateProjectBillingInfo({
      name: `projects/${projectId}`,
      projectBillingInfo: { billingAccountName: "" },
    });
  }
}
