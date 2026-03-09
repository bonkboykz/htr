import { sqliteTable, text, integer } from "drizzle-orm/sqlite-core";

export const foodItems = sqliteTable("food_items", {
  id: text("id").primaryKey(),
  name: text("name").notNull(),
  brand: text("brand"),
  caloriesPer100g: integer("calories_per_100g").notNull(),
  proteinPer100g: integer("protein_per_100g").notNull(),
  fatPer100g: integer("fat_per_100g").notNull(),
  carbsPer100g: integer("carbs_per_100g").notNull(),
  fiberPer100g: integer("fiber_per_100g").notNull().default(0),
  servingSizeG: integer("serving_size_g").notNull().default(100),
  barcode: text("barcode"),
  isDeleted: integer("is_deleted").notNull().default(0),
  createdAt: text("created_at")
    .notNull()
    .$defaultFn(() => new Date().toISOString()),
});

export const meals = sqliteTable("meals", {
  id: text("id").primaryKey(),
  name: text("name").notNull(),
  sortOrder: integer("sort_order").notNull(),
  isSystem: integer("is_system").notNull().default(0),
  isDeleted: integer("is_deleted").notNull().default(0),
  createdAt: text("created_at")
    .notNull()
    .$defaultFn(() => new Date().toISOString()),
});

export const foodLogs = sqliteTable("food_logs", {
  id: text("id").primaryKey(),
  date: text("date").notNull(),
  mealId: text("meal_id").notNull(),
  foodItemId: text("food_item_id").notNull(),
  servingGrams: integer("serving_grams").notNull(),
  calories: integer("calories").notNull(),
  protein: integer("protein").notNull(),
  fat: integer("fat").notNull(),
  carbs: integer("carbs").notNull(),
  fiber: integer("fiber").notNull().default(0),
  isDeleted: integer("is_deleted").notNull().default(0),
  createdAt: text("created_at")
    .notNull()
    .$defaultFn(() => new Date().toISOString()),
});

export const dailyTargets = sqliteTable("daily_targets", {
  id: text("id").primaryKey(),
  effectiveDate: text("effective_date").notNull(),
  calories: integer("calories").notNull(),
  protein: integer("protein").notNull(),
  fat: integer("fat").notNull(),
  carbs: integer("carbs").notNull(),
  waterMl: integer("water_ml").notNull().default(2500),
  sleepMinutes: integer("sleep_minutes").notNull().default(480),
  isDeleted: integer("is_deleted").notNull().default(0),
  createdAt: text("created_at")
    .notNull()
    .$defaultFn(() => new Date().toISOString()),
});

export const weightLogs = sqliteTable("weight_logs", {
  id: text("id").primaryKey(),
  date: text("date").notNull().unique(),
  weightGrams: integer("weight_grams").notNull(),
  bodyFat: integer("body_fat"),
  note: text("note"),
  isDeleted: integer("is_deleted").notNull().default(0),
  createdAt: text("created_at")
    .notNull()
    .$defaultFn(() => new Date().toISOString()),
});

export const waterLogs = sqliteTable("water_logs", {
  id: text("id").primaryKey(),
  date: text("date").notNull(),
  amountMl: integer("amount_ml").notNull(),
  isDeleted: integer("is_deleted").notNull().default(0),
  createdAt: text("created_at")
    .notNull()
    .$defaultFn(() => new Date().toISOString()),
});

export const sleepLogs = sqliteTable("sleep_logs", {
  id: text("id").primaryKey(),
  startTime: text("start_time").notNull(),
  endTime: text("end_time").notNull(),
  quality: integer("quality"),
  note: text("note"),
  isDeleted: integer("is_deleted").notNull().default(0),
  createdAt: text("created_at")
    .notNull()
    .$defaultFn(() => new Date().toISOString()),
});
