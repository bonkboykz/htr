import { z } from "zod";
import {
  // nutrition
  logFood,
  getDailyNutrition,
  // weight
  logWeight,
  getWeightTrend,
  getLatestWeight,
  // water
  logWater,
  getDailyWater,
  // sleep
  logSleep,
  getSleepForDate,
  getSleepDurationMinutes,
  // targets / tdee
  getActiveTarget,
  getTargetCalories,
  // training
  startSession,
  logSet,
  endSession,
  getToday,
  getRoutinePlan,
  getProgression,
  getVolumeStats,
  listSessions,
  suggestProgression,
  patchRoutineExercise,
  // training — exercises / routines / authoring
  listExercises,
  getExerciseById,
  listRoutines,
  listRoutineExercises,
  createExercise,
  updateExercise,
  deleteExercise,
  createRoutine,
  updateRoutine,
  deleteRoutine,
  addRoutineExercise,
  deleteRoutineExercise,
  deleteSet,
  deleteSession,
  recordOverride,
  listOverrides,
  getPlanDeviation,
  // training schemas
  StartSessionInput,
  LogSetInput,
  EndSessionInput,
  PatchRoutineExerciseInput,
  OverrideProgressionInput,
  CreateExerciseInput,
  UpdateExerciseInput,
  CreateRoutineInput,
  UpdateRoutineInput,
  AddRoutineExerciseInput,
  RecordOverrideInput,
  // factors
  createCategory,
  listCategories,
  deleteCategory,
  createFactor,
  listFactors,
  deleteFactor,
  logFactor,
  bulkLogFactors,
  deleteFactorLog,
  getFactorLogsForDate,
  getFactorHistory,
  // correlations
  getCorrelation,
  getCorrelationMatrix,
  getGroupComparison,
  getAutoInsights,
  listCorrelationSources,
  // factor / correlation schemas
  CreateCategoryInput,
  CreateFactorInput,
  LogFactorInput,
  BulkLogFactorsInput,
  CorrelationQueryInput,
  MatrixInput,
  GroupCompareInput,
  InsightsInput,
  // formatting
  formatCalories,
  formatMacro,
  formatWater,
  formatSleep,
  formatWeight,
  formatBodyFat,
  formatProgress,
  type DB,
  type TrainingRange,
  type WeightLogEntry,
} from "@htr/engine";

/** Permission tier for a tool. Encoded in the description too. */
export type Tier = "READ" | "WRITE" | "WRITE_TRAINING" | "SENSITIVE";

export interface ToolDef {
  name: string;
  tier: Tier;
  description: string;
  /** Zod object schema. `.shape` is the raw shape passed to the MCP SDK. */
  schema: z.ZodObject<z.ZodRawShape>;
  handler: (db: DB, args: unknown) => unknown;
}

// ---------- shared helpers ----------

const RangeShape = {
  from: z.string().optional(),
  to: z.string().optional(),
  range: z.enum(["week", "month"]).optional(),
};

// Mirror apps/api resolveRange: from/to win; else range=week|month; else all-time.
function resolveRange(args: {
  from?: string;
  to?: string;
  range?: "week" | "month";
}): TrainingRange {
  if (args.from || args.to) {
    const r: TrainingRange = {};
    if (args.from) r.from = args.from;
    if (args.to) r.to = args.to;
    return r;
  }
  const iso = (d: Date) => d.toISOString().slice(0, 10);
  const today = new Date();
  if (args.range === "week") {
    const start = new Date(today);
    start.setDate(start.getDate() - 6);
    return { from: iso(start), to: iso(today) };
  }
  if (args.range === "month") {
    const start = new Date(today);
    start.setDate(start.getDate() - 29);
    return { from: iso(start), to: iso(today) };
  }
  return {};
}

