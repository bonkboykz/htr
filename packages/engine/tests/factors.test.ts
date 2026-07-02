import { describe, it, expect, beforeEach } from "vitest";
import {
  setupTestDb,
  createCategory,
  listCategories,
  deleteCategory,
  createFactor,
  listFactors,
  getFactor,
  deleteFactor,
  logFactor,
  bulkLogFactors,
  getFactorLogsForDate,
  getFactorHistory,
  type DB,
} from "../src/index.js";

describe("factors: categories", () => {
  let db: DB;
  beforeEach(() => {
    db = setupTestDb();
  });

  it("seeds system categories and creates/deletes custom ones", () => {
    const seeded = listCategories(db);
    expect(seeded.map((c) => c.id)).toContain("cat-habits");
    expect(seeded.find((c) => c.id === "cat-mood")?.emoji).toBe("😊");

    const c = createCategory(db, { name: "Тренинг", emoji: "🏋️" });
    expect(listCategories(db).some((x) => x.id === c.id)).toBe(true);
    deleteCategory(db, c.id);
    expect(listCategories(db).some((x) => x.id === c.id)).toBe(false);
  });
});

describe("factors: factor CRUD", () => {
  let db: DB;
  beforeEach(() => {
    db = setupTestDb();
  });

  it("seeds default factors with parsed labels", () => {
    const mood = getFactor(db, "factor-mood");
    expect(mood?.name).toBe("Настроение");
    expect(mood?.labels).toEqual({ "1": "Ужасно", "3": "Норм", "5": "Отлично" });
    const energy = getFactor(db, "factor-energy");
    expect(energy?.labels).toBeNull();
  });

  it("creates, lists by category, and soft-deletes", () => {
    const f = createFactor(db, {
      categoryId: "cat-symptoms",
      name: "Тошнота",
      scaleMin: 0,
      scaleMax: 3,
    });
    expect(listFactors(db, "cat-symptoms").some((x) => x.id === f.id)).toBe(true);
    deleteFactor(db, f.id);
    expect(listFactors(db).some((x) => x.id === f.id)).toBe(false);
  });

  it("rejects a bad scale", () => {
    expect(() =>
      createFactor(db, { categoryId: "cat-other", name: "X", scaleMin: 5, scaleMax: 5 }),
    ).toThrow();
  });
});

describe("factors: logging", () => {
  let db: DB;
  beforeEach(() => {
    db = setupTestDb();
  });

  it("logFactor upserts on (date, factor) and validates the scale", () => {
    logFactor(db, { date: "2026-05-01", factorId: "factor-alcohol", value: 2 });
    logFactor(db, { date: "2026-05-01", factorId: "factor-alcohol", value: 4, note: "party" });
    const hist = getFactorHistory(db, "factor-alcohol");
    expect(hist).toHaveLength(1); // upsert, not a second row
    expect(hist[0].value).toBe(4);
    expect(hist[0].note).toBe("party");

    expect(() =>
      logFactor(db, { date: "2026-05-02", factorId: "factor-alcohol", value: 9 }),
    ).toThrow(); // scale 0-5
    expect(() =>
      logFactor(db, { date: "2026-05-02", factorId: "nope", value: 1 }),
    ).toThrow(); // unknown factor
  });

  it("bulkLogFactors logs several at once", () => {
    const logs = bulkLogFactors(db, {
      date: "2026-05-03",
      entries: [
        { factorId: "factor-energy", value: 4 },
        { factorId: "factor-stress", value: 2 },
      ],
    });
    expect(logs).toHaveLength(2);
  });

  it("getFactorLogsForDate groups by category with log-or-null", () => {
    logFactor(db, { date: "2026-05-04", factorId: "factor-energy", value: 5 });
    const grouped = getFactorLogsForDate(db, "2026-05-04");
    const mood = grouped.find((g) => g.category.id === "cat-mood");
    const energy = mood?.factors.find((f) => f.factor.id === "factor-energy");
    expect(energy?.log?.value).toBe(5);
    const stress = mood?.factors.find((f) => f.factor.id === "factor-stress");
    expect(stress?.log).toBeNull(); // not logged that day
  });

  it("getFactorHistory returns recent logs newest-first", () => {
    logFactor(db, { date: "2026-05-01", factorId: "factor-energy", value: 3 });
    logFactor(db, { date: "2026-05-02", factorId: "factor-energy", value: 5 });
    const hist = getFactorHistory(db, "factor-energy");
    expect(hist.map((h) => h.date)).toEqual(["2026-05-02", "2026-05-01"]);
  });
});
