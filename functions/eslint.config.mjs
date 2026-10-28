import js from "@eslint/js";
import tseslint from "typescript-eslint";

export default tseslint.config(
  { ignores: ["lib/**", "node_modules/**", "src/contracts/*.generated.ts"] },
  js.configs.recommended,
  ...tseslint.configs.recommended,
);
