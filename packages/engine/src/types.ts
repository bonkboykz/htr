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

export interface DayStats {
  date: string;
  calories: number;
  protein: number;
  fat: number;
  carbs: number;
  waterMl: number;
  sleepMinutes: number;
}

export interface Compliance {
  totalDays: number;
  caloriesDays: number;
  proteinDays: number;
  waterDays: number;
  sleepDays: number;
  caloriesRate: number;
  proteinRate: number;
  waterRate: number;
  sleepRate: number;
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
  days: DayStats[];
  compliance: Compliance | null;
}

// ---------- Training domain ----------

export interface Exercise {
  id: string;
  name: string;
  nameRu: string;
  muscleGroup: string;
  pattern: string;
  equipment: string; // JSON array string
  isUnilateral: number;
  isSafeLowerBack: number;
  defaultRepMin: number;
  defaultRepMax: number;
  minIncrementG: number;
  videoQuery: string | null;
  cuesRu: string | null;
  isDeleted: number;
  createdAt: string;
}

export interface Routine {
  id: string;
  name: string;
  nameRu: string;
  notes: string | null;
  sortOrder: number;
  isDeleted: number;
  createdAt: string;
}

export interface RoutineExercise {
  id: string;
  routineId: string;
  exerciseId: string;
  section: string; // warmup | main | reab
  sortOrder: number;
  targetSets: number;
  repMin: number;
  repMax: number;
  targetRir: number;
  isRampupScaled: number;
  notes: string | null;
  isDeleted: number;
}

export interface WorkoutSession {
  id: string;
  routineId: string;
  sessionIndex: number;
  startedAt: string;
  endedAt: string | null;
  notes: string | null;
  isDeleted: number;
}

export interface SetRow {
  id: string;
  sessionId: string;
  exerciseId: string;
  setNumber: number;
  weightG: number;
  reps: number;
  rir: number | null;
  isWarmup: number;
  isDeleted: number;
  createdAt: string;
}

export type ProgressionAction = "increase" | "hold" | "deload_or_hold" | "rampup";

export interface ProgressionSuggestion {
  exerciseId: string;
  action: ProgressionAction;
  weightG: number;
  repsTarget: number | null;
  rirTarget: number | null;
  rationale: string;
}

export interface RoutinePlanItem {
  routineExercise: RoutineExercise;
  exercise: Exercise | null;
  lastPerformance: SetRow[];
  suggestion: ProgressionSuggestion | null;
}

export interface RoutinePlan {
  routine: Routine;
  sessionIndex: number;
  isRampup: boolean;
  sections: {
    warmup: RoutinePlanItem[];
    main: RoutinePlanItem[];
    reab: RoutinePlanItem[];
  };
}

export interface ProgressionPoint {
  sessionId: string;
  date: string; // YYYY-MM-DD of the session
  weightG: number; // top working set weight
  reps: number;
  e1rmG: number; // Epley estimate
}

export interface ProgressionHistory {
  exerciseId: string;
  points: ProgressionPoint[];
  currentE1rmG: number;
  changeE1rmG: number; // vs first point
}

export interface VolumeGroupStat {
  muscleGroup: string;
  volumeG: number; // SUM(weight_g * reps)
  sets: number;
}

export interface VolumeByGroup {
  from: string | null;
  to: string | null;
  byGroup: VolumeGroupStat[];
  totalVolumeG: number;
}

export interface SessionSummary {
  id: string;
  routineId: string;
  routineName: string;
  sessionIndex: number;
  startedAt: string;
  endedAt: string | null;
  durationS: number | null;
  totalSets: number; // working sets
  totalVolumeG: number;
}

export interface TrainingRange {
  from?: string; // YYYY-MM-DD inclusive
  to?: string; // YYYY-MM-DD inclusive
}
