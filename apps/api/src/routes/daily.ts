import { Hono } from "hono";
import {
  getDailyNutrition,
  getDailyWater,
  getSleepForDate,
  getSleepDurationMinutes,
  getActiveTarget,
  getLatestWeight,
  formatCalories,
  formatMacro,
  formatWater,
  formatSleep,
  formatWeight,
  formatBodyFat,
  formatProgress,
  type DB,
  type WeightLogEntry,
} from "@htr/engine";

export function dailyRoutes(db: DB) {
  const app = new Hono();

  // GET /:date — full daily summary
  app.get("/:date", (c) => {
    const date = c.req.param("date");

    if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
      return c.json(
        {
          error: {
            code: "VALIDATION_ERROR",
            message: "Invalid date format",
            suggestion: "Use YYYY-MM-DD format, e.g. 2026-03-09",
          },
        },
        400
      );
    }

    // Nutrition
    const nutrition = getDailyNutrition(db, date);
    const formattedMeals = nutrition.meals.map((mg) => ({
      meal: mg.meal,
      entries: mg.entries.map((e) => ({
        ...e,
        caloriesFormatted: formatCalories(e.calories),
        proteinFormatted: formatMacro(e.protein),
        fatFormatted: formatMacro(e.fat),
        carbsFormatted: formatMacro(e.carbs),
        fiberFormatted: formatMacro(e.fiber),
      })),
    }));

    // Water
    const water = getDailyWater(db, date);

    // Sleep
    const sleepEntries = getSleepForDate(db, date);
    const totalSleepMinutes = sleepEntries.reduce(
      (sum, e) => sum + getSleepDurationMinutes(e),
      0
    );
    const qualities = sleepEntries
      .map((e) => e.quality)
      .filter((q): q is number => q !== null);
    const avgQuality =
      qualities.length > 0
        ? Math.round(qualities.reduce((a, b) => a + b, 0) / qualities.length)
        : null;

    // Weight — check if there's a log for this exact date
    // getLatestWeight doesn't filter by date, so we use getDailyNutrition pattern
    // Actually, we need weight for the specific date. Let's check via getWeightEntries or direct.
    // For simplicity, use getLatestWeight and check if it matches date
    const latestWeight = getLatestWeight(db);
    const weightForDate: WeightLogEntry | null =
      latestWeight && latestWeight.date === date ? latestWeight : null;

    // Target
    const target = getActiveTarget(db, date);
    const targetSleepMinutes = target?.sleepMinutes ?? 480;

    return c.json({
      date,
      nutrition: {
        meals: formattedMeals,
        totals: {
          ...nutrition.totals,
          caloriesFormatted: formatCalories(nutrition.totals.calories),
          proteinFormatted: formatMacro(nutrition.totals.protein),
          fatFormatted: formatMacro(nutrition.totals.fat),
          carbsFormatted: formatMacro(nutrition.totals.carbs),
          fiberFormatted: formatMacro(nutrition.totals.fiber),
        },
        target: nutrition.target,
        progress: nutrition.target
          ? {
              calories: formatProgress(
                nutrition.totals.calories,
                nutrition.target.calories
              ),
              protein: formatProgress(
                nutrition.totals.protein,
                nutrition.target.protein
              ),
              fat: formatProgress(nutrition.totals.fat, nutrition.target.fat),
              carbs: formatProgress(
                nutrition.totals.carbs,
                nutrition.target.carbs
              ),
            }
          : null,
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
        entries: sleepEntries.map((e) => {
          const durationMinutes = getSleepDurationMinutes(e);
          return {
            ...e,
            durationMinutes,
            durationFormatted: formatSleep(durationMinutes),
          };
        }),
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
    });
  });

  return app;
}
