import { describe, it, expect, beforeEach } from "vitest";
import { setupTestDb } from "../src/test-helpers.js";
import {
  getWeekSummary,
  getRangeStats,
  createFoodItem,
  logFood,
  logWater,
  logSleep,
  setTarget,
} from "../src/index.js";
import type { DB, FoodItem } from "../src/index.js";

describe("stats engine", () => {
  let db: DB;
  let chicken: FoodItem;

  beforeEach(() => {
    db = setupTestDb();
    chicken = createFoodItem(db, {
      name: "Chicken Breast",
      caloriesPer100g: 165,
      proteinPer100g: 310,
      fatPer100g: 36,
      carbsPer100g: 0,
      fiberPer100g: 0,
    });
  });

  describe("getWeekSummary", () => {
    it("returns zeros when no data exists for the week", () => {
      // 2026-01-12 is a Monday
      const summary = getWeekSummary(db, "2026-01-14");

      expect(summary.weekStart).toBe("2026-01-12");
      expect(summary.avgCalories).toBe(0);
      expect(summary.avgProtein).toBe(0);
      expect(summary.avgFat).toBe(0);
      expect(summary.avgCarbs).toBe(0);
      expect(summary.avgWaterMl).toBe(0);
      expect(summary.avgSleepMinutes).toBe(0);
      expect(summary.daysLogged).toBe(0);
    });

    it("computes averages for food logs across the week", () => {
      // 2026-01-12 is Monday, 2026-01-18 is Sunday
      // Log food on Monday and Wednesday
      logFood(db, {
        date: "2026-01-12",
        mealId: "meal-lunch",
        foodItemId: chicken.id,
        servingGrams: 200,
      });
      logFood(db, {
        date: "2026-01-14",
        mealId: "meal-lunch",
        foodItemId: chicken.id,
        servingGrams: 300,
      });

      const summary = getWeekSummary(db, "2026-01-14");

      expect(summary.weekStart).toBe("2026-01-12");
      expect(summary.daysLogged).toBe(2);

      // Mon: 330 cal, Wed: 495 cal => avg = (330 + 495) / 2 = 413 (rounded)
      const monCal = Math.round((165 * 200) / 100);
      const wedCal = Math.round((165 * 300) / 100);
      expect(summary.avgCalories).toBe(Math.round((monCal + wedCal) / 2));
    });

    it("computes average water for days with water logged", () => {
      // 2026-01-12 is Monday
      logWater(db, { date: "2026-01-12", amountMl: 2000 });
      logWater(db, { date: "2026-01-13", amountMl: 2500 });

      const summary = getWeekSummary(db, "2026-01-14");

      expect(summary.avgWaterMl).toBe(Math.round((2000 + 2500) / 2));
    });

    it("computes average sleep for days with sleep logged", () => {
      // Sleep waking up on Monday and Tuesday
      logSleep(db, {
        startTime: "2026-01-11T23:00:00",
        endTime: "2026-01-12T07:00:00", // 480 min, attributed to Mon
      });
      logSleep(db, {
        startTime: "2026-01-12T23:30:00",
        endTime: "2026-01-13T06:30:00", // 420 min, attributed to Tue
      });

      const summary = getWeekSummary(db, "2026-01-14");

      expect(summary.avgSleepMinutes).toBe(Math.round((480 + 420) / 2));
    });

    it("finds the correct Monday for any day of the week", () => {
      // 2026-01-18 is Sunday, week starts Mon 2026-01-12
      const summary = getWeekSummary(db, "2026-01-18");
      expect(summary.weekStart).toBe("2026-01-12");

      // 2026-01-12 is Monday itself
      const summary2 = getWeekSummary(db, "2026-01-12");
      expect(summary2.weekStart).toBe("2026-01-12");
    });
  });

  describe("getRangeStats", () => {
    it("returns zeros when no data exists in the range", () => {
      const stats = getRangeStats(db, "2026-01-01", "2026-01-31");

      expect(stats.from).toBe("2026-01-01");
      expect(stats.to).toBe("2026-01-31");
      expect(stats.avgCalories).toBe(0);
      expect(stats.avgProtein).toBe(0);
      expect(stats.avgFat).toBe(0);
      expect(stats.avgCarbs).toBe(0);
      expect(stats.avgWaterMl).toBe(0);
      expect(stats.avgSleepMinutes).toBe(0);
      expect(stats.daysLogged).toBe(0);
    });

    it("computes averages for food logs in the range", () => {
      logFood(db, {
        date: "2026-01-10",
        mealId: "meal-lunch",
        foodItemId: chicken.id,
        servingGrams: 200,
      });
      logFood(db, {
        date: "2026-01-15",
        mealId: "meal-dinner",
        foodItemId: chicken.id,
        servingGrams: 300,
      });
      // Outside range
      logFood(db, {
        date: "2026-02-01",
        mealId: "meal-lunch",
        foodItemId: chicken.id,
        servingGrams: 400,
      });

      const stats = getRangeStats(db, "2026-01-01", "2026-01-31");

      expect(stats.daysLogged).toBe(2);
      const day1Cal = Math.round((165 * 200) / 100);
      const day2Cal = Math.round((165 * 300) / 100);
      expect(stats.avgCalories).toBe(Math.round((day1Cal + day2Cal) / 2));
    });

    it("includes water averages for days with water logged", () => {
      logWater(db, { date: "2026-01-10", amountMl: 2000 });
      logWater(db, { date: "2026-01-10", amountMl: 500 });
      logWater(db, { date: "2026-01-15", amountMl: 3000 });

      const stats = getRangeStats(db, "2026-01-01", "2026-01-31");

      // Day 1: 2500ml, Day 2: 3000ml => avg = 2750
      expect(stats.avgWaterMl).toBe(Math.round((2500 + 3000) / 2));
    });

    it("includes sleep averages for days with sleep logged", () => {
      logSleep(db, {
        startTime: "2026-01-09T23:00:00",
        endTime: "2026-01-10T07:00:00", // 480 min
      });
      logSleep(db, {
        startTime: "2026-01-14T22:00:00",
        endTime: "2026-01-15T06:00:00", // 480 min
      });

      const stats = getRangeStats(db, "2026-01-01", "2026-01-31");
      expect(stats.avgSleepMinutes).toBe(480);
    });

    it("handles a single-day range", () => {
      logFood(db, {
        date: "2026-01-15",
        mealId: "meal-lunch",
        foodItemId: chicken.id,
        servingGrams: 200,
      });

      const stats = getRangeStats(db, "2026-01-15", "2026-01-15");
      expect(stats.daysLogged).toBe(1);
      expect(stats.avgCalories).toBe(Math.round((165 * 200) / 100));
    });

    it("returns 0 averages when range has no data", () => {
      logFood(db, {
        date: "2026-02-15",
        mealId: "meal-lunch",
        foodItemId: chicken.id,
        servingGrams: 200,
      });

      const stats = getRangeStats(db, "2026-01-01", "2026-01-31");
      expect(stats.daysLogged).toBe(0);
      expect(stats.avgCalories).toBe(0);
    });

    it("returns days array with correct order and per-day totals", () => {
      logFood(db, {
        date: "2026-01-10",
        mealId: "meal-lunch",
        foodItemId: chicken.id,
        servingGrams: 200,
      });
      logFood(db, {
        date: "2026-01-12",
        mealId: "meal-dinner",
        foodItemId: chicken.id,
        servingGrams: 300,
      });
      logWater(db, { date: "2026-01-10", amountMl: 2000 });
      logSleep(db, {
        startTime: "2026-01-11T23:00:00",
        endTime: "2026-01-12T07:00:00",
      });

      const stats = getRangeStats(db, "2026-01-10", "2026-01-12");

      expect(stats.days).toHaveLength(3);
      expect(stats.days[0].date).toBe("2026-01-10");
      expect(stats.days[1].date).toBe("2026-01-11");
      expect(stats.days[2].date).toBe("2026-01-12");

      // Day 1: food logged, water logged
      expect(stats.days[0].calories).toBe(Math.round((165 * 200) / 100));
      expect(stats.days[0].waterMl).toBe(2000);
      expect(stats.days[0].sleepMinutes).toBe(0);

      // Day 2: no food, no water, no sleep
      expect(stats.days[1].calories).toBe(0);
      expect(stats.days[1].waterMl).toBe(0);

      // Day 3: food logged, sleep attributed
      expect(stats.days[2].calories).toBe(Math.round((165 * 300) / 100));
      expect(stats.days[2].sleepMinutes).toBe(480);
    });

    it("returns compliance with correct counts and rates when target exists", () => {
      setTarget(db, {
        effectiveDate: "2026-01-01",
        calories: 2000,
        protein: 200, // tenths of grams = 20g
        fat: 500,
        carbs: 2000,
        waterMl: 2000,
        sleepMinutes: 420,
      });

      // Day 1: under calories, above protein, above water, above sleep
      logFood(db, {
        date: "2026-01-10",
        mealId: "meal-lunch",
        foodItemId: chicken.id,
        servingGrams: 200, // 330 cal, 620 protein (tenths)
      });
      logWater(db, { date: "2026-01-10", amountMl: 2500 });
      logSleep(db, {
        startTime: "2026-01-09T23:00:00",
        endTime: "2026-01-10T07:00:00", // 480 min
      });

      // Day 2: no food (0 cal <= 2000 = compliant), no water (0 < 2000 = not compliant), no sleep
      // Day 3: over calories
      logFood(db, {
        date: "2026-01-12",
        mealId: "meal-lunch",
        foodItemId: chicken.id,
        servingGrams: 1500, // 2475 cal > 2000
      });

      const stats = getRangeStats(db, "2026-01-10", "2026-01-12");

      expect(stats.compliance).not.toBeNull();
      expect(stats.compliance!.totalDays).toBe(3);
      // Calories: day1 (330 <= 2000 ✓), day2 (0 <= 2000 ✓), day3 (2475 > 2000 ✗)
      expect(stats.compliance!.caloriesDays).toBe(2);
      expect(stats.compliance!.caloriesRate).toBe(67);
      // Protein: day1 (620 >= 200 ✓), day2 (0 < 200 ✗), day3 (4650 >= 200 ✓)
      expect(stats.compliance!.proteinDays).toBe(2);
      expect(stats.compliance!.proteinRate).toBe(67);
      // Water: day1 (2500 >= 2000 ✓), day2 (0 ✗), day3 (0 ✗)
      expect(stats.compliance!.waterDays).toBe(1);
      expect(stats.compliance!.waterRate).toBe(33);
      // Sleep: day1 (480 >= 420 ✓), day2 (0 ✗), day3 (0 ✗)
      expect(stats.compliance!.sleepDays).toBe(1);
      expect(stats.compliance!.sleepRate).toBe(33);
    });

    it("returns compliance null when no target exists", () => {
      logFood(db, {
        date: "2026-01-10",
        mealId: "meal-lunch",
        foodItemId: chicken.id,
        servingGrams: 200,
      });

      const stats = getRangeStats(db, "2026-01-10", "2026-01-12");
      expect(stats.compliance).toBeNull();
    });
  });
});
