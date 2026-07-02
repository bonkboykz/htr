import { eq, and, asc, desc } from "drizzle-orm";
import type { DB } from "../db/index.js";
import { schema } from "../db/index.js";
import { newId } from "../id.js";
import type {
  FactorCategory,
  Factor,
  FactorLog,
  FactorLogsForDate,
} from "../types.js";
import type {
  CreateCategoryInputT,
  CreateFactorInputT,
  LogFactorInputT,
  BulkLogFactorsInputT,
} from "./schemas.js";

// ---------- row helpers ----------

interface FactorRow extends Omit<Factor, "labels"> {
  labels: string | null;
}

function parseLabels(raw: string | null): Record<string, string> | null {
  if (!raw) return null;
  try {
    return JSON.parse(raw) as Record<string, string>;
  } catch {
    return null;
  }
}

function toFactor(row: FactorRow): Factor {
  return { ...row, labels: parseLabels(row.labels) };
}

// ---------- categories ----------

export function createCategory(
  db: DB,
  input: CreateCategoryInputT,
): FactorCategory {
  const id = newId();
  db.insert(schema.factorCategories)
    .values({
      id,
      name: input.name,
      emoji: input.emoji ?? null,
      sortOrder: input.sortOrder ?? 0,
    })
    .run();
  return db
    .select()
    .from(schema.factorCategories)
    .where(eq(schema.factorCategories.id, id))
    .get() as FactorCategory;
}

export function listCategories(db: DB): FactorCategory[] {
  return db
    .select()
    .from(schema.factorCategories)
    .where(eq(schema.factorCategories.isDeleted, 0))
    .orderBy(asc(schema.factorCategories.sortOrder))
    .all() as FactorCategory[];
}

export function deleteCategory(db: DB, id: string): void {
  db.update(schema.factorCategories)
    .set({ isDeleted: 1 })
    .where(eq(schema.factorCategories.id, id))
    .run();
}

// ---------- factors ----------

export function createFactor(db: DB, input: CreateFactorInputT): Factor {
  const scaleMin = input.scaleMin ?? 0;
  const scaleMax = input.scaleMax ?? 5;
  if (scaleMax <= scaleMin) {
    throw new Error("scaleMax must be greater than scaleMin");
  }
  const id = newId();
  db.insert(schema.factors)
    .values({
      id,
      categoryId: input.categoryId,
      name: input.name,
      scaleMin,
      scaleMax,
      labels: input.labels ? JSON.stringify(input.labels) : null,
      unit: input.unit ?? null,
    })
    .run();
  return getFactor(db, id) as Factor;
}

export function getFactor(db: DB, id: string): Factor | null {
  const row = db
    .select()
    .from(schema.factors)
    .where(eq(schema.factors.id, id))
    .get() as FactorRow | undefined;
  return row ? toFactor(row) : null;
}

export function listFactors(db: DB, categoryId?: string): Factor[] {
  const where = categoryId
    ? and(
        eq(schema.factors.isDeleted, 0),
        eq(schema.factors.categoryId, categoryId),
      )
    : eq(schema.factors.isDeleted, 0);
  const rows = db
    .select()
    .from(schema.factors)
    .where(where)
    .all() as FactorRow[];
  return rows.map(toFactor);
}

export function deleteFactor(db: DB, id: string): void {
  db.update(schema.factors)
    .set({ isDeleted: 1 })
    .where(eq(schema.factors.id, id))
    .run();
}

// ---------- logging (upsert on (date, factor_id)) ----------

export function logFactor(db: DB, input: LogFactorInputT): FactorLog {
  const factor = getFactor(db, input.factorId);
  if (!factor || factor.isDeleted) {
    throw new Error("Factor not found");
  }
  if (input.value < factor.scaleMin || input.value > factor.scaleMax) {
    throw new Error(
      `Value ${input.value} out of scale ${factor.scaleMin}-${factor.scaleMax}`,
    );
  }

  // Upsert: update the existing (date, factor) row, else insert (setProfile pattern).
  const existing = db
    .select()
    .from(schema.factorLogs)
    .where(
      and(
        eq(schema.factorLogs.date, input.date),
        eq(schema.factorLogs.factorId, input.factorId),
      ),
    )
    .get() as FactorLog | undefined;

  if (existing) {
    db.update(schema.factorLogs)
      .set({ value: input.value, note: input.note ?? null, isDeleted: 0 })
      .where(eq(schema.factorLogs.id, existing.id))
      .run();
    return db
      .select()
      .from(schema.factorLogs)
      .where(eq(schema.factorLogs.id, existing.id))
      .get() as FactorLog;
  }

  const id = newId();
  db.insert(schema.factorLogs)
    .values({
      id,
      date: input.date,
      factorId: input.factorId,
      value: input.value,
      note: input.note ?? null,
    })
    .run();
  return db
    .select()
    .from(schema.factorLogs)
    .where(eq(schema.factorLogs.id, id))
    .get() as FactorLog;
}

export function bulkLogFactors(
  db: DB,
  input: BulkLogFactorsInputT,
): FactorLog[] {
  return input.entries.map((e) =>
    logFactor(db, {
      date: input.date,
      factorId: e.factorId,
      value: e.value,
      note: e.note,
    }),
  );
}

export function deleteFactorLog(db: DB, id: string): void {
  db.update(schema.factorLogs)
    .set({ isDeleted: 1 })
    .where(eq(schema.factorLogs.id, id))
    .run();
}

// ---------- reads ----------

// All categories → their factors → each factor's log for `date` (or null).
export function getFactorLogsForDate(
  db: DB,
  date: string,
): FactorLogsForDate[] {
  const categories = listCategories(db);
  const logs = db
    .select()
    .from(schema.factorLogs)
    .where(
      and(
        eq(schema.factorLogs.date, date),
        eq(schema.factorLogs.isDeleted, 0),
      ),
    )
    .all() as FactorLog[];
  const logByFactor = new Map(logs.map((l) => [l.factorId, l]));

  return categories.map((category) => ({
    category,
    factors: listFactors(db, category.id).map((factor) => ({
      factor,
      log: logByFactor.get(factor.id) ?? null,
    })),
  }));
}

export function getFactorHistory(
  db: DB,
  factorId: string,
  days = 30,
): FactorLog[] {
  return db
    .select()
    .from(schema.factorLogs)
    .where(
      and(
        eq(schema.factorLogs.factorId, factorId),
        eq(schema.factorLogs.isDeleted, 0),
      ),
    )
    .orderBy(desc(schema.factorLogs.date))
    .limit(days)
    .all() as FactorLog[];
}