// Replicates apps/api/src/routes/daily.ts assembly into a plain object.
function assembleDailySummary(db: DB, date: string) {
  const nutrition = getDailyNutrition(db, date);
  const water = getDailyWater(db, date);

  const sleepEntries = getSleepForDate(db, date);
  const totalSleepMinutes = sleepEntries.reduce(
    (sum, e) => sum + getSleepDurationMinutes(e),
    0,
  );
  const qualities = sleepEntries
    .map((e) => e.quality)
    .filter((q): q is number => q !== null);
  const avgQuality =
    qualities.length > 0
      ? Math.round(qualities.reduce((a, b) => a + b, 0) / qualities.length)
      : null;

  const latestWeight = getLatestWeight(db);
  const weightForDate: WeightLogEntry | null =
    latestWeight && latestWeight.date === date ? latestWeight : null;

  const target = getActiveTarget(db, date);
  const targetSleepMinutes = target?.sleepMinutes ?? 480;
  const tdeeCalc = getTargetCalories(db, date);

  const caloriesBudget = tdeeCalc
    ? (() => {
        const consumed = nutrition.totals.calories;
        const remaining = tdeeCalc.targetCalories - consumed;
        return {
          targetCalories: tdeeCalc.targetCalories,
          targetCaloriesFormatted: formatCalories(tdeeCalc.targetCalories),
          consumedCalories: consumed,
          consumedCaloriesFormatted: formatCalories(consumed),
          remainingCalories: remaining,
          remainingCaloriesFormatted: formatCalories(remaining),
          progress: formatProgress(consumed, tdeeCalc.targetCalories),
        };
      })()
    : null;

  return {
    date,
    caloriesBudget,
    tdee: tdeeCalc,
    nutrition: {
      meals: nutrition.meals.map((mg) => ({
        meal: mg.meal,
        entries: mg.entries.map((e) => ({
          ...e,
          caloriesFormatted: formatCalories(e.calories),
          proteinFormatted: formatMacro(e.protein),
          fatFormatted: formatMacro(e.fat),
          carbsFormatted: formatMacro(e.carbs),
          fiberFormatted: formatMacro(e.fiber),
        })),
      })),
      totals: {
        ...nutrition.totals,
        caloriesFormatted: formatCalories(nutrition.totals.calories),
        proteinFormatted: formatMacro(nutrition.totals.protein),
        fatFormatted: formatMacro(nutrition.totals.fat),
        carbsFormatted: formatMacro(nutrition.totals.carbs),
        fiberFormatted: formatMacro(nutrition.totals.fiber),
      },
      target: nutrition.target,
    },
    water: {
      totalMl: water.totalMl,
      totalFormatted: formatWater(water.totalMl),
      targetMl: water.targetMl,
      targetFormatted: formatWater(water.targetMl),
      progress: formatProgress(water.totalMl, water.targetMl),
    },
    sleep: {
      totalMinutes: totalSleepMinutes,
      totalFormatted: formatSleep(totalSleepMinutes),
      targetMinutes: targetSleepMinutes,
      targetFormatted: formatSleep(targetSleepMinutes),
      quality: avgQuality,
      progress: formatProgress(totalSleepMinutes, targetSleepMinutes),
    },
    weight: weightForDate
      ? {
          ...weightForDate,
          weightFormatted: formatWeight(weightForDate.weightGrams),
          bodyFatFormatted:
            weightForDate.bodyFat !== null
              ? formatBodyFat(weightForDate.bodyFat)
              : null,
        }
      : null,
  };
}

// ---------- schemas ----------

const DateSchema = z.object({ date: z.string() });
const WeightTrendSchema = z.object({
  days: z.number().int().positive().optional(),
});
const ProgressionSchema = z.object({
  exercise_id: z.string(),
  from: z.string().optional(),
  to: z.string().optional(),
});
const RangeSchema = z.object(RangeShape);
const RoutinePlanSchema = z.object({
  routine_id: z.string(),
  session_index: z.number().int().min(1).optional(),
});
const EmptySchema = z.object({});
const TdeeSchema = z.object({ date: z.string().optional() });

