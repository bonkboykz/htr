export interface FoodItem {
  id: string;
  name: string;
  brand: string | null;
  caloriesPer100g: number;
  proteinPer100g: number;
  fatPer100g: number;
  carbsPer100g: number;
  fiberPer100g: number;
  servingSizeG: number;
  barcode: string | null;
  isDeleted: number;
  createdAt: string;
}

export interface Meal {
  id: string;
  name: string;
  sortOrder: number;
  isSystem: number;
  isDeleted: number;
  createdAt: string;
}

export interface FoodLogEntry {
  id: string;
  date: string;
  mealId: string;
  foodItemId: string;
  servingGrams: number;
  calories: number;
  protein: number;
  fat: number;
  carbs: number;
  fiber: number;
  isDeleted: number;
  createdAt: string;
}

export interface DailyTarget {
  id: string;
  effectiveDate: string;
  calories: number;
  protein: number;
  fat: number;
  carbs: number;
  waterMl: number;
  sleepMinutes: number;
  isDeleted: number;
  createdAt: string;
}

export interface WeightLogEntry {
  id: string;
  date: string;
  weightGrams: number;
  bodyFat: number | null;
  note: string | null;
  isDeleted: number;
  createdAt: string;
}

export interface WaterLogEntry {
  id: string;
  date: string;
  amountMl: number;
  isDeleted: number;
  createdAt: string;
}

export interface SleepLogEntry {
  id: string;
  startTime: string;
  endTime: string;
  quality: number | null;
  note: string | null;
  isDeleted: number;
  createdAt: string;
}

export interface MacroTotals {
  calories: number;
  protein: number;
  fat: number;
  carbs: number;
  fiber: number;
}

export interface DailyNutrition {
  date: string;
  meals: { meal: Meal; entries: FoodLogEntry[] }[];
  totals: MacroTotals;
  target: DailyTarget | null;
}

export interface DailySummary {
  date: string;
  nutrition: DailyNutrition;
  water: { totalMl: number; targetMl: number };
  sleep: { totalMinutes: number; targetMinutes: number; quality: number | null };
  weight: WeightLogEntry | null;
}

export interface WeightTrend {
  entries: WeightLogEntry[];
  trendGrams: number;
  changeGrams: number;
}

export interface WeekSummary {
  weekStart: string;
  avgCalories: number;
  avgProtein: number;
  avgFat: number;
  avgCarbs: number;
  avgWaterMl: number;
  avgSleepMinutes: number;
  daysLogged: number;
}

export interface Streaks {
  foodLogging: { current: number; best: number };
  waterGoal: { current: number; best: number };
  sleepGoal: { current: number; best: number };
}

export interface UserProfile {
  id: string;
  heightCm: number;
  birthDate: string;
  sex: string;
  activityLevel: string;
  createdAt: string;
  updatedAt: string;
}

export interface TdeeCalculation {
  bmr: number;
  tdee: number;
  targetCalories: number;
  deficit: number;
}

export interface WeightGoal {
  id: string;
  targetGrams: number;
  pace: string;
  startDate: string;
  startGrams: number;
  isActive: number;
  isDeleted: number;
  createdAt: string;
}

export interface WeightGoalProgress {
  goal: WeightGoal;
  currentGrams: number;
  remainingGrams: number;
  progressPercent: number;
  estimatedDaysLeft: number;
  estimatedDate: string;
  direction: "loss" | "gain";
  tdee: TdeeCalculation | null;
}

export interface RangeStats {
  from: string;
  to: string;
  avgCalories: number;
  avgProtein: number;
  avgFat: number;
  avgCarbs: number;
  avgWaterMl: number;
  avgSleepMinutes: number;
  daysLogged: number;
}
