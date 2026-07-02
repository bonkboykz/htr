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
// Ratings use a bounded scale (chips); counts are unbounded tallies (stepper).
const DEFAULT_FACTORS = [
  { id: "factor-energy", categoryId: "cat-mood", name: "Энергия", kind: "rating", scaleMin: 1, scaleMax: 5, labels: null, unit: null },
  {
    id: "factor-mood",
    categoryId: "cat-mood",
    name: "Настроение",
    kind: "rating",
    scaleMin: 1,
    scaleMax: 5,
    labels: JSON.stringify({ "1": "Ужасно", "3": "Норм", "5": "Отлично" }),
    unit: null,
  },
  { id: "factor-stress", categoryId: "cat-mood", name: "Стресс", kind: "rating", scaleMin: 0, scaleMax: 5, labels: null, unit: null },
  { id: "factor-headache", categoryId: "cat-symptoms", name: "Головная боль", kind: "rating", scaleMin: 0, scaleMax: 5, labels: null, unit: null },
  { id: "factor-alcohol", categoryId: "cat-habits", name: "Алкоголь", kind: "count", scaleMin: 0, scaleMax: 0, labels: null, unit: "порций" },
  { id: "factor-caffeine", categoryId: "cat-habits", name: "Кофеин", kind: "count", scaleMin: 0, scaleMax: 0, labels: null, unit: "чашек" },
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
    } else {
      // System factors are engine-owned: keep their definition authoritative so
      // schema changes (e.g. count vs rating) propagate to existing DBs on redeploy.
      db.update(schema.factors)
        .set({
          kind: f.kind,
          scaleMin: f.scaleMin,
          scaleMax: f.scaleMax,
          unit: f.unit,
        })
        .where(eq(schema.factors.id, f.id))
        .run();
    }
  }
}
