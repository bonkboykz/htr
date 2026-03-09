import { migrate } from "drizzle-orm/better-sqlite3/migrator";
import { createDb } from "./index.js";

const dbPath = process.env.DATABASE_PATH || "htr.db";
const db = createDb(dbPath);
migrate(db, { migrationsFolder: new URL("../../drizzle", import.meta.url).pathname });
console.log("Migrations applied successfully.");
