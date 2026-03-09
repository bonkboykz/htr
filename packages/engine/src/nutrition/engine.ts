import { eq, and, like } from "drizzle-orm";
import type { DB } from "../db/index.js";
import { schema } from "../db/index.js";
import { newId } from "../id.js";
import { getActiveTarget } from "../targets/engine.js";
import type { FoodItem, FoodLogEntry, DailyNutrition, Meal } from "../types.js";

export function createFoodItem(
  db: DB,
  data: {
    name: string;
    brand?: string;
    caloriesPer100g: number;
    proteinPer100g: number;
    fatPer100g: number;
    carbsPer100g: number;
    fiberPer100g?: number;
    servingSizeG?: number;
    barcode?: string;
  }
): FoodItem {
  const id = newId();
  db.insert(schema.foodItems)
    .values({
      id,
      name: data.name,
      brand: data.brand ?? null,
      caloriesPer100g: data.caloriesPer100g,
      proteinPer100g: data.proteinPer100g,
      fatPer100g: data.fatPer100g,
      carbsPer100g: data.carbsPer100g,
      fiberPer100g: data.fiberPer100g ?? 0,
      servingSizeG: data.servingSizeG ?? 100,
      barcode: data.barcode ?? null,
    })
    .run();
  return db
    .select()
    .from(schema.foodItems)
    .where(eq(schema.foodItems.id, id))
    .get()! as FoodItem;
}

export function updateFoodItem(
  db: DB,
  id: string,
  data: Partial<{
    name: string;
    brand: string | null;
    caloriesPer100g: number;
    proteinPer100g: number;
    fatPer100g: number;
    carbsPer100g: number;
    fiberPer100g: number;
    servingSizeG: number;
    barcode: string | null;
  }>
): FoodItem | null {
  db.update(schema.foodItems).set(data).where(eq(schema.foodItems.id, id)).run();
  return (
    (db
      .select()
      .from(schema.foodItems)
      .where(and(eq(schema.foodItems.id, id), eq(schema.foodItems.isDeleted, 0)))
      .get() as FoodItem) ?? null
  );
}

export function deleteFoodItem(db: DB, id: string): void {
  db.update(schema.foodItems)
    .set({ isDeleted: 1 })
    .where(eq(schema.foodItems.id, id))
    .run();
}

export function getFoodItem(db: DB, id: string): FoodItem | null {
  return (
    (db
      .select()
      .from(schema.foodItems)
      .where(and(eq(schema.foodItems.id, id), eq(schema.foodItems.isDeleted, 0)))
      .get() as FoodItem) ?? null
  );
}

export function listFoodItems(db: DB, query?: string): FoodItem[] {
  if (query) {
    return db
      .select()
      .from(schema.foodItems)
      .where(
        and(
          like(schema.foodItems.name, `%${query}%`),
          eq(schema.foodItems.isDeleted, 0)
        )
      )
      .all() as FoodItem[];
  }
  return db
    .select()
    .from(schema.foodItems)
    .where(eq(schema.foodItems.isDeleted, 0))
    .all() as FoodItem[];
}

function computeMacros(foodItem: FoodItem, servingGrams: number) {
  return {
    calories: Math.round((foodItem.caloriesPer100g * servingGrams) / 100),
    protein: Math.round((foodItem.proteinPer100g * servingGrams) / 100),
    fat: Math.round((foodItem.fatPer100g * servingGrams) / 100),
    carbs: Math.round((foodItem.carbsPer100g * servingGrams) / 100),
    fiber: Math.round((foodItem.fiberPer100g * servingGrams) / 100),
  };
}

export function logFood(
  db: DB,
  data: {
    date: string;
    mealId: string;
    foodItemId: string;
    servingGrams: number;
  }
): FoodLogEntry {
  const foodItem = getFoodItem(db, data.foodItemId);
  if (!foodItem) throw new Error(`Food item not found: ${data.foodItemId}`);

  const macros = computeMacros(foodItem, data.servingGrams);
  const id = newId();

  db.insert(schema.foodLogs)
    .values({
      id,
      date: data.date,
      mealId: data.mealId,
      foodItemId: data.foodItemId,
      servingGrams: data.servingGrams,
      ...macros,
    })
    .run();

  return db
    .select()
    .from(schema.foodLogs)
    .where(eq(schema.foodLogs.id, id))
    .get()! as FoodLogEntry;
}

export function quickLog(
  db: DB,
  data: {
    date: string;
    mealId: string;
    name: string;
    calories: number;
    protein?: number;
    fat?: number;
    carbs?: number;
    fiber?: number;
  }
): FoodLogEntry {
  const foodItem = createFoodItem(db, {
    name: data.name,
    caloriesPer100g: data.calories,
    proteinPer100g: data.protein ?? 0,
    fatPer100g: data.fat ?? 0,
    carbsPer100g: data.carbs ?? 0,
    fiberPer100g: data.fiber ?? 0,
    servingSizeG: 100,
  });

  const id = newId();
  db.insert(schema.foodLogs)
    .values({
      id,
      date: data.date,
      mealId: data.mealId,
      foodItemId: foodItem.id,
      servingGrams: 100,
      calories: data.calories,
      protein: data.protein ?? 0,
      fat: data.fat ?? 0,
      carbs: data.carbs ?? 0,
      fiber: data.fiber ?? 0,
    })
    .run();

  return db
    .select()
    .from(schema.foodLogs)
    .where(eq(schema.foodLogs.id, id))
    .get()! as FoodLogEntry;
}

export function deleteFoodLog(db: DB, id: string): void {
  db.update(schema.foodLogs)
    .set({ isDeleted: 1 })
    .where(eq(schema.foodLogs.id, id))
    .run();
}

export function getDailyNutrition(db: DB, date: string): DailyNutrition {
  const allMeals = db
    .select()
    .from(schema.meals)
    .where(eq(schema.meals.isDeleted, 0))
    .all() as Meal[];

  allMeals.sort((a, b) => a.sortOrder - b.sortOrder);

  const logs = db
    .select()
    .from(schema.foodLogs)
    .where(
      and(eq(schema.foodLogs.date, date), eq(schema.foodLogs.isDeleted, 0))
    )
    .all() as FoodLogEntry[];

  const mealGroups = allMeals.map((meal) => ({
    meal,
    entries: logs.filter((l) => l.mealId === meal.id),
  }));

  const totals = logs.reduce(
    (acc, log) => ({
      calories: acc.calories + log.calories,
      protein: acc.protein + log.protein,
      fat: acc.fat + log.fat,
      carbs: acc.carbs + log.carbs,
      fiber: acc.fiber + log.fiber,
    }),
    { calories: 0, protein: 0, fat: 0, carbs: 0, fiber: 0 }
  );

  const target = getActiveTarget(db, date);

  return { date, meals: mealGroups, totals, target };
}
