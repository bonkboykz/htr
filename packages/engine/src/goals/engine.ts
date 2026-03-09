import { eq, and } from "drizzle-orm";
import type { DB } from "../db/index.js";
import { schema } from "../db/index.js";
import { newId } from "../id.js";
import type { WeightGoal, WeightGoalProgress } from "../types.js";
import { getLatestWeight } from "../weight/engine.js";
import { getTargetCalories } from "../profile/engine.js";

const PACE_GRAMS_PER_DAY: Record<string, number> = {
  slow: Math.round((250 / 7) * 10) / 10,     // ~35.7 g/day
  normal: Math.round((500 / 7) * 10) / 10,    // ~71.4 g/day
  fast: Math.round((1000 / 7) * 10) / 10,     // ~142.9 g/day
};

export function setWeightGoal(
  db: DB,
  data: { targetGrams: number; pace?: string }
): WeightGoal {
  // Deactivate previous active goals
  db.update(schema.weightGoals)
    .set({ isActive: 0 })
    .where(eq(schema.weightGoals.isActive, 1))
    .run();

  const latestWeight = getLatestWeight(db);
  if (!latestWeight) {
    throw new Error("No weight entries found. Log your weight first.");
  }

  const id = newId();
  const today = new Date().toISOString().split("T")[0];

  db.insert(schema.weightGoals)
    .values({
      id,
      targetGrams: data.targetGrams,
      pace: data.pace ?? "normal",
      startDate: today,
      startGrams: latestWeight.weightGrams,
    })
    .run();

  return db
    .select()
    .from(schema.weightGoals)
    .where(eq(schema.weightGoals.id, id))
    .get()! as WeightGoal;
}

export function getActiveGoal(db: DB): WeightGoal | null {
  return (
    (db
      .select()
      .from(schema.weightGoals)
      .where(
        and(
          eq(schema.weightGoals.isActive, 1),
          eq(schema.weightGoals.isDeleted, 0)
        )
      )
      .get() as WeightGoal) ?? null
  );
}

export function getGoalProgress(db: DB): WeightGoalProgress | null {
  const goal = getActiveGoal(db);
  if (!goal) return null;

  const latestWeight = getLatestWeight(db);
  if (!latestWeight) return null;

  const currentGrams = latestWeight.weightGrams;
  const totalChange = Math.abs(goal.startGrams - goal.targetGrams);
  const currentChange = Math.abs(goal.startGrams - currentGrams);
  const progressPercent =
    totalChange > 0 ? Math.min(100, Math.round((currentChange / totalChange) * 100)) : 100;

  const remainingGrams = Math.abs(currentGrams - goal.targetGrams);
  const direction: "loss" | "gain" =
    goal.targetGrams < goal.startGrams ? "loss" : "gain";

  const paceGramsPerDay = PACE_GRAMS_PER_DAY[goal.pace] ?? PACE_GRAMS_PER_DAY.normal;
  const estimatedDaysLeft =
    paceGramsPerDay > 0 ? Math.ceil(remainingGrams / paceGramsPerDay) : 0;

  const estimatedDate = new Date();
  estimatedDate.setDate(estimatedDate.getDate() + estimatedDaysLeft);

  const tdee = getTargetCalories(db);

  return {
    goal,
    currentGrams,
    remainingGrams,
    progressPercent,
    estimatedDaysLeft,
    estimatedDate: estimatedDate.toISOString().split("T")[0],
    direction,
    tdee,
  };
}

export function deleteWeightGoal(db: DB, id: string): void {
  db.update(schema.weightGoals)
    .set({ isDeleted: 1, isActive: 0 })
    .where(eq(schema.weightGoals.id, id))
    .run();
}
