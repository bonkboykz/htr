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
  // training schemas
  StartSessionInput,
  LogSetInput,
  EndSessionInput,
  PatchRoutineExerciseInput,
  OverrideProgressionInput,
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
      "[WRITE] Start a workout session for a routine (session_index derived if omitted).",
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
      "[WRITE] End a workout session (optional ended_at + notes). Returns duration in seconds.",
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
];

export const toolsByName: Record<string, ToolDef> = Object.fromEntries(
  tools.map((t) => [t.name, t]),
);
