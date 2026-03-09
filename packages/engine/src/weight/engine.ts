import { eq, and, desc, gte } from "drizzle-orm";
import type { DB } from "../db/index.js";
import { schema } from "../db/index.js";
import { newId } from "../id.js";
import type { WeightLogEntry, WeightTrend } from "../types.js";

export function logWeight(
  db: DB,
  data: {
    date: string;
    weightGrams: number;
    bodyFat?: number;
    note?: string;
  }
): WeightLogEntry {
  const id = newId();
  db.insert(schema.weightLogs)
    .values({
      id,
      date: data.date,
      weightGrams: data.weightGrams,
      bodyFat: data.bodyFat ?? null,
      note: data.note ?? null,
    })
    .run();
  return db
    .select()
    .from(schema.weightLogs)
    .where(eq(schema.weightLogs.id, id))
    .get()! as WeightLogEntry;
}

export function deleteWeightLog(db: DB, id: string): void {
  db.update(schema.weightLogs)
    .set({ isDeleted: 1 })
    .where(eq(schema.weightLogs.id, id))
    .run();
}

export function getLatestWeight(db: DB): WeightLogEntry | null {
  return (
    (db
      .select()
      .from(schema.weightLogs)
      .where(eq(schema.weightLogs.isDeleted, 0))
      .orderBy(desc(schema.weightLogs.date))
      .limit(1)
      .get() as WeightLogEntry) ?? null
  );
}

export function getWeightEntries(db: DB, days: number = 30): WeightLogEntry[] {
  const fromDate = new Date();
  fromDate.setDate(fromDate.getDate() - days);
  const fromStr = fromDate.toISOString().split("T")[0];

  return db
    .select()
    .from(schema.weightLogs)
    .where(
      and(
        gte(schema.weightLogs.date, fromStr),
        eq(schema.weightLogs.isDeleted, 0)
      )
    )
    .orderBy(desc(schema.weightLogs.date))
    .all() as WeightLogEntry[];
}

export function getWeightTrend(db: DB, days: number = 30): WeightTrend {
  const entries = getWeightEntries(db, days);

  if (entries.length === 0) {
    return { entries, trendGrams: 0, changeGrams: 0 };
  }

  // EMA with alpha = 2/(N+1), using chronological order
  const sorted = [...entries].reverse();
  const alpha = 2 / (sorted.length + 1);
  let ema = sorted[0].weightGrams;
  for (let i = 1; i < sorted.length; i++) {
    ema = alpha * sorted[i].weightGrams + (1 - alpha) * ema;
  }

  const changeGrams =
    sorted[sorted.length - 1].weightGrams - sorted[0].weightGrams;

  return {
    entries,
    trendGrams: Math.round(ema),
    changeGrams,
  };
}
