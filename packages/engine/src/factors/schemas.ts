import { z } from "zod";

// ---------- factor CRUD + logging ----------

export const CreateCategoryInput = z.object({
  name: z.string().min(1),
  emoji: z.string().optional(),
  sortOrder: z.number().int().optional(),
});

export const CreateFactorInput = z.object({
  categoryId: z.string(),
  name: z.string().min(1),
  kind: z.enum(["rating", "count"]).optional(), // default "rating"
  scaleMin: z.number().int().optional(),
  scaleMax: z.number().int().optional(),
  labels: z.record(z.string()).optional(), // {"1":"Ужасно","5":"Отлично"}
  unit: z.string().optional(),
});

export const LogFactorInput = z.object({
  date: z.string(), // YYYY-MM-DD
  factorId: z.string(),
  value: z.number().int(), // validated against the factor's scale in the engine
  note: z.string().max(500).optional(),
});

export const BulkLogFactorsInput = z.object({
  date: z.string(),
  entries: z
    .array(
      z.object({
        factorId: z.string(),
        value: z.number().int(),
        note: z.string().max(500).optional(),
      }),
    )
    .min(1),
});

// ---------- correlation queries ----------

export const CorrelationQueryInput = z.object({
  seriesA: z.string(),
  seriesB: z.string(),
  from: z.string(),
  to: z.string(),
  lag: z.number().int().optional(), // days seriesB is shifted vs seriesA (default 0)
});

export const MatrixInput = z.object({
  sources: z.array(z.string()).min(2),
  from: z.string(),
  to: z.string(),
  lag: z.number().int().optional(),
});

export const GroupCompareInput = z.object({
  factorSource: z.string(),
  metricSource: z.string(),
  from: z.string(),
  to: z.string(),
  lag: z.number().int().optional(),
  threshold: z.number().int().optional(),
});

export const InsightsInput = z.object({
  from: z.string(),
  to: z.string(),
});

export type CreateCategoryInputT = z.infer<typeof CreateCategoryInput>;
export type CreateFactorInputT = z.infer<typeof CreateFactorInput>;
export type LogFactorInputT = z.infer<typeof LogFactorInput>;
export type BulkLogFactorsInputT = z.infer<typeof BulkLogFactorsInput>;
export type CorrelationQueryInputT = z.infer<typeof CorrelationQueryInput>;
export type MatrixInputT = z.infer<typeof MatrixInput>;
export type GroupCompareInputT = z.infer<typeof GroupCompareInput>;
export type InsightsInputT = z.infer<typeof InsightsInput>;
