import { describe, it, expect, beforeEach } from "vitest";
import { setupTestDb } from "../src/test-helpers.js";
import { setTarget, getActiveTarget, listTargets } from "../src/index.js";
import type { DB } from "../src/index.js";

describe("targets engine", () => {
  let db: DB;

  beforeEach(() => {
    db = setupTestDb();
  });

  describe("setTarget", () => {
    it("creates a target with all fields", () => {
      const target = setTarget(db, {
        effectiveDate: "2026-01-01",
        calories: 2000,
        protein: 1500,
        fat: 700,
        carbs: 2500,
        waterMl: 3000,
        sleepMinutes: 420,
      });

      expect(target.id).toBeDefined();
      expect(target.effectiveDate).toBe("2026-01-01");
      expect(target.calories).toBe(2000);
      expect(target.protein).toBe(1500);
      expect(target.fat).toBe(700);
      expect(target.carbs).toBe(2500);
      expect(target.waterMl).toBe(3000);
      expect(target.sleepMinutes).toBe(420);
      expect(target.isDeleted).toBe(0);
    });

    it("uses default waterMl and sleepMinutes when omitted", () => {
      const target = setTarget(db, {
        effectiveDate: "2026-01-01",
        calories: 2000,
        protein: 1500,
        fat: 700,
        carbs: 2500,
      });

      expect(target.waterMl).toBe(2500);
      expect(target.sleepMinutes).toBe(480);
    });
  });

  describe("getActiveTarget", () => {
    it("returns null when no targets exist", () => {
      const result = getActiveTarget(db, "2026-01-15");
      expect(result).toBeNull();
    });

    it("returns the target effective on the given date", () => {
      setTarget(db, {
        effectiveDate: "2026-01-01",
        calories: 2000,
        protein: 1500,
        fat: 700,
        carbs: 2500,
      });

      const result = getActiveTarget(db, "2026-01-15");
      expect(result).not.toBeNull();
      expect(result!.calories).toBe(2000);
    });

    it("returns null when date is before all targets", () => {
      setTarget(db, {
        effectiveDate: "2026-02-01",
        calories: 2000,
        protein: 1500,
        fat: 700,
        carbs: 2500,
      });

      const result = getActiveTarget(db, "2026-01-15");
      expect(result).toBeNull();
    });

    it("picks the latest effective_date <= query date", () => {
      setTarget(db, {
        effectiveDate: "2026-01-01",
        calories: 2000,
        protein: 1500,
        fat: 700,
        carbs: 2500,
      });
      setTarget(db, {
        effectiveDate: "2026-02-01",
        calories: 2200,
        protein: 1600,
        fat: 800,
        carbs: 2600,
      });
      setTarget(db, {
        effectiveDate: "2026-03-01",
        calories: 1800,
        protein: 1400,
        fat: 600,
        carbs: 2400,
      });

      // Feb 15 should get the Feb 1 target
      const result = getActiveTarget(db, "2026-02-15");
      expect(result!.calories).toBe(2200);

      // Mar 15 should get the Mar 1 target
      const result2 = getActiveTarget(db, "2026-03-15");
      expect(result2!.calories).toBe(1800);
    });

    it("matches exact effective date", () => {
      setTarget(db, {
        effectiveDate: "2026-01-01",
        calories: 2000,
        protein: 1500,
        fat: 700,
        carbs: 2500,
      });

      const result = getActiveTarget(db, "2026-01-01");
      expect(result).not.toBeNull();
      expect(result!.calories).toBe(2000);
    });
  });

  describe("listTargets", () => {
    it("returns empty array when no targets exist", () => {
      const result = listTargets(db);
      expect(result).toEqual([]);
    });

    it("returns all non-deleted targets ordered by effectiveDate desc", () => {
      setTarget(db, {
        effectiveDate: "2026-01-01",
        calories: 2000,
        protein: 1500,
        fat: 700,
        carbs: 2500,
      });
      setTarget(db, {
        effectiveDate: "2026-03-01",
        calories: 1800,
        protein: 1400,
        fat: 600,
        carbs: 2400,
      });
      setTarget(db, {
        effectiveDate: "2026-02-01",
        calories: 2200,
        protein: 1600,
        fat: 800,
        carbs: 2600,
      });

      const result = listTargets(db);
      expect(result).toHaveLength(3);
      // Should be ordered by effectiveDate descending
      expect(result[0].effectiveDate).toBe("2026-03-01");
      expect(result[1].effectiveDate).toBe("2026-02-01");
      expect(result[2].effectiveDate).toBe("2026-01-01");
    });
  });
});