const LogFoodSchema = z.object({
  date: z.string(),
  mealId: z.string(),
  foodItemId: z.string(),
  servingGrams: z.number().int().positive(),
});
const LogWeightSchema = z.object({
  date: z.string(),
  weightGrams: z.number().int().positive(),
  bodyFat: z.number().int().optional(),
  note: z.string().optional(),
});
const LogSleepSchema = z.object({
  startTime: z.string(),
  endTime: z.string(),
  quality: z.number().int().min(1).max(5).optional(),
  note: z.string().optional(),
});
const LogWaterSchema = z.object({
  date: z.string(),
  amountMl: z.number().int().positive(),
});

const LogSetSchema = LogSetInput.extend({ session_id: z.string() });
const EndSessionSchema = EndSessionInput.extend({ session_id: z.string() });
const PatchRoutineExerciseSchema = PatchRoutineExerciseInput.extend({
  routine_exercise_id: z.string(),
});

const ListExercisesSchema = z.object({
  q: z.string().optional(),
  muscle_group: z.string().optional(),
  include_deleted: z.boolean().optional(),
});
const IdSchema = z.object({ id: z.string() });
const RoutineIdSchema = z.object({ routine_id: z.string() });
const ListOverridesSchema = z.object({ session_id: z.string().optional() });
const UpdateExerciseSchema = UpdateExerciseInput.extend({ id: z.string() });
const UpdateRoutineSchema = UpdateRoutineInput.extend({ id: z.string() });
const AddRoutineExerciseSchema = AddRoutineExerciseInput.extend({
  routine_id: z.string(),
});
const DeleteRoutineExerciseSchema = z.object({
  routine_exercise_id: z.string(),
});
const DeleteSetSchema = z.object({ set_id: z.string() });
const DeleteSessionSchema = z.object({ session_id: z.string() });
const RecordOverrideSchema = RecordOverrideInput.extend({
  session_id: z.string(),
});

// factors
const ListFactorsSchema = z.object({ categoryId: z.string().optional() });
const FactorHistorySchema = z.object({
  factorId: z.string(),
  days: z.number().int().positive().optional(),
});

// ---------- tool registry ----------

