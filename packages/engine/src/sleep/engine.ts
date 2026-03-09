import { eq, and, gte, lte, desc } from "drizzle-orm";
import type { DB } from "../db/index.js";
import { schema } from "../db/index.js";
import { newId } from "../id.js";
import type { SleepLogEntry } from "../types.js";

export function logSleep(
  db: DB,
  data: {
    startTime: string;
    endTime: string;
    quality?: number;
    note?: string;
  }
): SleepLogEntry {
  const id = newId();
  db.insert(schema.sleepLogs)
    .values({
      id,
      startTime: data.startTime,
      endTime: data.endTime,
      quality: data.quality ?? null,
      note: data.note ?? null,
    })
    .run();
  return db
    .select()
    .from(schema.sleepLogs)
    .where(eq(schema.sleepLogs.id, id))
    .get()! as SleepLogEntry;
}

export function deleteSleepLog(db: DB, id: string): void {
  db.update(schema.sleepLogs)
    .set({ isDeleted: 1 })
    .where(eq(schema.sleepLogs.id, id))
    .run();
}

function getSleepDurationMinutes(entry: SleepLogEntry): number {
  const start = new Date(entry.startTime).getTime();
  const end = new Date(entry.endTime).getTime();
  return Math.round((end - start) / 60000);
}

export function getSleepForDate(db: DB, date: string): SleepLogEntry[] {
  // Attribute sleep to wake-up date: DATE(end_time)
  // end_time starts with date (YYYY-MM-DD)
  const dayStart = `${date}T00:00:00`;
  const dayEnd = `${date}T23:59:59`;

  return db
    .select()
    .from(schema.sleepLogs)
    .where(
      and(
        gte(schema.sleepLogs.endTime, dayStart),
        lte(schema.sleepLogs.endTime, dayEnd),
        eq(schema.sleepLogs.isDeleted, 0)
      )
    )
    .all() as SleepLogEntry[];
}

export function getSleepTrend(
  db: DB,
  days: number = 7
): { date: string; totalMinutes: number; quality: number | null }[] {
  const results: { date: string; totalMinutes: number; quality: number | null }[] = [];

  for (let i = 0; i < days; i++) {
    const d = new Date();
    d.setDate(d.getDate() - i);
    const date = d.toISOString().split("T")[0];
    const entries = getSleepForDate(db, date);

    const totalMinutes = entries.reduce(
      (sum, e) => sum + getSleepDurationMinutes(e),
      0
    );

    const qualities = entries
      .map((e) => e.quality)
      .filter((q): q is number => q !== null);
    const quality =
      qualities.length > 0
        ? Math.round(qualities.reduce((a, b) => a + b, 0) / qualities.length)
        : null;

    results.push({ date, totalMinutes, quality });
  }

  return results;
}

export { getSleepDurationMinutes };
