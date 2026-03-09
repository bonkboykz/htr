import { eq, and, lte, desc } from "drizzle-orm";
import type { DB } from "../db/index.js";
import { schema } from "../db/index.js";
import { newId } from "../id.js";
import type { DailyTarget } from "../types.js";

export function setTarget(
  db: DB,
  data: {
    effectiveDate: string;
    calories: number;
    protein: number;
    fat: number;
    carbs: number;
    waterMl?: number;
    sleepMinutes?: number;
  }
): DailyTarget {
  const id = newId();
  const row = {
    id,
    effectiveDate: data.effectiveDate,
    calories: data.calories,
    protein: data.protein,
    fat: data.fat,
    carbs: data.carbs,
    waterMl: data.waterMl ?? 2500,
    sleepMinutes: data.sleepMinutes ?? 480,
  };
  db.insert(schema.dailyTargets).values(row).run();
  return db
    .select()
    .from(schema.dailyTargets)
    .where(eq(schema.dailyTargets.id, id))
    .get()! as DailyTarget;
}

export function getActiveTarget(db: DB, date: string): DailyTarget | null {
  const result = db
    .select()
    .from(schema.dailyTargets)
    .where(
      and(
        lte(schema.dailyTargets.effectiveDate, date),
        eq(schema.dailyTargets.isDeleted, 0)
      )
    )
    .orderBy(desc(schema.dailyTargets.effectiveDate))
    .limit(1)
    .get();
  return (result as DailyTarget) ?? null;
}

export function listTargets(db: DB): DailyTarget[] {
  return db
    .select()
    .from(schema.dailyTargets)
    .where(eq(schema.dailyTargets.isDeleted, 0))
    .orderBy(desc(schema.dailyTargets.effectiveDate))
    .all() as DailyTarget[];
}