export const tools: ToolDef[] = [
  // ===== READ (free) =====
  {
    name: "get_daily_summary",
    tier: "READ",
    description:
      "[READ] Full daily summary for a date: nutrition (meals + totals), calories budget, TDEE, water, sleep and weight.",
    schema: DateSchema,
    handler: (db, args) => {
      const { date } = DateSchema.parse(args);
      return assembleDailySummary(db, date);
    },
  },
  {
    name: "get_weight_trend",
    tier: "READ",
    description:
      "[READ] Weight entries over the last N days plus EMA-smoothed trend and net change (grams).",
    schema: WeightTrendSchema,
    handler: (db, args) => {
      const { days } = WeightTrendSchema.parse(args);
      const trend = getWeightTrend(db, days ?? 30);
      return {
        ...trend,
        trendFormatted: formatWeight(trend.trendGrams),
        changeFormatted: formatWeight(trend.changeGrams),
      };
    },
  },
  {
    name: "get_progression",
    tier: "READ",
    description:
      "[READ] Estimated-1RM progression history for an exercise over an optional date range.",
    schema: ProgressionSchema,
    handler: (db, args) => {
      const { exercise_id, from, to } = ProgressionSchema.parse(args);
      return getProgression(db, exercise_id, resolveRange({ from, to }));
    },
  },
  {
    name: "get_volume_stats",
    tier: "READ",
    description:
      "[READ] Training volume by muscle group over a range (from/to, or range=week|month, or all-time).",
    schema: RangeSchema,
    handler: (db, args) => {
      const parsed = RangeSchema.parse(args);
      return getVolumeStats(db, resolveRange(parsed));
    },
  },
  {
    name: "list_sessions",
    tier: "READ",
    description:
      "[READ] Workout session history (volume, sets, duration) over a range (from/to, or range=week|month, or all-time).",
    schema: RangeSchema,
    handler: (db, args) => {
      const parsed = RangeSchema.parse(args);
      return listSessions(db, resolveRange(parsed));
    },
  },
  {
    name: "get_routine_plan",
    tier: "READ",
    description:
      "[READ] Planned exercises for a routine (sections + per-exercise last performance and progression suggestion).",
    schema: RoutinePlanSchema,
    handler: (db, args) => {
      const { routine_id, session_index } = RoutinePlanSchema.parse(args);
      return getRoutinePlan(db, routine_id, session_index);
    },
  },
  {
    name: "get_today",
    tier: "READ",
    description:
      "[READ] Which routine/session is next today, and whether it is a ramp-up session.",
    schema: EmptySchema,
    handler: (db) => getToday(db),
  },
  {
    name: "get_tdee",
    tier: "READ",
    description:
      "[READ] BMR/TDEE and target calories for a date (defaults to today). Null if no profile.",
    schema: TdeeSchema,
    handler: (db, args) => {
      const { date } = TdeeSchema.parse(args);
      return getTargetCalories(db, date);
    },
  },

  // ===== WRITE (nutrition / body) =====
  {
    name: "log_food",
    tier: "WRITE",
    description:
      "[WRITE] Log a food entry from an existing food item and serving in grams. Macros are pre-computed.",
    schema: LogFoodSchema,
    handler: (db, args) => logFood(db, LogFoodSchema.parse(args)),
  },
  {
    name: "log_weight",
    tier: "WRITE",
    description:
      "[WRITE] Log a body-weight entry for a date (weight in grams, optional body fat permille + note).",
    schema: LogWeightSchema,
    handler: (db, args) => logWeight(db, LogWeightSchema.parse(args)),
  },
  {
    name: "log_sleep",
    tier: "WRITE",
    description:
      "[WRITE] Log a sleep period from ISO start/end timestamps (optional quality 1-5 + note).",
    schema: LogSleepSchema,
    handler: (db, args) => logSleep(db, LogSleepSchema.parse(args)),
  },
  {
    name: "log_water",
    tier: "WRITE",
    description: "[WRITE] Log a water intake entry (ml) for a date.",
    schema: LogWaterSchema,
    handler: (db, args) => logWater(db, LogWaterSchema.parse(args)),
  },

  // ===== WRITE (training) =====
  {
    name: "start_session",
    tier: "WRITE_TRAINING",
    description:
      "[WRITE] Start a workout session for a routine (session_index derived if omitted). Pass started_at (full ISO 8601 in the user's local timezone) to backdate a past workout; defaults to now.",
    schema: StartSessionInput,
    handler: (db, args) => startSession(db, StartSessionInput.parse(args)),
  },
  {
    name: "log_set",
    tier: "WRITE_TRAINING",
    description:
      "[WRITE] Log a single set (weight grams, reps, RIR) into an active session.",
    schema: LogSetSchema,
    handler: (db, args) => {
      const { session_id, ...rest } = LogSetSchema.parse(args);
      return logSet(db, session_id, rest);
    },
  },
  {
    name: "end_session",
    tier: "WRITE_TRAINING",
    description:
      "[WRITE] End a workout session (optional ended_at + notes). Can also correct/backdate started_at (full ISO 8601); duration is recomputed from the corrected start. Returns duration in seconds.",
    schema: EndSessionSchema,
    handler: (db, args) => {
      const { session_id, ...rest } = EndSessionSchema.parse(args);
      return endSession(db, session_id, rest);
    },
  },

  // ===== SENSITIVE (persistent plan edits) =====
  {
    name: "patch_routine_exercise",
    tier: "SENSITIVE",
    description:
      "[SENSITIVE] Persistently edits the routine template (rep range, target sets/RIR, swap exercise, notes). This is a PERSISTENT plan change affecting all future sessions.",
    schema: PatchRoutineExerciseSchema,
    handler: (db, args) => {
      const { routine_exercise_id, ...rest } =
        PatchRoutineExerciseSchema.parse(args);
      return patchRoutineExercise(db, routine_exercise_id, rest);
    },
  },
  {
    name: "override_progression",
    tier: "SENSITIVE",
    description:
      "[SENSITIVE] Advisory in v1: overrides the engine's suggested weight with a reason; realized when the set is logged. Does NOT persist a plan change.",
    schema: OverrideProgressionInput,
    handler: (db, args) => {
      const parsed = OverrideProgressionInput.parse(args);
      return {
        engineSuggestion: suggestProgression(db, parsed.exercise_id),
        override: parsed,
      };
    },
  },

  // ===== READ (exercises / routines / overrides) =====
  {
    name: "list_exercises",
    tier: "READ",
    description:
      "[READ] List exercises in the library (optional name search q, muscle_group filter, include_deleted).",
    schema: ListExercisesSchema,
    handler: (db, args) => {
      const { q, muscle_group, include_deleted } =
        ListExercisesSchema.parse(args);
      return listExercises(db, {
        q,
        muscleGroup: muscle_group,
        includeDeleted: include_deleted,
      });
    },
  },
  {
    name: "get_exercise",
    tier: "READ",
    description: "[READ] Get a single exercise by id.",
    schema: IdSchema,
    handler: (db, args) => {
      const { id } = IdSchema.parse(args);
      return getExerciseById(db, id);
    },
  },
  {
    name: "list_routines",
    tier: "READ",
    description: "[READ] List all routines.",
    schema: EmptySchema,
    handler: (db) => listRoutines(db),
  },
  {
    name: "list_routine_exercises",
    tier: "READ",
    description:
      "[READ] List the planned exercises (sections, targets) for a routine.",
    schema: RoutineIdSchema,
    handler: (db, args) => {
      const { routine_id } = RoutineIdSchema.parse(args);
      return listRoutineExercises(db, routine_id);
    },
  },
  {
    name: "list_overrides",
    tier: "READ",
    description:
      "[READ] List recorded session plan overrides (optionally filtered by session_id).",
    schema: ListOverridesSchema,
    handler: (db, args) => {
      const { session_id } = ListOverridesSchema.parse(args);
      return listOverrides(db, session_id);
    },
  },
  {
    name: "get_plan_deviation",
    tier: "READ",
    description:
      "[READ] How often the plan is overridden over a range (from/to, or range=week|month, or all-time).",
    schema: RangeSchema,
    handler: (db, args) => {
      const parsed = RangeSchema.parse(args);
      return getPlanDeviation(db, resolveRange(parsed));
    },
  },

  // ===== SENSITIVE (persistent library / routine authoring) =====
  {
    name: "create_exercise",
    tier: "SENSITIVE",
    description:
      "[SENSITIVE] Create a new exercise in the library. Persistent authoring change to the training catalog.",
    schema: CreateExerciseInput,
    handler: (db, args) => createExercise(db, CreateExerciseInput.parse(args)),
  },
  {
    name: "update_exercise",
    tier: "SENSITIVE",
    description:
      "[SENSITIVE] Update an existing exercise by id. Persistent authoring change to the training catalog.",
    schema: UpdateExerciseSchema,
    handler: (db, args) => {
      const { id, ...rest } = UpdateExerciseSchema.parse(args);
      return updateExercise(db, id, rest);
    },
  },
  {
    name: "delete_exercise",
    tier: "SENSITIVE",
    description:
      "[SENSITIVE] Soft-delete an exercise by id. Persistent authoring change to the training catalog.",
    schema: IdSchema,
    handler: (db, args) => {
      const { id } = IdSchema.parse(args);
      deleteExercise(db, id);
      return { deleted: id };
    },
  },
  {
    name: "create_routine",
    tier: "SENSITIVE",
    description:
      "[SENSITIVE] Create a new routine. Persistent authoring change to the training plan.",
    schema: CreateRoutineInput,
    handler: (db, args) => createRoutine(db, CreateRoutineInput.parse(args)),
  },
  {
    name: "update_routine",
    tier: "SENSITIVE",
    description:
      "[SENSITIVE] Update a routine by id. Persistent authoring change to the training plan.",
    schema: UpdateRoutineSchema,
    handler: (db, args) => {
      const { id, ...rest } = UpdateRoutineSchema.parse(args);
      return updateRoutine(db, id, rest);
    },
  },
  {
    name: "delete_routine",
    tier: "SENSITIVE",
    description:
      "[SENSITIVE] Soft-delete a routine by id. Persistent authoring change to the training plan.",
    schema: IdSchema,
    handler: (db, args) => {
      const { id } = IdSchema.parse(args);
      deleteRoutine(db, id);
      return { deleted: id };
    },
  },
  {
    name: "add_routine_exercise",
    tier: "SENSITIVE",
    description:
      "[SENSITIVE] Add an exercise to a routine (section + targets). Persistent authoring change affecting future sessions.",
    schema: AddRoutineExerciseSchema,
    handler: (db, args) => {
      const { routine_id, ...rest } = AddRoutineExerciseSchema.parse(args);
      return addRoutineExercise(db, routine_id, rest);
    },
  },
  {
    name: "delete_routine_exercise",
    tier: "SENSITIVE",
    description:
      "[SENSITIVE] Remove a planned exercise from a routine. Persistent authoring change affecting future sessions.",
    schema: DeleteRoutineExerciseSchema,
    handler: (db, args) => {
      const { routine_exercise_id } = DeleteRoutineExerciseSchema.parse(args);
      deleteRoutineExercise(db, routine_exercise_id);
      return { deleted: routine_exercise_id };
    },
  },

  // ===== WRITE (training log edits) =====
  {
    name: "delete_set",
    tier: "WRITE_TRAINING",
    description: "[WRITE] Soft-delete a logged set by id.",
    schema: DeleteSetSchema,
    handler: (db, args) => {
      const { set_id } = DeleteSetSchema.parse(args);
      deleteSet(db, set_id);
      return { deleted: set_id };
    },
  },
  {
    name: "delete_session",
    tier: "WRITE_TRAINING",
    description:
      "[WRITE] Soft-delete a workout session (and its sets) by id.",
    schema: DeleteSessionSchema,
    handler: (db, args) => {
      const { session_id } = DeleteSessionSchema.parse(args);
      deleteSession(db, session_id);
      return { deleted: session_id };
    },
  },
  {
    name: "record_override",
    tier: "WRITE_TRAINING",
    description:
      "[WRITE] Record a one-off exercise substitution/override on a session.",
    schema: RecordOverrideSchema,
    handler: (db, args) => {
      const { session_id, ...rest } = RecordOverrideSchema.parse(args);
      return recordOverride(db, session_id, rest);
    },
  },

  // ===== READ (factors / correlations) =====
  {
    name: "list_factor_categories",
    tier: "READ",
    description: "[READ] List all factor categories.",
    schema: EmptySchema,
    handler: (db) => listCategories(db),
  },
  {
    name: "list_factors",
    tier: "READ",
    description:
      "[READ] List trackable factors, optionally filtered by categoryId.",
    schema: ListFactorsSchema,
    handler: (db, args) => {
      const { categoryId } = ListFactorsSchema.parse(args);
      return listFactors(db, categoryId);
    },
  },
  {
    name: "get_factor_logs",
    tier: "READ",
    description: "[READ] Get all factor logs recorded for a date.",
    schema: DateSchema,
    handler: (db, args) => {
      const { date } = DateSchema.parse(args);
      return getFactorLogsForDate(db, date);
    },
  },
  {
    name: "get_factor_history",
    tier: "READ",
    description:
      "[READ] Recent logged values for a factor (most recent first, optional days limit).",
    schema: FactorHistorySchema,
    handler: (db, args) => {
      const { factorId, days } = FactorHistorySchema.parse(args);
      return getFactorHistory(db, factorId, days);
    },
  },
  {
    name: "get_correlation",
    tier: "READ",
    description:
      "[READ] Spearman correlation between two data series over a date range (optional lag in days). ASSOCIATION only, not causation.",
    schema: CorrelationQueryInput,
    handler: (db, args) => {
      const { seriesA, seriesB, from, to, lag } =
        CorrelationQueryInput.parse(args);
      return getCorrelation(db, seriesA, seriesB, from, to, { lag });
    },
  },
  {
    name: "get_correlation_matrix",
    tier: "READ",
    description:
      "[READ] Pairwise correlation matrix across data sources over a range (optional lag). ASSOCIATIONS only, not causation.",
    schema: MatrixInput,
    handler: (db, args) => {
      const { sources, from, to, lag } = MatrixInput.parse(args);
      return getCorrelationMatrix(db, sources, from, to, { lag });
    },
  },
  {
    name: "get_group_comparison",
    tier: "READ",
    description:
      "[READ] Compare a metric on days a factor is present vs absent over a range (optional lag, threshold). ASSOCIATION only, not causation.",
    schema: GroupCompareInput,
    handler: (db, args) => {
      const { factorSource, metricSource, from, to, lag, threshold } =
        GroupCompareInput.parse(args);
      return getGroupComparison(db, factorSource, metricSource, from, to, {
        lag,
        threshold,
      });
    },
  },
  {
    name: "get_insights",
    tier: "READ",
    description:
      "[READ] Auto-discovered factor/metric relationships over a range. Results are ASSOCIATIONS, not causation.",
    schema: InsightsInput,
    handler: (db, args) => {
      const { from, to } = InsightsInput.parse(args);
      return getAutoInsights(db, from, to);
    },
  },
  {
    name: "list_correlation_sources",
    tier: "READ",
    description:
      "[READ] List all data sources available for correlation (factors + HTR metrics).",
    schema: EmptySchema,
    handler: (db) => listCorrelationSources(db),
  },

  // ===== WRITE (factors) =====
  {
    name: "create_factor_category",
    tier: "WRITE",
    description:
      "[WRITE] Create a factor category (name, optional emoji, sort order).",
    schema: CreateCategoryInput,
    handler: (db, args) => createCategory(db, CreateCategoryInput.parse(args)),
  },
  {
    name: "create_factor",
    tier: "WRITE",
    description:
      "[WRITE] Create a trackable factor in a category (scale, labels, unit).",
    schema: CreateFactorInput,
    handler: (db, args) => createFactor(db, CreateFactorInput.parse(args)),
  },
  {
    name: "log_factor",
    tier: "WRITE",
    description:
      "[WRITE] Log a factor value for a date (upserts on date + factor).",
    schema: LogFactorInput,
    handler: (db, args) => logFactor(db, LogFactorInput.parse(args)),
  },
  {
    name: "bulk_log_factors",
    tier: "WRITE",
    description: "[WRITE] Log multiple factor values for a single date at once.",
    schema: BulkLogFactorsInput,
    handler: (db, args) => bulkLogFactors(db, BulkLogFactorsInput.parse(args)),
  },
  {
    name: "delete_factor_category",
    tier: "WRITE",
    description: "[WRITE] Delete a factor category by id.",
    schema: IdSchema,
    handler: (db, args) => {
      const { id } = IdSchema.parse(args);
      deleteCategory(db, id);
      return { deleted: id };
    },
  },
  {
    name: "delete_factor",
    tier: "WRITE",
    description: "[WRITE] Delete a factor by id.",
    schema: IdSchema,
    handler: (db, args) => {
      const { id } = IdSchema.parse(args);
      deleteFactor(db, id);
      return { deleted: id };
    },
  },
  {
    name: "delete_factor_log",
    tier: "WRITE",
    description: "[WRITE] Soft-delete a single factor log entry by id.",
    schema: IdSchema,
    handler: (db, args) => {
      const { id } = IdSchema.parse(args);
      deleteFactorLog(db, id);
      return { deleted: id };
    },
  },
];

export const toolsByName: Record<string, ToolDef> = Object.fromEntries(
  tools.map((t) => [t.name, t]),
);
