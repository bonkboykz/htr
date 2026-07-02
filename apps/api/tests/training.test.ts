import { describe, it, expect, beforeAll } from "vitest";
import { createApp } from "../src/app.js";
import { createAndMigrateDb, seedMeals, seedTraining } from "@htr/engine";

function json(body: unknown) {
  return {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  };
}

describe("Training API", () => {
  let app: ReturnType<typeof createApp>;
  let sessionId: string;

  beforeAll(() => {
    const db = createAndMigrateDb(":memory:");
    seedMeals(db);
    seedTraining(db);
    app = createApp(db);
  });

  it("GET /today returns routine-a, session 1, rampup", async () => {
    const res = await app.request("/api/v1/training/today");
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.routine_id).toBe("routine-a");
    expect(body.session_index).toBe(1);
    expect(body.is_rampup).toBe(true);
  });

  it("POST /sessions starts a session", async () => {
    const res = await app.request(
      "/api/v1/training/sessions",
      json({ routine_id: "routine-a", session_index: 5 }),
    );
    expect(res.status).toBe(201);
    const body = await res.json();
    expect(body.session_id).toBeDefined();
    expect(body.session_index).toBe(5);
    sessionId = body.session_id;
  });

  it("POST /sessions/:id/sets logs 3 working sets for bench", async () => {
    for (let setNumber = 1; setNumber <= 3; setNumber++) {
      const res = await app.request(
        `/api/v1/training/sessions/${sessionId}/sets`,
        json({
          exercise_id: "ex-bench_press",
          set_number: setNumber,
          weight_g: 50000,
          reps: 10,
          rir: 2,
        }),
      );
      expect(res.status).toBe(201);
      const body = await res.json();
      expect(body.set_id).toBeDefined();
    }
  });

  it("PATCH /sessions/:id ends the session", async () => {
    const res = await app.request(`/api/v1/training/sessions/${sessionId}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({}),
    });
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.duration_s).toBeGreaterThanOrEqual(0);
  });

  it("GET /routines/:id/plan suggests an increase for bench", async () => {
    const res = await app.request(
      "/api/v1/training/routines/routine-a/plan?sessionIndex=6",
    );
    expect(res.status).toBe(200);
    const body = await res.json();
    const benchItem = body.sections.main.find(
      (i: any) => i.routineExercise.exerciseId === "ex-bench_press",
    );
    expect(benchItem).toBeDefined();
    expect(benchItem.suggestion.action).toBe("increase");
    expect(benchItem.suggestion.weightG).toBe(52500);
    expect(benchItem.suggestion.weightFormatted).toBeDefined();
  });

  it("POST /progression/:exerciseId/override returns advisory override", async () => {
    const res = await app.request(
      "/api/v1/training/progression/ex-bench_press/override",
      json({
        exercise_id: "ex-bench_press",
        weight_g: 50000,
        reason: "deload week",
      }),
    );
    expect(res.status).toBe(200);
    const body = await res.json();
    expect(body.engineSuggestion).toBeDefined();
    expect(body.override.weightG).toBe(50000);
    expect(body.override.weightFormatted).toBeDefined();
    expect(body.note).toContain("advisory");
  });

  it("POST /sessions with invalid body returns 400 VALIDATION_ERROR", async () => {
    const res = await app.request(
      "/api/v1/training/sessions",
      json({ session_index: 5 }),
    );
    expect(res.status).toBe(400);
    const body = await res.json();
    expect(body.error.code).toBe("VALIDATION_ERROR");
  });
});
