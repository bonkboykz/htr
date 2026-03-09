import { eq } from "drizzle-orm";
import { createDb, schema } from "./index.js";

const SYSTEM_MEALS = [
  { id: "meal-breakfast", name: "Breakfast", sortOrder: 1, isSystem: 1 },
  { id: "meal-lunch", name: "Lunch", sortOrder: 2, isSystem: 1 },
  { id: "meal-dinner", name: "Dinner", sortOrder: 3, isSystem: 1 },
  { id: "meal-snack", name: "Snack", sortOrder: 4, isSystem: 1 },
] as const;

export function seedMeals(db: ReturnType<typeof createDb>) {
  for (const meal of SYSTEM_MEALS) {
    const existing = db
      .select()
      .from(schema.meals)
      .where(eq(schema.meals.id, meal.id))
      .get();
    if (!existing) {
      db.insert(schema.meals).values(meal).run();
    }
  }
}

// CLI entry point
if (process.argv[1] && import.meta.url.endsWith(process.argv[1].replace(/.*\//, ""))) {
  const dbPath = process.env.DATABASE_PATH || "htr.db";
  const db = createDb(dbPath);
  seedMeals(db);
  console.log("Seed completed successfully.");
}
