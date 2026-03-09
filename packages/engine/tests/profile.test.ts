import { describe, it, expect, beforeAll } from "vitest";
import {
  setupTestDb,
  setProfile,
  getProfile,
  calculateAge,
  calculateBmr,
  calculateTdee,
  getTargetCalories,
  logWeight,
  type DB,
  type UserProfile,
} from "../src/index.js";

describe("Profile Engine", () => {
  let db: DB;

  beforeAll(() => {
    db = setupTestDb();
  });

  describe("setProfile / getProfile", () => {
    it("returns null when no profile exists", () => {
      expect(getProfile(db)).toBeNull();
    });

    it("creates a new profile", () => {
      const profile = setProfile(db, {
        heightCm: 178,
        birthDate: "1998-05-15",
        sex: "male",
        activityLevel: "moderate",
      });
      expect(profile.id).toBe("default");
      expect(profile.heightCm).toBe(178);
      expect(profile.sex).toBe("male");
      expect(profile.activityLevel).toBe("moderate");
    });

    it("retrieves existing profile", () => {
      const profile = getProfile(db);
      expect(profile).not.toBeNull();
      expect(profile!.heightCm).toBe(178);
    });

    it("updates existing profile (upsert)", () => {
      const profile = setProfile(db, {
        heightCm: 180,
        birthDate: "1998-05-15",
        sex: "male",
        activityLevel: "active",
      });
      expect(profile.heightCm).toBe(180);
      expect(profile.activityLevel).toBe("active");
    });

    it("preserves activity level if not provided on update", () => {
      const profile = setProfile(db, {
        heightCm: 180,
        birthDate: "1998-05-15",
        sex: "male",
      });
      expect(profile.activityLevel).toBe("active");
    });
  });

  describe("calculateAge", () => {
    it("calculates age correctly", () => {
      const age = calculateAge("1998-05-15", "2026-03-09");
      expect(age).toBe(27);
    });

    it("handles birthday not yet passed this year", () => {
      const age = calculateAge("1998-12-15", "2026-03-09");
      expect(age).toBe(27);
    });

    it("handles birthday already passed", () => {
      const age = calculateAge("1998-01-01", "2026-03-09");
      expect(age).toBe(28);
    });
  });

  describe("calculateBmr", () => {
    it("calculates BMR for male (Mifflin-St Jeor)", () => {
      const profile: UserProfile = {
        id: "default",
        heightCm: 178,
        birthDate: "1998-05-15",
        sex: "male",
        activityLevel: "moderate",
        createdAt: "",
        updatedAt: "",
      };
      // Male: 10 * 75.5 + 6.25 * 178 - 5 * 27 + 5
      // = 755 + 1112.5 - 135 + 5 = 1737.5 → 1738
      const bmr = calculateBmr(profile, 75500);
      expect(bmr).toBe(1738);
    });

    it("calculates BMR for female", () => {
      const profile: UserProfile = {
        id: "default",
        heightCm: 165,
        birthDate: "1998-05-15",
        sex: "female",
        activityLevel: "moderate",
        createdAt: "",
        updatedAt: "",
      };
      // Female: 10 * 60 + 6.25 * 165 - 5 * 27 - 161
      // = 600 + 1031.25 - 135 - 161 = 1335.25 → 1335
      const bmr = calculateBmr(profile, 60000);
      expect(bmr).toBe(1335);
    });
  });

  describe("calculateTdee", () => {
    it("applies sedentary multiplier", () => {
      expect(calculateTdee(1738, "sedentary")).toBe(Math.round(1738 * 1.2));
    });

    it("applies moderate multiplier", () => {
      expect(calculateTdee(1738, "moderate")).toBe(Math.round(1738 * 1.55));
    });

    it("applies very_active multiplier", () => {
      expect(calculateTdee(1738, "very_active")).toBe(Math.round(1738 * 1.9));
    });
  });

  describe("getTargetCalories", () => {
    it("returns null without profile", () => {
      const freshDb = setupTestDb();
      expect(getTargetCalories(freshDb)).toBeNull();
    });

    it("returns null without weight log", () => {
      const freshDb = setupTestDb();
      setProfile(freshDb, {
        heightCm: 178,
        birthDate: "1998-05-15",
        sex: "male",
      });
      expect(getTargetCalories(freshDb)).toBeNull();
    });

    it("returns TDEE calculation with profile and weight", () => {
      // db already has profile from earlier tests
      logWeight(db, { date: "2026-03-09", weightGrams: 75500 });
      const result = getTargetCalories(db);
      expect(result).not.toBeNull();
      expect(result!.bmr).toBeGreaterThan(0);
      expect(result!.tdee).toBeGreaterThan(result!.bmr);
      expect(result!.deficit).toBe(0); // no goal set in this db yet
      expect(result!.targetCalories).toBe(result!.tdee);
    });
  });
});
