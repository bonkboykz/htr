import { eq } from "drizzle-orm";
import type { DB } from "../db/index.js";
import { schema } from "../db/index.js";
import type { UserProfile, TdeeCalculation } from "../types.js";
import { getLatestWeight } from "../weight/engine.js";

const ACTIVITY_MULTIPLIERS: Record<string, number> = {
  sedentary: 1.2,
  light: 1.375,
  moderate: 1.55,
  active: 1.725,
  very_active: 1.9,
};

const PACE_DEFICIT: Record<string, number> = {
  slow: 275,
  normal: 550,
  fast: 1100,
};

export function setProfile(
  db: DB,
  data: {
    heightCm: number;
    birthDate: string;
    sex: string;
    activityLevel?: string;
  }
): UserProfile {
  const now = new Date().toISOString();
  const existing = getProfile(db);

  if (existing) {
    db.update(schema.userProfile)
      .set({
        heightCm: data.heightCm,
        birthDate: data.birthDate,
        sex: data.sex,
        activityLevel: data.activityLevel ?? existing.activityLevel,
        updatedAt: now,
      })
      .where(eq(schema.userProfile.id, "default"))
      .run();
  } else {
    db.insert(schema.userProfile)
      .values({
        id: "default",
        heightCm: data.heightCm,
        birthDate: data.birthDate,
        sex: data.sex,
        activityLevel: data.activityLevel ?? "moderate",
        createdAt: now,
        updatedAt: now,
      })
      .run();
  }

  return db
    .select()
    .from(schema.userProfile)
    .where(eq(schema.userProfile.id, "default"))
    .get()! as UserProfile;
}

export function getProfile(db: DB): UserProfile | null {
  return (
    (db
      .select()
      .from(schema.userProfile)
      .where(eq(schema.userProfile.id, "default"))
      .get() as UserProfile) ?? null
  );
}

export function calculateAge(birthDate: string, atDate?: string): number {
  const birth = new Date(birthDate);
  const at = atDate ? new Date(atDate) : new Date();
  let age = at.getFullYear() - birth.getFullYear();
  const monthDiff = at.getMonth() - birth.getMonth();
  if (monthDiff < 0 || (monthDiff === 0 && at.getDate() < birth.getDate())) {
    age--;
  }
  return age;
}

export function calculateBmr(profile: UserProfile, weightGrams: number): number {
  const weightKg = weightGrams / 1000;
  const age = calculateAge(profile.birthDate);

  if (profile.sex === "male") {
    return Math.round(10 * weightKg + 6.25 * profile.heightCm - 5 * age + 5);
  }
  return Math.round(10 * weightKg + 6.25 * profile.heightCm - 5 * age - 161);
}

export function calculateTdee(bmr: number, activityLevel: string): number {
  const multiplier = ACTIVITY_MULTIPLIERS[activityLevel] ?? 1.55;
  return Math.round(bmr * multiplier);
}

export function getTargetCalories(db: DB, date?: string): TdeeCalculation | null {
  const profile = getProfile(db);
  if (!profile) return null;

  const latestWeight = getLatestWeight(db);
  if (!latestWeight) return null;

  const bmr = calculateBmr(profile, latestWeight.weightGrams);
  const tdee = calculateTdee(bmr, profile.activityLevel);

  // Check for active weight goal
  const activeGoal = db
    .select()
    .from(schema.weightGoals)
    .where(eq(schema.weightGoals.isActive, 1))
    .get();

  let deficit = 0;
  if (activeGoal) {
    const direction = activeGoal.targetGrams < activeGoal.startGrams ? "loss" : "gain";
    const paceDeficit = PACE_DEFICIT[activeGoal.pace] ?? 550;
    deficit = direction === "loss" ? -paceDeficit : paceDeficit;
  }

  return {
    bmr,
    tdee,
    targetCalories: tdee + deficit,
    deficit,
  };
}
