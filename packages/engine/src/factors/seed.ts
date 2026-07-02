import { eq } from "drizzle-orm";
import type { DB } from "../db/index.js";
import { schema } from "../db/index.js";

const SYSTEM_CATEGORIES = [
  { id: "cat-mood", name: "Настроение", emoji: "😊", sortOrder: 1, isSystem: 1 },
  { id: "cat-symptoms", name: "Симптомы", emoji: "🤒", sortOrder: 2, isSystem: 1 },
  { id: "cat-habits", name: "Привычки", emoji: "✅", sortOrder: 3, isSystem: 1 },
  { id: "cat-meds", name: "Лекарства", emoji: "💊", sortOrder: 4, isSystem: 1 },
  { id: "cat-other", name: "Другое", emoji: "📝", sortOrder: 5, isSystem: 1 },
] as const;

// A few sensible defaults so correlations have something to chew on out of the box.
const DEFAULT_FACTORS = [
  { id: "factor-energy", categoryId: "cat-mood", name: "Энергия", scaleMin: 1, scaleMax: 5, labels: null, unit: null },
  {
    id: "factor-mood",
    categoryId: "cat-mood",
    name: "Настроение",
    scaleMin: 1,
    scaleMax: 5,
    labels: JSON.stringify({ "1": "Ужасно", "3": "Норм", "5": "Отлично" }),
    unit: null,
  },
  { id: "factor-stress", categoryId: "cat-mood", name: "Стресс", scaleMin: 0, scaleMax: 5, labels: null, unit: null },
  { id: "factor-headache", categoryId: "cat-symptoms", name: "Головная боль", scaleMin: 0, scaleMax: 5, labels: null, unit: null },
  { id: "factor-alcohol", categoryId: "cat-habits", name: "Алкоголь", scaleMin: 0, scaleMax: 5, labels: null, unit: "порций" },
  { id: "factor-caffeine", categoryId: "cat-habits", name: "Кофеин", scaleMin: 0, scaleMax: 5, labels: null, unit: "чашек" },
] as const;

export function seedFactors(db: DB): void {
  for (const cat of SYSTEM_CATEGORIES) {
    const existing = db
      .select()
      .from(schema.factorCategories)
      .where(eq(schema.factorCategories.id, cat.id))
      .get();
    if (!existing) {
      db.insert(schema.factorCategories).values(cat).run();
    }
  }

  for (const f of DEFAULT_FACTORS) {
    const existing = db
      .select()
      .from(schema.factors)
      .where(eq(schema.factors.id, f.id))
      .get();
    if (!existing) {
      db.insert(schema.factors).values(f).run();
    }
  }
}
