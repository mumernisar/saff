"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.currentConstants = currentConstants;
const contracts_1 = require("../contracts");
/**
 * Constants for this run. Demo timing applies only inside the Functions
 * emulator and only when DEMO_TIMING=true in functions/.env.local
 * (docs/DEV_RELAXATIONS.md R-1); a deployed function ignores it.
 */
function currentConstants(env = process.env) {
    return (0, contracts_1.resolveConstants)({
        allowDemo: env.FUNCTIONS_EMULATOR === "true",
        demoRequested: env.DEMO_TIMING === "true",
    });
}
//# sourceMappingURL=config.js.map