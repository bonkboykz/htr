import { eq, and } from "drizzle-orm";
import type { DB } from "../db/index.js";
import { schema } from "../db/index.js";
import { newId } from "../id.js";
import { getActiveTarget } from "../targets/engine.js";
import type { WaterLogEntry } from "../types.js";

export function logWater(
  db: DB,
  data: { date: string; amountMl: number }
): WaterLogEntry {
  const id = newId();
  db.insert(schema.waterLogs)
    .values({ id, date: data.date, amountMl: data.amountMl })
    .run();
  return db
    .select()
    .from(schema.waterLogs)
    .where(eq(schema.waterLogs.id, id))
    .get()! as WaterLogEntry;
}

export function deleteWaterLog(db: DB, id: string): void {
  db.update(schema.waterLogs)
    .set({ isDeleted: 1 })
    .where(eq(schema.waterLogs.id, id))
    .run();
}

export function getDailyWater(
  db: DB,
  date: string
): { totalMl: number; targetMl: number; entries: WaterLogEntry[] } {
  const entries = db
    .select()
    .from(schema.waterLogs)
    .where(
      and(eq(schema.waterLogs.date, date), eq(schema.waterLogs.isDeleted, 0))
    )
    .all() as WaterLogEntry[];

  const totalMl = entries.reduce((sum, e) => sum + e.amountMl, 0);
  const target = getActiveTarget(db, date);
  const targetMl = target?.waterMl ?? 2500;

  return { totalMl, targetMl, entries };
}
