import { Hono } from "hono";
import {
  getWeekSummary,
  getStreaks,
  getRangeStats,
  getWeightTrend,
  formatCalories,
  formatMacro,
  formatWater,
  formatSleep,
  formatWeight,
  type DB,
} from "@htr/engine";

export function statsRoutes(db: DB) {
  const app = new Hono();

  // GET /week?date= — week summary
  app.get("/week", (c) => {
    const date = c.req.query("date") || new Date().toISOString().split("T")[0];
    const summary = getWeekSummary(db, date);
    return c.json({
      ...summary,
      avgCaloriesFormatted: formatCalories(summary.avgCalories),
      avgProteinFormatted: formatMacro(summary.avgProtein),
      avgFatFormatted: formatMacro(summary.avgFat),
      avgCarbsFormatted: formatMacro(summary.avgCarbs),
      avgWaterMlFormatted: formatWater(summary.avgWaterMl),
      avgSleepFormatted: formatSleep(summary.avgSleepMinutes),
    });
  });

  // GET /streaks — current streaks
  app.get("/streaks", (c) => {
    const streaks = getStreaks(db);
    return c.json(streaks);
  });

  // GET /range?from=&to= — range averages
  app.get("/range", (c) => {
    const from = c.req.query("from");
    const to = c.req.query("to");
    if (!from || !to) {
      return c.json(
        {
          error: {
            code: "VALIDATION_ERROR",
            message: "from and to query parameters are required",
            suggestion:
              "Provide date range, e.g. ?from=2026-03-01&to=2026-03-09",
          },
        },
        400
      );
    }

    const stats = getRangeStats(db, from, to);
    return c.json({
      ...stats,
      avgCaloriesFormatted: formatCalories(stats.avgCalories),
      avgProteinFormatted: formatMacro(stats.avgProtein),
      avgFatFormatted: formatMacro(stats.avgFat),
      avgCarbsFormatted: formatMacro(stats.avgCarbs),
      avgWaterMlFormatted: formatWater(stats.avgWaterMl),
      avgSleepFormatted: formatSleep(stats.avgSleepMinutes),
      days: stats.days.map((day) => ({
        ...day,
        caloriesFormatted: formatCalories(day.calories),
        proteinFormatted: formatMacro(day.protein),
        fatFormatted: formatMacro(day.fat),
        carbsFormatted: formatMacro(day.carbs),
        waterFormatted: formatWater(day.waterMl),
        sleepFormatted: formatSleep(day.sleepMinutes),
      })),
      compliance: stats.compliance,
    });
  });

  // GET /weight-trend?days= — weight trend + EMA
  app.get("/weight-trend", (c) => {
    const days = parseInt(c.req.query("days") || "30", 10);
    const trend = getWeightTrend(db, days);
    return c.json({
      entries: trend.entries.map((e) => ({
        ...e,
        weightFormatted: formatWeight(e.weightGrams),
      })),
      trendGrams: trend.trendGrams,
      trendFormatted: formatWeight(trend.trendGrams),
      changeGrams: trend.changeGrams,
      changeFormatted: formatWeight(Math.abs(trend.changeGrams)),
    });
  });

  return app;
}
