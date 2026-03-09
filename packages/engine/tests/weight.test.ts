import { describe, it, expect, beforeEach } from "vitest";
import { setupTestDb } from "../src/test-helpers.js";
import {
  logWeight,
  deleteWeightLog,
  getLatestWeight,
  getWeightEntries,
  getWeightTrend,
} from "../src/index.js";
import type { DB } from "../src/index.js";

describe("weight engine", () => {
  let db: DB;

  beforeEach(() => {
    db = setupTestDb();
  });

  describe("logWeight", () => {
    it("creates a weight log entry", () => {
      const entry = logWeight(db, {
        date: "2026-01-15",
        weightGrams: 75500,
      });

      expect(entry.id).toBeDefined();
      expect(entry.date).toBe("2026-01-15");
      expect(entry.weightGrams).toBe(75500);
      expect(entry.bodyFat).toBeNull();
      expect(entry.note).toBeNull();
      expect(entry.isDeleted).toBe(0);
    });

    it("creates entry with optional body fat and note", () => {
      const entry = logWeight(db, {
        date: "2026-01-15",
        weightGrams: 75500,
        bodyFat: 152,
        note: "Morning weigh-in",
      });

      expect(entry.bodyFat).toBe(152);
      expect(entry.note).toBe("Morning weigh-in");
    });

    it("throws when logging weight for the same date twice", () => {
      logWeight(db, { date: "2026-01-15", weightGrams: 75500 });

      expect(() =>
        logWeight(db, { date: "2026-01-15", weightGrams: 76000 })
      ).toThrow();
    });
  });

  describe("deleteWeightLog", () => {
    it("soft deletes a weight log entry", () => {
      const entry = logWeight(db, {
        date: "2026-01-15",
        weightGrams: 75500,
      });

      deleteWeightLog(db, entry.id);

      const latest = getLatestWeight(db);
      expect(latest).toBeNull();
    });
  });

  describe("getLatestWeight", () => {
    it("returns null when no entries exist", () => {
      expect(getLatestWeight(db)).toBeNull();
    });

    it("returns the most recent entry by date", () => {
      logWeight(db, { date: "2026-01-10", weightGrams: 76000 });
      logWeight(db, { date: "2026-01-15", weightGrams: 75500 });
      logWeight(db, { date: "2026-01-12", weightGrams: 75800 });

      const latest = getLatestWeight(db);
      expect(latest).not.toBeNull();
      expect(latest!.date).toBe("2026-01-15");
      expect(latest!.weightGrams).toBe(75500);
    });

    it("excludes deleted entries", () => {
      const old = logWeight(db, { date: "2026-01-10", weightGrams: 76000 });
      const newer = logWeight(db, { date: "2026-01-15", weightGrams: 75500 });

      deleteWeightLog(db, newer.id);

      const latest = getLatestWeight(db);
      expect(latest!.date).toBe("2026-01-10");
    });
  });

  describe("getWeightEntries", () => {
    it("returns entries within the given day range", () => {
      // These use "today minus N days" logic, so we log entries with today's-range dates
      const today = new Date().toISOString().split("T")[0];
      logWeight(db, { date: today, weightGrams: 75500 });

      const entries = getWeightEntries(db, 30);
      expect(entries.length).toBeGreaterThanOrEqual(1);
      expect(entries[0].date).toBe(today);
    });

    it("returns entries ordered by date descending", () => {
      const today = new Date();
      const d1 = new Date(today);
      d1.setDate(d1.getDate() - 2);
      const d2 = new Date(today);
      d2.setDate(d2.getDate() - 1);

      const date1 = d1.toISOString().split("T")[0];
      const date2 = d2.toISOString().split("T")[0];
      const date3 = today.toISOString().split("T")[0];

      logWeight(db, { date: date1, weightGrams: 76000 });
      logWeight(db, { date: date2, weightGrams: 75800 });
      logWeight(db, { date: date3, weightGrams: 75500 });

      const entries = getWeightEntries(db, 30);
      expect(entries[0].date).toBe(date3);
      expect(entries[1].date).toBe(date2);
      expect(entries[2].date).toBe(date1);
    });

    it("excludes deleted entries", () => {
      const today = new Date().toISOString().split("T")[0];
      const entry = logWeight(db, { date: today, weightGrams: 75500 });
      deleteWeightLog(db, entry.id);

      const entries = getWeightEntries(db, 30);
      expect(entries).toHaveLength(0);
    });
  });

  describe("getWeightTrend", () => {
    it("returns zeros when no entries exist", () => {
      const trend = getWeightTrend(db, 30);
      expect(trend.entries).toHaveLength(0);
      expect(trend.trendGrams).toBe(0);
      expect(trend.changeGrams).toBe(0);
    });

    it("returns trend for a single entry", () => {
      const today = new Date().toISOString().split("T")[0];
      logWeight(db, { date: today, weightGrams: 75500 });

      const trend = getWeightTrend(db, 30);
      expect(trend.entries).toHaveLength(1);
      expect(trend.trendGrams).toBe(75500);
      expect(trend.changeGrams).toBe(0);
    });

    it("computes EMA trend and change for multiple entries", () => {
      const today = new Date();

      // Create 5 entries over 5 days
      for (let i = 4; i >= 0; i--) {
        const d = new Date(today);
        d.setDate(d.getDate() - i);
        const dateStr = d.toISOString().split("T")[0];
        logWeight(db, {
          date: dateStr,
          weightGrams: 76000 - i * 200, // decreasing from 75200 to 76000
        });
      }

      const trend = getWeightTrend(db, 30);
      expect(trend.entries).toHaveLength(5);
      // trendGrams should be a smoothed value
      expect(trend.trendGrams).toBeGreaterThan(0);
      // changeGrams = last entry weight - first entry weight (chronological)
      // sorted chronologically: 75200, 75400, 75600, 75800, 76000
      // change = 76000 - 75200 = 800
      expect(trend.changeGrams).toBe(800);
    });
  });
});
