import { defineConfig } from "drizzle-kit";

export default defineConfig({
  schema: [
    "./src/db/schema.ts",
    "./src/training/schema.ts",
    "./src/factors/schema.ts",
  ],
  out: "./drizzle",
  dialect: "sqlite",
});
