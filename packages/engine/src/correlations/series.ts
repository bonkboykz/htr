import { eq, and, gte, lte } from "drizzle-orm";
import type { DB } from "../db/index.js";
import { schema } from "../db/index.js";
import type { DataSeries, CorrelationSource } from "../types.js";
import { listFactors } from "../factors/engine.js";

// Fixed HTR (non-factor) sources. Each is a real per-date aggregation — days with
// no data are omitted (missing ≠ zero), which matters for correct correlation.
export const HTR_SOURCES: { id: string; label: string }[] = [
  { id: "htr:calories", label: "Калории" },
  { id: "htr:protein", label: "Белок" },
  { id: "htr:fat", label: "Жир" },
  { id: "htr:carbs", label: "Углеводы" },
  { id: "htr:water-ml", label: "Вода (мл)" },
  { id: "htr:sleep-minutes", label: "Сон (мин)" },
  { id: "htr:weight-grams", label: "Вес (г)" },
  { id: "htr:training-volume", label: "Объём тренировок" },
];

const NUTRITION_FIELDS: Record<string, "calories" | "protein" | "fat" | "carbs"> = {
  "htr:calories": "calories",
  "htr:protein": "protein",
  "htr:fat": "fat",
  "htr:carbs": "carbs",
};

function sumByDate(
  rows: { date: string; value: number }[],
): { date: string; value: number }[] {
  const acc = new Map<string, number>();
  for (const r of rows) acc.set(r.date, (acc.get(r.date) ?? 0) + r.value);
  return [...acc.entries()]
    .map(([date, value]) => ({ date, value }))
    .sort((a, b) => a.date.localeCompare(b.date));
}

export function getDataSeries(
  db: DB,
  source: string,
  from: string,
  to: string,
): DataSeries {
  // factor:{id}
  if (source.startsWith("factor:")) {
    const factorId = source.slice("factor:".length);
    const rows = db
      .select({ date: schema.factorLogs.date, value: schema.factorLogs.value })
      .from(schema.factorLogs)
      .where(
        and(
          eq(schema.factorLogs.factorId, factorId),
          eq(schema.factorLogs.isDeleted, 0),
          gte(schema.factorLogs.date, from),
          lte(schema.factorLogs.date, to),
        ),
      )
      .all() as { date: string; value: number }[];
    // one log per (date,factor) → no summing needed, but sort
    return {
      source,
      points: rows.slice().sort((a, b) => a.date.localeCompare(b.date)),
    };
  }

  // htr:calories | protein | fat | carbs
  const nutritionField = NUTRITION_FIELDS[source];
  if (nutritionField) {
    const rows = db
      .select({
        date: schema.foodLogs.date,
        value: schema.foodLogs[nutritionField],
      })
      .from(schema.foodLogs)
      .where(
        and(
          eq(schema.foodLogs.isDeleted, 0),
          gte(schema.foodLogs.date, from),
          lte(schema.foodLogs.date, to),
        ),
      )
      .all() as { date: string; value: number }[];
    return { source, points: sumByDate(rows) };
  }

  if (source === "htr:water-ml") {
    const rows = db
      .select({
        date: schema.waterLogs.date,
        value: schema.waterLogs.amountMl,
      })
      .from(schema.waterLogs)
      .where(
        and(
          eq(schema.waterLogs.isDeleted, 0),
          gte(schema.waterLogs.date, from),
          lte(schema.waterLogs.date, to),
        ),
      )
      .all() as { date: string; value: number }[];
    return { source, points: sumByDate(rows) };
  }

  if (source === "htr:sleep-minutes") {
    // Attributed to wake date = DATE(end_time).
    const rows = db
      .select()
      .from(schema.sleepLogs)
      .where(
        and(
          eq(schema.sleepLogs.isDeleted, 0),
          gte(schema.sleepLogs.endTime, `${from}T00:00:00`),
          lte(schema.sleepLogs.endTime, `${to}T23:59:59`),
        ),
      )
      .all() as { startTime: string; endTime: string }[];
    const points = rows.map((r) => ({
      date: r.endTime.slice(0, 10),
      value: Math.round(
        (new Date(r.endTime).getTime() - new Date(r.startTime).getTime()) /
          60000,
      ),
    }));
    return { source, points: sumByDate(points) };
  }

  if (source === "htr:weight-grams") {
    const rows = db
      .select({
        date: schema.weightLogs.date,
        value: schema.weightLogs.weightGrams,
      })
      .from(schema.weightLogs)
      .where(
        and(
          eq(schema.weightLogs.isDeleted, 0),
          gte(schema.weightLogs.date, from),
          lte(schema.weightLogs.date, to),
        ),
      )
      .all() as { date: string; value: number }[];
    // one weight per date (UNIQUE) — sort, no summing
    return {
      source,
      points: rows.slice().sort((a, b) => a.date.localeCompare(b.date)),
    };
  }

  if (source === "htr:training-volume") {
    const rows = db
      .select({
        startedAt: schema.workoutSessions.startedAt,
        weightG: schema.setLogs.weightG,
        reps: schema.setLogs.reps,
      })
      .from(schema.setLogs)
      .innerJoin(
        schema.workoutSessions,
        eq(schema.workoutSessions.id, schema.setLogs.sessionId),
      )
      .where(
        and(
          eq(schema.setLogs.isWarmup, 0),
          eq(schema.setLogs.isDeleted, 0),
          eq(schema.workoutSessions.isDeleted, 0),
        ),
      )
      .all() as { startedAt: string; weightG: number; reps: number }[];
    const points = rows
      .map((r) => ({ date: r.startedAt.slice(0, 10), value: r.weightG * r.reps }))
      .filter((p) => p.date >= from && p.date <= to);
    return { source, points: sumByDate(points) };
  }

  // Unknown source → empty series.
  return { source, points: [] };
}

export function listCorrelationSources(db: DB): CorrelationSource[] {
  const htr: CorrelationSource[] = HTR_SOURCES.map((s) => ({
    id: s.id,
    label: s.label,
    kind: "htr",
  }));
  const factorSources: CorrelationSource[] = listFactors(db).map((f) => ({
    id: `factor:${f.id}`,
    label: f.name,
    kind: "factor",
  }));
  return [...factorSources, ...htr];
}

// Human label for any source id (for insight sentences).
export function sourceLabel(db: DB, source: string): string {
  const found = listCorrelationSources(db).find((s) => s.id === source);
  return found?.label ?? source;
}
