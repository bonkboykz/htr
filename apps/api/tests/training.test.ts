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

  it("POST /sessions accepts a backdated started_at", async () => {
    const res = await app.request(
      "/api/v1/training/sessions",
      json({
        routine_id: "routine-a",
        session_index: 6,
        started_at: "2026-06-03T09:00:00.000Z",
      }),
    );
    expect(res.status).toBe(201);
    const sid = (await res.json()).session_id;

    const patchRes = await app.request(`/api/v1/training/sessions/${sid}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ ended_at: "2026-06-03T10:00:00.000Z" }),
    });
    expect(patchRes.status).toBe(200);
    expect((await patchRes.json()).duration_s).toBe(3600);

    const sessions = await (
      await app.request("/api/v1/training/sessions")
    ).json();
    const mine = sessions.find((s: any) => s.id === sid);
    expect(mine.startedAt).toBe("2026-06-03T09:00:00.000Z");
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

describe("Training CRUD & overrides API", () => {
  let app: ReturnType<typeof createApp>;

  beforeAll(() => {
    const db = createAndMigrateDb(":memory:");
    seedMeals(db);
    seedTraining(db);
    app = createApp(db);
  });

  it("exercise CRUD: create, search, update, delete → 404", async () => {
    // create
    const createRes = await app.request(
      "/api/v1/training/exercises",
      json({
        name: "Cable Fly",
        name_ru: "Сведение в кроссовере",
        muscle_group: "chest",
        pattern: "h_press",
        target_sets: 3,
      }),
    );
    expect(createRes.status).toBe(201);
    const created = await createRes.json();
    expect(created.id).toBeDefined();
    const id = created.id;

    // search
    const searchRes = await app.request(
      "/api/v1/training/exercises?q=Cable",
    );
    expect(searchRes.status).toBe(200);
    const list = await searchRes.json();
    expect(list.some((e: any) => e.id === id)).toBe(true);

    // update
    const patchRes = await app.request(`/api/v1/training/exercises/${id}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ name: "Cable Crossover" }),
    });
    expect(patchRes.status).toBe(200);
    const updated = await patchRes.json();
    expect(updated.name).toBe("Cable Crossover");

    // delete
    const delRes = await app.request(`/api/v1/training/exercises/${id}`, {
      method: "DELETE",
    });
    expect(delRes.status).toBe(200);
    expect((await delRes.json()).success).toBe(true);

    // gone
    const goneRes = await app.request(`/api/v1/training/exercises/${id}`);
    expect(goneRes.status).toBe(404);
  });

  it("routine composition: create, add, list, move, remove, delete", async () => {
    // create routine
    const routineRes = await app.request(
      "/api/v1/training/routines",
      json({ name: "Push Day", name_ru: "День толчка" }),
    );
    expect(routineRes.status).toBe(201);
    const routine = await routineRes.json();
    const routineId = routine.id;

    // add exercise
    const addRes = await app.request(
      `/api/v1/training/routines/${routineId}/exercises`,
      json({
        exercise_id: "ex-bench_press",
        section: "main",
        target_sets: 3,
        rep_min: 8,
        rep_max: 12,
      }),
    );
    expect(addRes.status).toBe(201);
    const re = await addRes.json();
    const reId = re.id;
    expect(re.section).toBe("main");

    // list
    const listRes = await app.request(
      `/api/v1/training/routines/${routineId}/exercises`,
    );
    expect(listRes.status).toBe(200);
    expect((await listRes.json()).length).toBe(1);

    // move section
    const moveRes = await app.request(
      `/api/v1/training/routines/${routineId}/exercises/${reId}`,
      {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ section: "warmup" }),
      },
    );
    expect(moveRes.status).toBe(200);
    expect((await moveRes.json()).section).toBe("warmup");

    // remove exercise
    const removeRes = await app.request(
      `/api/v1/training/routines/${routineId}/exercises/${reId}`,
      { method: "DELETE" },
    );
    expect(removeRes.status).toBe(200);
    expect((await removeRes.json()).success).toBe(true);

    // delete routine
    const delRoutineRes = await app.request(
      `/api/v1/training/routines/${routineId}`,
      { method: "DELETE" },
    );
    expect(delRoutineRes.status).toBe(200);
    expect((await delRoutineRes.json()).success).toBe(true);
  });

  it("session/set lifecycle: start, log, delete set, delete session", async () => {
    const startRes = await app.request(
      "/api/v1/training/sessions",
      json({ routine_id: "routine-a", session_index: 9 }),
    );
    expect(startRes.status).toBe(201);
    const sid = (await startRes.json()).session_id;

    const setIds: string[] = [];
    for (let n = 1; n <= 2; n++) {
      const setRes = await app.request(
        `/api/v1/training/sessions/${sid}/sets`,
        json({
          exercise_id: "ex-bench_press",
          set_number: n,
          weight_g: 50000,
          reps: 10,
          rir: 2,
        }),
      );
      expect(setRes.status).toBe(201);
      setIds.push((await setRes.json()).set_id);
    }

    // delete one set
    const delSetRes = await app.request(
      `/api/v1/training/sessions/${sid}/sets/${setIds[0]}`,
      { method: "DELETE" },
    );
    expect(delSetRes.status).toBe(200);
    expect((await delSetRes.json()).success).toBe(true);

    // reflects 1 remaining working set
    let sessions = await (
      await app.request("/api/v1/training/sessions")
    ).json();
    const mine = sessions.find((s: any) => s.id === sid);
    expect(mine.totalSets).toBe(1);

    // delete session
    const delSessionRes = await app.request(
      `/api/v1/training/sessions/${sid}`,
      { method: "DELETE" },
    );
    expect(delSessionRes.status).toBe(200);
    expect((await delSessionRes.json()).success).toBe(true);

    // now empty
    sessions = await (await app.request("/api/v1/training/sessions")).json();
    expect(sessions.length).toBe(0);
  });

  it("session overrides: record, list, adherence stats", async () => {
    const startRes = await app.request(
      "/api/v1/training/sessions",
      json({ routine_id: "routine-a", session_index: 10 }),
    );
    const sid = (await startRes.json()).session_id;

    const overrideRes = await app.request(
      `/api/v1/training/sessions/${sid}/overrides`,
      json({
        routine_exercise_id: "re-1",
        replaced_exercise_id: "ex-bench_press",
        reason: "shoulder tweak",
      }),
    );
    expect(overrideRes.status).toBe(201);

    const listRes = await app.request(
      `/api/v1/training/sessions/${sid}/overrides`,
    );
    expect(listRes.status).toBe(200);
    expect((await listRes.json()).length).toBe(1);

    const adherenceRes = await app.request(
      "/api/v1/training/stats/adherence",
    );
    expect(adherenceRes.status).toBe(200);
    expect((await adherenceRes.json()).totalOverrides).toBe(1);
  });

  it("POST /exercises missing name returns 400 VALIDATION_ERROR", async () => {
    const res = await app.request(
      "/api/v1/training/exercises",
      json({
        name_ru: "Без имени",
        muscle_group: "chest",
        pattern: "h_press",
      }),
    );
    expect(res.status).toBe(400);
    expect((await res.json()).error.code).toBe("VALIDATION_ERROR");
  });
});
