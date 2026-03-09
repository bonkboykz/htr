import { describe, it, expect, beforeEach } from "vitest";
import { setupTestDb } from "../src/test-helpers.js";
import { logSleep, deleteSleepLog, getSleepForDate } from "../src/index.js";
import type { DB } from "../src/index.js";

describe("sleep engine", () => {
  let db: DB;

  beforeEach(() => {
    db = setupTestDb();
  });

  describe("logSleep", () => {
    it("creates a sleep log entry", () => {
      const entry = logSleep(db, {
        startTime: "2026-01-14T23:00:00",
        endTime: "2026-01-15T07:00:00",
      });

      expect(entry.id).toBeDefined();
      expect(entry.startTime).toBe("2026-01-14T23:00:00");
      expect(entry.endTime).toBe("2026-01-15T07:00:00");
      expect(entry.quality).toBeNull();
      expect(entry.note).toBeNull();
      expect(entry.isDeleted).toBe(0);
    });

    it("creates entry with quality and note", () => {
      const entry = logSleep(db, {
        startTime: "2026-01-14T23:00:00",
        endTime: "2026-01-15T07:00:00",
        quality: 4,
        note: "Slept well",
      });

      expect(entry.quality).toBe(4);
      expect(entry.note).toBe("Slept well");
    });
  });

  describe("deleteSleepLog", () => {
    it("soft deletes a sleep log entry", () => {
      const entry = logSleep(db, {
        startTime: "2026-01-14T23:00:00",
        endTime: "2026-01-15T07:00:00",
      });

      deleteSleepLog(db, entry.id);

      const entries = getSleepForDate(db, "2026-01-15");
      expect(entries).toHaveLength(0);
    });
  });

  describe("getSleepForDate", () => {
    it("returns empty array when no sleep entries exist", () => {
      const entries = getSleepForDate(db, "2026-01-15");
      expect(entries).toEqual([]);
    });

    it("attributes sleep to the wake-up date (end_time)", () => {
      // Sleep starts on Jan 14 but ends on Jan 15
      logSleep(db, {
        startTime: "2026-01-14T23:00:00",
        endTime: "2026-01-15T07:00:00",
      });

      // Should appear under Jan 15 (wake-up date)
      const entriesJan15 = getSleepForDate(db, "2026-01-15");
      expect(entriesJan15).toHaveLength(1);

      // Should NOT appear under Jan 14
      const entriesJan14 = getSleepForDate(db, "2026-01-14");
      expect(entriesJan14).toHaveLength(0);
    });

    it("returns multiple sleep entries for the same wake-up date", () => {
      // Main sleep
      logSleep(db, {
        startTime: "2026-01-14T23:00:00",
        endTime: "2026-01-15T06:00:00",
      });
      // Nap
      logSleep(db, {
        startTime: "2026-01-15T13:00:00",
        endTime: "2026-01-15T14:00:00",
      });

      const entries = getSleepForDate(db, "2026-01-15");
      expect(entries).toHaveLength(2);
    });

    it("handles same-day sleep (no midnight crossing)", () => {
      logSleep(db, {
        startTime: "2026-01-15T13:00:00",
        endTime: "2026-01-15T14:30:00",
      });

      const entries = getSleepForDate(db, "2026-01-15");
      expect(entries).toHaveLength(1);
    });

    it("excludes deleted entries", () => {
      const entry = logSleep(db, {
        startTime: "2026-01-14T23:00:00",
        endTime: "2026-01-15T07:00:00",
      });
      logSleep(db, {
        startTime: "2026-01-15T13:00:00",
        endTime: "2026-01-15T14:00:00",
      });

      deleteSleepLog(db, entry.id);

      const entries = getSleepForDate(db, "2026-01-15");
      expect(entries).toHaveLength(1);
      expect(entries[0].startTime).toBe("2026-01-15T13:00:00");
    });

    it("does not return entries from different dates", () => {
      logSleep(db, {
        startTime: "2026-01-15T23:00:00",
        endTime: "2026-01-16T07:00:00",
      });

      const entries = getSleepForDate(db, "2026-01-15");
      expect(entries).toHaveLength(0);
    });
  });
});
