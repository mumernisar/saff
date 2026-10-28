import { resolveConstants, type Constants } from "../contracts";

/**
 * Constants for this run. Demo timing applies only inside the Functions
 * emulator and only when DEMO_TIMING=true in functions/.env.local
 * (docs/DEV_RELAXATIONS.md R-1); a deployed function ignores it.
 */
export function currentConstants(
  env: NodeJS.ProcessEnv = process.env,
): Constants {
  return resolveConstants({
    allowDemo: env.FUNCTIONS_EMULATOR === "true",
    demoRequested: env.DEMO_TIMING === "true",
  });
}
