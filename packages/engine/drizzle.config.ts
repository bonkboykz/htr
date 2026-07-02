import { defineConfig } from "drizzle-kit";

export default defineConfig({
  schema: ["./src/db/schema.ts", "./src/training/schema.ts"],
  out: "./drizzle",
  dialect: "sqlite",
});
