import { eq, and, gte, lte } from "drizzle-orm";
import type { DB } from "../db/index.js";
import { schema } from "../db/index.js";
import { getActiveTarget } from "../targets/engine.js";
import { getDailyWater } from "../water/engine.js";
import { getSleepForDate } from "../sleep/engine.js";
import type { WeekSummary, Streaks, RangeStats, DayStats, Compliance, FoodLogEntry, SleepLogEntry } from "../types.js";

function getMonday(dateStr: string): string {
  const d = new Date(dateStr);
  const day = d.getDay();
  const diff = d.getDate() - day + (day === 0 ? -6 : 1);
  d.setDate(diff);
  return d.toISOString().split("T")[0];
}

function addDays(dateStr: string, days: number): string {
  const d = new Date(dateStr);
  d.setDate(d.getDate() + days);
  return d.toISOString().split("T")[0];
}

function sleepDurationMinutes(entry: SleepLogEntry): number {
  return Math.round(
    (new Date(entry.endTime).getTime() - new Date(entry.startTime).getTime()) /
      60000
  );
}

export function getWeekSummary(db: DB, date: string): WeekSummary {
  const weekStart = getMonday(date);
  const weekEnd = addDays(weekStart, 6);

  const foodLogs = db
    .select()
    .from(schema.foodLogs)
    .where(
      and(
        gte(schema.foodLogs.date, weekStart),
        lte(schema.foodLogs.date, weekEnd),
        eq(schema.foodLogs.isDeleted, 0)
      )
    )
    .all() as FoodLogEntry[];

  // Group by date
  const dailyTotals = new Map<
    string,
    { calories: number; protein: number; fat: number; carbs: number }
  >();
  for (const log of foodLogs) {
    const existing = dailyTotals.get(log.date) || {
      calories: 0,
      protein: 0,
      fat: 0,
      carbs: 0,
    };
    existing.calories += log.calories;
    existing.protein += log.protein;
    existing.fat += log.fat;
    existing.carbs += log.carbs;
    dailyTotals.set(log.date, existing);
  }

  // Water and sleep for each day
  let totalWaterMl = 0;
  let totalSleepMin = 0;
  let waterDays = 0;
  let sleepDays = 0;

  for (let i = 0; i < 7; i++) {
    const d = addDays(weekStart, i);
    const water = getDailyWater(db, d);
    if (water.totalMl > 0) {
      totalWaterMl += water.totalMl;
      waterDays++;
    }
    const sleepEntries = getSleepForDate(db, d);
    const daySlept = sleepEntries.reduce(
      (sum, e) => sum + sleepDurationMinutes(e),
      0
    );
    if (daySlept > 0) {
      totalSleepMin += daySlept;
      sleepDays++;
    }
  }

  const daysLogged = dailyTotals.size;
  const sumNutrition = [...dailyTotals.values()].reduce(
    (acc, d) => ({
      calories: acc.calories + d.calories,
      protein: acc.protein + d.protein,
      fat: acc.fat + d.fat,
      carbs: acc.carbs + d.carbs,
    }),
    { calories: 0, protein: 0, fat: 0, carbs: 0 }
  );

  return {
    weekStart,
    avgCalories: daysLogged ? Math.round(sumNutrition.calories / daysLogged) : 0,
    avgProtein: daysLogged ? Math.round(sumNutrition.protein / daysLogged) : 0,
    avgFat: daysLogged ? Math.round(sumNutrition.fat / daysLogged) : 0,
    avgCarbs: daysLogged ? Math.round(sumNutrition.carbs / daysLogged) : 0,
    avgWaterMl: waterDays ? Math.round(totalWaterMl / waterDays) : 0,
    avgSleepMinutes: sleepDays ? Math.round(totalSleepMin / sleepDays) : 0,
    daysLogged,
  };
}

export function getStreaks(db: DB): Streaks {
  const today = new Date().toISOString().split("T")[0];
  const target = getActiveTarget(db, today);

  let foodCurrent = 0;
  let foodBest = 0;
  let waterCurrent = 0;
  let waterBest = 0;
  let sleepCurrent = 0;
  let sleepBest = 0;

  let foodActive = true;
  let waterActive = true;
  let sleepActive = true;

  for (let i = 0; i < 365; i++) {
    const d = addDays(today, -i);

    if (foodActive) {
      const logs = db
        .select()
        .from(schema.foodLogs)
        .where(
          and(eq(schema.foodLogs.date, d), eq(schema.foodLogs.isDeleted, 0))
        )
        .all();
      if (logs.length > 0) {
        foodCurrent++;
      } else {
        foodActive = false;
      }
    }
    foodBest = Math.max(foodBest, foodCurrent);

    if (waterActive && target) {
      const water = getDailyWater(db, d);
      if (water.totalMl >= target.waterMl) {
        waterCurrent++;
      } else {
        waterActive = false;
      }
    }
    waterBest = Math.max(waterBest, waterCurrent);

    if (sleepActive && target) {
      const sleepEntries = getSleepForDate(db, d);
      const totalMin = sleepEntries.reduce(
        (sum, e) => sum + sleepDurationMinutes(e),
        0
      );
      if (totalMin >= target.sleepMinutes) {
        sleepCurrent++;
      } else {
        sleepActive = false;
      }
    }
    sleepBest = Math.max(sleepBest, sleepCurrent);

    if (!foodActive && !waterActive && !sleepActive) break;
  }

  return {
    foodLogging: { current: foodCurrent, best: foodBest },
    waterGoal: { current: waterCurrent, best: waterBest },
    sleepGoal: { current: sleepCurrent, best: sleepBest },
  };
}

