import { describe, it, expect, beforeEach } from "vitest";
import { setupTestDb } from "../src/test-helpers.js";
import {
  logWater,
  deleteWaterLog,
  getDailyWater,
  setTarget,
} from "../src/index.js";
import type { DB } from "../src/index.js";

describe("water engine", () => {
  let db: DB;

  beforeEach(() => {
    db = setupTestDb();
  });

  describe("logWater", () => {
    it("creates a water log entry", () => {
      const entry = logWater(db, {
        date: "2026-01-15",
        amountMl: 250,
      });

      expect(entry.id).toBeDefined();
      expect(entry.date).toBe("2026-01-15");
      expect(entry.amountMl).toBe(250);
      expect(entry.isDeleted).toBe(0);
    });
  });

  describe("deleteWaterLog", () => {
    it("soft deletes a water log entry", () => {
      const entry = logWater(db, {
        date: "2026-01-15",
        amountMl: 250,
      });

      deleteWaterLog(db, entry.id);

      const daily = getDailyWater(db, "2026-01-15");
      expect(daily.totalMl).toBe(0);
      expect(daily.entries).toHaveLength(0);
    });
  });

  describe("getDailyWater", () => {
    it("returns zero total with no entries", () => {
      const daily = getDailyWater(db, "2026-01-15");
      expect(daily.totalMl).toBe(0);
      expect(daily.entries).toHaveLength(0);
    });

    it("sums multiple entries for the same date", () => {
      logWater(db, { date: "2026-01-15", amountMl: 250 });
      logWater(db, { date: "2026-01-15", amountMl: 500 });
      logWater(db, { date: "2026-01-15", amountMl: 300 });

      const daily = getDailyWater(db, "2026-01-15");
      expect(daily.totalMl).toBe(1050);
      expect(daily.entries).toHaveLength(3);
    });

    it("only includes entries for the specified date", () => {
      logWater(db, { date: "2026-01-15", amountMl: 250 });
      logWater(db, { date: "2026-01-16", amountMl: 500 });

      const daily = getDailyWater(db, "2026-01-15");
      expect(daily.totalMl).toBe(250);
      expect(daily.entries).toHaveLength(1);
    });

    it("excludes deleted entries", () => {
      logWater(db, { date: "2026-01-15", amountMl: 250 });
      const toDelete = logWater(db, { date: "2026-01-15", amountMl: 500 });

      deleteWaterLog(db, toDelete.id);

      const daily = getDailyWater(db, "2026-01-15");
      expect(daily.totalMl).toBe(250);
      expect(daily.entries).toHaveLength(1);
    });

    it("returns default target of 2500 when no target is set", () => {
      const daily = getDailyWater(db, "2026-01-15");
      expect(daily.targetMl).toBe(2500);
    });

    it("returns custom target when a target is set", () => {
      setTarget(db, {
        effectiveDate: "2026-01-01",
        calories: 2000,
        protein: 1500,
        fat: 700,
        carbs: 2500,
        waterMl: 3000,
      });

      const daily = getDailyWater(db, "2026-01-15");
      expect(daily.targetMl).toBe(3000);
    });
  });
});
