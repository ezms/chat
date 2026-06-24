import tseslint from "@typescript-eslint/eslint-plugin";
import tsparser from "@typescript-eslint/parser";
import sveltePlugin from "eslint-plugin-svelte";
import prettier from "eslint-config-prettier";

export default [
    {
        files: ["src/**/*.ts"],
        languageOptions: { parser: tsparser },
        plugins: { "@typescript-eslint": tseslint },
        rules: { ...tseslint.configs.recommended.rules },
    },
    ...sveltePlugin.configs["flat/recommended"],
    prettier,
];
