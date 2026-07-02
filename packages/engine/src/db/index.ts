import Database from "better-sqlite3";
import { drizzle } from "drizzle-orm/better-sqlite3";
import { migrate } from "drizzle-orm/better-sqlite3/migrator";
import * as coreSchema from "./schema.js";
import * as trainingSchema from "../training/schema.js";

// Merge core + training tables into a single schema namespace.
const schema = { ...coreSchema, ...trainingSchema };

export type DB = ReturnType<typeof createDb>;

export function createDb(path: string = ":memory:") {
  const sqlite = new Database(path);
  sqlite.pragma("journal_mode = WAL");
  sqlite.pragma("foreign_keys = ON");
  const db = drizzle(sqlite, { schema });
  return db;
}

export function createAndMigrateDb(path: string = ":memory:"): DB {
  const db = createDb(path);
  const migrationsFolder = new URL("../../drizzle", import.meta.url).pathname;
  migrate(db, { migrationsFolder });
  return db;
}

export { schema };
