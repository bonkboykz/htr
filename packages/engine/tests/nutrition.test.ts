import { describe, it, expect, beforeEach } from "vitest";
import { setupTestDb } from "../src/test-helpers.js";
import {
  createFoodItem,
  updateFoodItem,
  deleteFoodItem,
  getFoodItem,
  listFoodItems,
  logFood,
  quickLog,
  deleteFoodLog,
  getDailyNutrition,
  setTarget,
} from "../src/index.js";
import type { DB, FoodItem } from "../src/index.js";

describe("nutrition engine", () => {
  let db: DB;

  beforeEach(() => {
    db = setupTestDb();
  });

  describe("createFoodItem", () => {
    it("creates a food item with required fields", () => {
      const item = createFoodItem(db, {
        name: "Chicken Breast",
        caloriesPer100g: 165,
        proteinPer100g: 310,
        fatPer100g: 36,
        carbsPer100g: 0,
      });

      expect(item.id).toBeDefined();
      expect(item.name).toBe("Chicken Breast");
      expect(item.caloriesPer100g).toBe(165);
      expect(item.proteinPer100g).toBe(310);
      expect(item.fatPer100g).toBe(36);
      expect(item.carbsPer100g).toBe(0);
      expect(item.fiberPer100g).toBe(0);
      expect(item.servingSizeG).toBe(100);
      expect(item.brand).toBeNull();
      expect(item.barcode).toBeNull();
      expect(item.isDeleted).toBe(0);
    });

    it("creates a food item with optional fields", () => {
      const item = createFoodItem(db, {
        name: "Greek Yogurt",
        brand: "Fage",
        caloriesPer100g: 97,
        proteinPer100g: 90,
        fatPer100g: 50,
        carbsPer100g: 33,
        fiberPer100g: 0,
        servingSizeG: 150,
        barcode: "1234567890",
      });

      expect(item.brand).toBe("Fage");
      expect(item.servingSizeG).toBe(150);
      expect(item.barcode).toBe("1234567890");
    });
  });

  describe("updateFoodItem", () => {
    it("updates partial fields", () => {
      const item = createFoodItem(db, {
        name: "Chicken Breast",
        caloriesPer100g: 165,
        proteinPer100g: 310,
        fatPer100g: 36,
        carbsPer100g: 0,
      });

      const updated = updateFoodItem(db, item.id, {
        name: "Grilled Chicken Breast",
        caloriesPer100g: 170,
      });

      expect(updated).not.toBeNull();
      expect(updated!.name).toBe("Grilled Chicken Breast");
      expect(updated!.caloriesPer100g).toBe(170);
      // Unchanged fields remain
      expect(updated!.proteinPer100g).toBe(310);
    });

    it("returns null for non-existent item", () => {
      const result = updateFoodItem(db, "nonexistent", { name: "Test" });
      expect(result).toBeNull();
    });
  });

  describe("deleteFoodItem", () => {
    it("soft deletes a food item", () => {
      const item = createFoodItem(db, {
        name: "Chicken Breast",
        caloriesPer100g: 165,
        proteinPer100g: 310,
        fatPer100g: 36,
        carbsPer100g: 0,
      });

      deleteFoodItem(db, item.id);

      const result = getFoodItem(db, item.id);
      expect(result).toBeNull();
    });
  });

  describe("getFoodItem", () => {
    it("returns the food item by ID", () => {
      const item = createFoodItem(db, {
        name: "Rice",
        caloriesPer100g: 130,
        proteinPer100g: 27,
        fatPer100g: 3,
        carbsPer100g: 280,
      });

      const result = getFoodItem(db, item.id);
      expect(result).not.toBeNull();
      expect(result!.name).toBe("Rice");
    });

    it("returns null for deleted items", () => {
      const item = createFoodItem(db, {
        name: "Rice",
        caloriesPer100g: 130,
        proteinPer100g: 27,
        fatPer100g: 3,
        carbsPer100g: 280,
      });
      deleteFoodItem(db, item.id);

      expect(getFoodItem(db, item.id)).toBeNull();
    });

    it("returns null for non-existent ID", () => {
      expect(getFoodItem(db, "nonexistent")).toBeNull();
    });
  });

  describe("listFoodItems", () => {
    let chicken: FoodItem;
    let rice: FoodItem;

    beforeEach(() => {
      chicken = createFoodItem(db, {
        name: "Chicken Breast",
        caloriesPer100g: 165,
        proteinPer100g: 310,
        fatPer100g: 36,
        carbsPer100g: 0,
      });
      rice = createFoodItem(db, {
        name: "White Rice",
        caloriesPer100g: 130,
        proteinPer100g: 27,
        fatPer100g: 3,
        carbsPer100g: 280,
      });
    });

    it("lists all non-deleted food items", () => {
      const items = listFoodItems(db);
      expect(items).toHaveLength(2);
    });

    it("filters by search query", () => {
      const items = listFoodItems(db, "Chicken");
      expect(items).toHaveLength(1);
      expect(items[0].name).toBe("Chicken Breast");
    });

    it("search is case-sensitive by default (LIKE)", () => {
      const items = listFoodItems(db, "Rice");
      expect(items).toHaveLength(1);
      expect(items[0].name).toBe("White Rice");
    });

    it("excludes deleted items from list", () => {
      deleteFoodItem(db, chicken.id);
      const items = listFoodItems(db);
      expect(items).toHaveLength(1);
      expect(items[0].name).toBe("White Rice");
    });

    it("returns empty array when nothing matches", () => {
      const items = listFoodItems(db, "Broccoli");
      expect(items).toHaveLength(0);
    });
  });

  describe("logFood", () => {
    let chicken: FoodItem;

    beforeEach(() => {
      chicken = createFoodItem(db, {
        name: "Chicken Breast",
        caloriesPer100g: 165,
        proteinPer100g: 310,
        fatPer100g: 36,
        carbsPer100g: 0,
        fiberPer100g: 0,
      });
    });

    it("pre-computes macros from food item and serving grams", () => {
      const log = logFood(db, {
        date: "2026-01-15",
        mealId: "meal-lunch",
        foodItemId: chicken.id,
        servingGrams: 200,
      });

      expect(log.id).toBeDefined();
      expect(log.date).toBe("2026-01-15");
      expect(log.mealId).toBe("meal-lunch");
      expect(log.foodItemId).toBe(chicken.id);
      expect(log.servingGrams).toBe(200);
      // Math.round(165 * 200 / 100) = 330
      expect(log.calories).toBe(330);
      // Math.round(310 * 200 / 100) = 620
      expect(log.protein).toBe(620);
      // Math.round(36 * 200 / 100) = 72
      expect(log.fat).toBe(72);
      expect(log.carbs).toBe(0);
      expect(log.fiber).toBe(0);
    });

    it("computes correctly for non-100g servings", () => {
      const log = logFood(db, {
        date: "2026-01-15",
        mealId: "meal-breakfast",
        foodItemId: chicken.id,
        servingGrams: 150,
      });

      // Math.round(165 * 150 / 100) = 248
      expect(log.calories).toBe(248);
      // Math.round(310 * 150 / 100) = 465
      expect(log.protein).toBe(465);
    });

    it("throws error for non-existent food item", () => {
      expect(() =>
        logFood(db, {
          date: "2026-01-15",
          mealId: "meal-lunch",
          foodItemId: "nonexistent",
          servingGrams: 100,
        })
      ).toThrow("Food item not found");
    });
  });

  describe("quickLog", () => {
    it("creates food item and logs it with 100g serving", () => {
      const log = quickLog(db, {
        date: "2026-01-15",
        mealId: "meal-snack",
        name: "Protein Bar",
        calories: 200,
        protein: 150,
        fat: 80,
        carbs: 220,
      });

      expect(log.date).toBe("2026-01-15");
      expect(log.mealId).toBe("meal-snack");
      expect(log.servingGrams).toBe(100);
      expect(log.calories).toBe(200);
      expect(log.protein).toBe(150);
      expect(log.fat).toBe(80);
      expect(log.carbs).toBe(220);
    });

    it("defaults optional macros to 0", () => {
      const log = quickLog(db, {
        date: "2026-01-15",
        mealId: "meal-snack",
        name: "Mystery Snack",
        calories: 150,
      });

      expect(log.protein).toBe(0);
      expect(log.fat).toBe(0);
      expect(log.carbs).toBe(0);
      expect(log.fiber).toBe(0);
    });

    it("auto-creates a food item that can be retrieved", () => {
      const log = quickLog(db, {
        date: "2026-01-15",
        mealId: "meal-snack",
        name: "Quick Oats",
        calories: 370,
      });

      const foodItem = getFoodItem(db, log.foodItemId);
      expect(foodItem).not.toBeNull();
      expect(foodItem!.name).toBe("Quick Oats");
      expect(foodItem!.caloriesPer100g).toBe(370);
    });
  });

  describe("deleteFoodLog", () => {
    it("soft deletes a food log entry", () => {
      const chicken = createFoodItem(db, {
        name: "Chicken",
        caloriesPer100g: 165,
        proteinPer100g: 310,
        fatPer100g: 36,
        carbsPer100g: 0,
      });

      const log = logFood(db, {
        date: "2026-01-15",
        mealId: "meal-lunch",
        foodItemId: chicken.id,
        servingGrams: 200,
      });

      deleteFoodLog(db, log.id);

      const nutrition = getDailyNutrition(db, "2026-01-15");
      expect(nutrition.totals.calories).toBe(0);
    });
  });

  describe("getDailyNutrition", () => {
    it("returns all system meals with empty entries when no logs", () => {
      const nutrition = getDailyNutrition(db, "2026-01-15");

      expect(nutrition.date).toBe("2026-01-15");
      expect(nutrition.meals).toHaveLength(4);
      expect(nutrition.meals[0].meal.id).toBe("meal-breakfast");
      expect(nutrition.meals[1].meal.id).toBe("meal-lunch");
      expect(nutrition.meals[2].meal.id).toBe("meal-dinner");
      expect(nutrition.meals[3].meal.id).toBe("meal-snack");
      expect(nutrition.totals.calories).toBe(0);
    });

    it("groups food logs by meal and computes totals", () => {
      const chicken = createFoodItem(db, {
        name: "Chicken",
        caloriesPer100g: 165,
        proteinPer100g: 310,
        fatPer100g: 36,
        carbsPer100g: 0,
      });
      const rice = createFoodItem(db, {
        name: "Rice",
        caloriesPer100g: 130,
        proteinPer100g: 27,
        fatPer100g: 3,
        carbsPer100g: 280,
      });

      logFood(db, {
        date: "2026-01-15",
        mealId: "meal-lunch",
        foodItemId: chicken.id,
        servingGrams: 200,
      });
      logFood(db, {
        date: "2026-01-15",
        mealId: "meal-lunch",
        foodItemId: rice.id,
        servingGrams: 150,
      });

      const nutrition = getDailyNutrition(db, "2026-01-15");

      // Lunch should have 2 entries
      const lunch = nutrition.meals.find((m) => m.meal.id === "meal-lunch")!;
      expect(lunch.entries).toHaveLength(2);

      // Breakfast should have 0 entries
      const breakfast = nutrition.meals.find(
        (m) => m.meal.id === "meal-breakfast"
      )!;
      expect(breakfast.entries).toHaveLength(0);

      // Totals: chicken(200g) + rice(150g)
      // calories: 330 + 195 = 525
      expect(nutrition.totals.calories).toBe(
        Math.round((165 * 200) / 100) + Math.round((130 * 150) / 100)
      );
    });

    it("excludes deleted food logs from totals", () => {
      const chicken = createFoodItem(db, {
        name: "Chicken",
        caloriesPer100g: 165,
        proteinPer100g: 310,
        fatPer100g: 36,
        carbsPer100g: 0,
      });

      const log1 = logFood(db, {
        date: "2026-01-15",
        mealId: "meal-lunch",
        foodItemId: chicken.id,
        servingGrams: 200,
      });
      logFood(db, {
        date: "2026-01-15",
        mealId: "meal-dinner",
        foodItemId: chicken.id,
        servingGrams: 150,
      });

      deleteFoodLog(db, log1.id);

      const nutrition = getDailyNutrition(db, "2026-01-15");
      // Only dinner log remains: Math.round(165 * 150 / 100) = 248
      expect(nutrition.totals.calories).toBe(248);
    });

    it("includes active target when set", () => {
      setTarget(db, {
        effectiveDate: "2026-01-01",
        calories: 2000,
        protein: 1500,
        fat: 700,
        carbs: 2500,
      });

      const nutrition = getDailyNutrition(db, "2026-01-15");
      expect(nutrition.target).not.toBeNull();
      expect(nutrition.target!.calories).toBe(2000);
    });

    it("returns null target when none set", () => {
      const nutrition = getDailyNutrition(db, "2026-01-15");
      expect(nutrition.target).toBeNull();
    });
  });
});