export function getRangeStats(db: DB, from: string, to: string): RangeStats {
  const foodLogs = db
    .select()
    .from(schema.foodLogs)
    .where(
      and(
        gte(schema.foodLogs.date, from),
        lte(schema.foodLogs.date, to),
        eq(schema.foodLogs.isDeleted, 0)
      )
    )
    .all() as FoodLogEntry[];

  // Group food logs by date
  const dailyFoodTotals = new Map<
    string,
    { calories: number; protein: number; fat: number; carbs: number }
  >();
  for (const log of foodLogs) {
    const existing = dailyFoodTotals.get(log.date) || {
      calories: 0,
      protein: 0,
      fat: 0,
      carbs: 0,
    };
    existing.calories += log.calories;
    existing.protein += log.protein;
    existing.fat += log.fat;
    existing.carbs += log.carbs;
    dailyFoodTotals.set(log.date, existing);
  }

  // Build per-day stats
  const days: DayStats[] = [];
  let totalWaterMl = 0;
  let waterDaysCount = 0;
  let totalSleepMin = 0;
  let sleepDaysCount = 0;

  const d = new Date(from);
  const end = new Date(to);
  while (d <= end) {
    const dateStr = d.toISOString().split("T")[0];
    const food = dailyFoodTotals.get(dateStr) || { calories: 0, protein: 0, fat: 0, carbs: 0 };

    const water = getDailyWater(db, dateStr);
    if (water.totalMl > 0) {
      totalWaterMl += water.totalMl;
      waterDaysCount++;
    }

    const sleepEntries = getSleepForDate(db, dateStr);
    const daySlept = sleepEntries.reduce(
      (sum, e) => sum + sleepDurationMinutes(e),
      0
    );
    if (daySlept > 0) {
      totalSleepMin += daySlept;
      sleepDaysCount++;
    }

    days.push({
      date: dateStr,
      calories: food.calories,
      protein: food.protein,
      fat: food.fat,
      carbs: food.carbs,
      waterMl: water.totalMl,
      sleepMinutes: daySlept,
    });

    d.setDate(d.getDate() + 1);
  }

  const daysLogged = dailyFoodTotals.size;
  const sum = [...dailyFoodTotals.values()].reduce(
    (acc, v) => ({
      calories: acc.calories + v.calories,
      protein: acc.protein + v.protein,
      fat: acc.fat + v.fat,
      carbs: acc.carbs + v.carbs,
    }),
    { calories: 0, protein: 0, fat: 0, carbs: 0 }
  );

  // Compute compliance against active target
  const target = getActiveTarget(db, from);
  let compliance: Compliance | null = null;
  if (target) {
    const totalDays = days.length;
    let caloriesDays = 0;
    let proteinDays = 0;
    let waterDays = 0;
    let sleepDays = 0;

    for (const day of days) {
      if (day.calories <= target.calories) caloriesDays++;
      if (day.protein >= target.protein) proteinDays++;
      if (day.waterMl >= target.waterMl) waterDays++;
      if (day.sleepMinutes >= target.sleepMinutes) sleepDays++;
    }

    compliance = {
      totalDays,
      caloriesDays,
      proteinDays,
      waterDays,
      sleepDays,
      caloriesRate: totalDays ? Math.round(caloriesDays / totalDays * 100) : 0,
      proteinRate: totalDays ? Math.round(proteinDays / totalDays * 100) : 0,
      waterRate: totalDays ? Math.round(waterDays / totalDays * 100) : 0,
      sleepRate: totalDays ? Math.round(sleepDays / totalDays * 100) : 0,
    };
  }

  return {
    from,
    to,
    avgCalories: daysLogged ? Math.round(sum.calories / daysLogged) : 0,
    avgProtein: daysLogged ? Math.round(sum.protein / daysLogged) : 0,
    avgFat: daysLogged ? Math.round(sum.fat / daysLogged) : 0,
    avgCarbs: daysLogged ? Math.round(sum.carbs / daysLogged) : 0,
    avgWaterMl: waterDaysCount ? Math.round(totalWaterMl / waterDaysCount) : 0,
    avgSleepMinutes: sleepDaysCount ? Math.round(totalSleepMin / sleepDaysCount) : 0,
    daysLogged,
    days,
    compliance,
  };
}
