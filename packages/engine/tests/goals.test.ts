import { describe, it, expect, beforeAll } from "vitest";
import {
  setupTestDb,
  setProfile,
  logWeight,
  setWeightGoal,
  getActiveGoal,
  getGoalProgress,
  deleteWeightGoal,
  type DB,
} from "../src/index.js";

describe("Weight Goals Engine", () => {
  let db: DB;

  beforeAll(() => {
    db = setupTestDb();
    // Setup profile and weight for goal tests
    setProfile(db, {
      heightCm: 178,
      birthDate: "1998-05-15",
      sex: "male",
      activityLevel: "moderate",
    });
    logWeight(db, { date: "2026-03-09", weightGrams: 78000 });
  });

  describe("setWeightGoal", () => {
    it("throws without weight entries", () => {
      const freshDb = setupTestDb();
      expect(() => setWeightGoal(freshDb, { targetGrams: 70000 })).toThrow(
        "No weight entries found"
      );
    });

    it("creates a weight goal", () => {
      const goal = setWeightGoal(db, { targetGrams: 70000, pace: "normal" });
      expect(goal.targetGrams).toBe(70000);
      expect(goal.startGrams).toBe(78000);
      expect(goal.pace).toBe("normal");
      expect(goal.isActive).toBe(1);
    });

    it("deactivates previous goal when setting new one", () => {
      const goal1 = getActiveGoal(db);
      expect(goal1).not.toBeNull();
      const goal1Id = goal1!.id;

      const goal2 = setWeightGoal(db, { targetGrams: 72000, pace: "slow" });
      expect(goal2.isActive).toBe(1);

      // Previous goal should be deactivated
      const oldGoal = getActiveGoal(db);
      expect(oldGoal).not.toBeNull();
      expect(oldGoal!.id).toBe(goal2.id);
      expect(oldGoal!.id).not.toBe(goal1Id);
    });

    it("defaults pace to normal", () => {
      const goal = setWeightGoal(db, { targetGrams: 73000 });
      expect(goal.pace).toBe("normal");
    });
  });

  describe("getActiveGoal", () => {
    it("returns active goal", () => {
      const goal = getActiveGoal(db);
      expect(goal).not.toBeNull();
      expect(goal!.isActive).toBe(1);
    });

    it("returns null when no active goal", () => {
      const freshDb = setupTestDb();
      expect(getActiveGoal(freshDb)).toBeNull();
    });
  });

  describe("getGoalProgress", () => {
    it("returns null when no active goal", () => {
      const freshDb = setupTestDb();
      expect(getGoalProgress(freshDb)).toBeNull();
    });

    it("calculates progress for weight loss goal", () => {
      const progress = getGoalProgress(db);
      expect(progress).not.toBeNull();
      expect(progress!.direction).toBe("loss");
      expect(progress!.currentGrams).toBe(78000);
      expect(progress!.remainingGrams).toBeGreaterThan(0);
      expect(progress!.progressPercent).toBeGreaterThanOrEqual(0);
      expect(progress!.estimatedDaysLeft).toBeGreaterThan(0);
      expect(progress!.estimatedDate).toMatch(/^\d{4}-\d{2}-\d{2}$/);
    });

    it("includes TDEE when profile exists", () => {
      const progress = getGoalProgress(db);
      expect(progress!.tdee).not.toBeNull();
      expect(progress!.tdee!.bmr).toBeGreaterThan(0);
      expect(progress!.tdee!.deficit).not.toBe(0); // has active goal
    });
  });

  describe("deleteWeightGoal", () => {
    it("soft deletes and deactivates goal", () => {
      const goal = getActiveGoal(db);
      expect(goal).not.toBeNull();

      deleteWeightGoal(db, goal!.id);
      expect(getActiveGoal(db)).toBeNull();
    });
  });
});
