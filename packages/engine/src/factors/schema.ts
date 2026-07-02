import {
  sqliteTable,
  text,
  integer,
  index,
  uniqueIndex,
} from "drizzle-orm/sqlite-core";

// Categories that group factors (Mood, Symptoms, Habits, Meds, ...).
export const factorCategories = sqliteTable("factor_categories", {
  id: text("id").primaryKey(),
  name: text("name").notNull(),
  emoji: text("emoji"),
  sortOrder: integer("sort_order").notNull().default(0),
  isSystem: integer("is_system").notNull().default(0),
  isDeleted: integer("is_deleted").notNull().default(0),
  createdAt: text("created_at")
    .notNull()
    .$defaultFn(() => new Date().toISOString()),
});

// A tracked item with a configurable integer scale.
export const factors = sqliteTable("factors", {
  id: text("id").primaryKey(),
  categoryId: text("category_id").notNull(),
  name: text("name").notNull(),
  scaleMin: integer("scale_min").notNull().default(0),
  scaleMax: integer("scale_max").notNull().default(5),
  labels: text("labels"), // JSON: {"1":"Ужасно","5":"Отлично"} | null
  unit: text("unit"), // e.g. "mg", "минут" | null
  isDeleted: integer("is_deleted").notNull().default(0),
  createdAt: text("created_at")
    .notNull()
    .$defaultFn(() => new Date().toISOString()),
});

// One value per (date, factor). UNIQUE(date, factor_id) → upsert on re-log.
export const factorLogs = sqliteTable(
  "factor_logs",
  {
    id: text("id").primaryKey(),
    date: text("date").notNull(), // YYYY-MM-DD
    factorId: text("factor_id").notNull(),
    value: integer("value").notNull(),
    note: text("note"),
    isDeleted: integer("is_deleted").notNull().default(0),
    createdAt: text("created_at")
      .notNull()
      .$defaultFn(() => new Date().toISOString()),
  },
  (t) => [
    // Uniqueness + hot path for per-factor history (factor_id, date).
    uniqueIndex("factor_logs_factor_date_idx").on(t.factorId, t.date),
    // Per-date lookups (getFactorLogsForDate).
    index("factor_logs_date_idx").on(t.date),
  ],
);
