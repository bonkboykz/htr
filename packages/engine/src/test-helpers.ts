import { createAndMigrateDb } from "./db/index.js";
import { seedMeals } from "./db/seed.js";
import type { DB } from "./db/index.js";

export function setupTestDb(): DB {
  const db = createAndMigrateDb(":memory:");
  seedMeals(db);
  return db;
}
