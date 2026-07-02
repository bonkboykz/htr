import { describe, it, expect, beforeEach } from "vitest";
import { setupTestDb, createFoodItem, type DB } from "@htr/engine";
import { toolsByName } from "../src/tools.js";

function call<T = any>(db: DB, name: string, args: unknown = {}): T {
  const tool = toolsByName[name];
  if (!tool) throw new Error(`Unknown tool: ${name}`);
  return tool.handler(db, args) as T;
}

describe("HTR MCP tools", () => {
  let db: DB;
  beforeEach(() => {
    db = setupTestDb();
  });

  it("get_today returns routine-a / session_index 1 on a fresh db", () => {
    const today = call(db, "get_today");
    expect(today.routine_id).toBe("routine-a");
    expect(today.session_index).toBe(1);
    expect(today.is_rampup).toBe(true);
  });

  it("start_session -> log_set -> get_routine_plan reflects logged data + suggestion", () => {
    const { session_id } = call(db, "start_session", {
      routine_id: "routine-a",
      session_index: 5, // past ramp-up so main lifts get real suggestions
    });
    expect(session_id).toBeTruthy();

    call(db, "log_set", {
      session_id,
      exercise_id: "ex-bench_press",
      set_number: 1,
      weight_g: 60000,
      reps: 10,
      rir: 1,
    });

    const plan = call(db, "get_routine_plan", {
      routine_id: "routine-a",
      session_index: 5,
    });
    const bench = plan.sections.main.find(
      (i: any) => i.routineExercise.exerciseId === "ex-bench_press",
    );
    expect(bench).toBeTruthy();
    expect(bench.lastPerformance.length).toBeGreaterThan(0);
    expect(bench.lastPerformance[0].weightG).toBe(60000);
    expect(bench.suggestion).toBeTruthy();
  });

  it("log_weight then get_weight_trend reflects the entry", () => {
    const entry = call(db, "log_weight", {
      date: "2026-07-01",
      weightGrams: 80000,
    });
    expect(entry.weightGrams).toBe(80000);

    const trend = call(db, "get_weight_trend", { days: 3650 });
    expect(trend.entries.length).toBe(1);
    expect(trend.trendGrams).toBe(80000);
  });

  it("rejects invalid input via the tool's zod shape (.parse throws)", () => {
    expect(() =>
      call(db, "log_water", { date: "2026-07-01", amountMl: "lots" }),
    ).toThrow();
    // schema-level check too
    expect(
      toolsByName["log_set"].schema.safeParse({ exercise_id: "x" }).success,
    ).toBe(false);
  });

  it("override_progression returns engineSuggestion + override without persisting", () => {
    const before = call(db, "list_sessions", {});
    const res = call(db, "override_progression", {
      exercise_id: "ex-bench_press",
      weight_g: 65000,
      reason: "felt strong",
    });
    expect(res.engineSuggestion.exerciseId).toBe("ex-bench_press");
    expect(res.override.weight_g).toBe(65000);
    expect(res.override.reason).toBe("felt strong");
    // nothing persisted
    const after = call(db, "list_sessions", {});
    expect(after.length).toBe(before.length);
  });

  it("log_food logs against a food item and get_daily_summary aggregates it", () => {
    const item = createFoodItem(db, {
      name: "Oats",
      caloriesPer100g: 380,
      proteinPer100g: 130,
      fatPer100g: 70,
      carbsPer100g: 600,
    });
    call(db, "log_food", {
      date: "2026-07-01",
      mealId: "meal-breakfast",
      foodItemId: item.id,
      servingGrams: 50,
    });
    const summary = call(db, "get_daily_summary", { date: "2026-07-01" });
    expect(summary.nutrition.totals.calories).toBe(190);
  });
});
