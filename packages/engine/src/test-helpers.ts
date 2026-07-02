import { createAndMigrateDb } from "./db/index.js";
import { seedMeals } from "./db/seed.js";
import { seedTraining } from "./training/seed.js";
import { seedFactors } from "./factors/seed.js";
import type { DB } from "./db/index.js";

export function setupTestDb(): DB {
  const db = createAndMigrateDb(":memory:");
  seedMeals(db);
  seedTraining(db);
  seedFactors(db);
  return db;
}
