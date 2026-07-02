import { Hono } from "hono";
import type { Context } from "hono";
import {
  getToday,
  getRoutinePlan,
  startSession,
  logSet,
  quickRepeatLastSet,
  endSession,
  getProgression,
  getVolumeStats,
  listSessions,
  patchRoutineExercise,
  suggestProgression,
  listExercises,
  getExerciseById,
  createExercise,
  updateExercise,
  deleteExercise,
  listRoutines,
  createRoutine,
  updateRoutine,
  deleteRoutine,
  listRoutineExercises,
  addRoutineExercise,
  deleteRoutineExercise,
  deleteSet,
  deleteSession,
  recordOverride,
  listOverrides,
  getPlanDeviation,
  StartSessionInput,
  LogSetInput,
  EndSessionInput,
  OverrideProgressionInput,
  PatchRoutineExerciseInput,
  CreateExerciseInput,
  UpdateExerciseInput,
  CreateRoutineInput,
  UpdateRoutineInput,
  AddRoutineExerciseInput,
  RecordOverrideInput,
  formatWeight,
  formatVolume,
  formatDuration,
  type DB,
  type TrainingRange,
} from "@htr/engine";
import { AppError } from "../errors.js";

function validationError(c: Context, issues: { message: string }[]) {
  return c.json(
    {
      error: {
        code: "VALIDATION_ERROR",
        message: issues.map((i) => i.message).join(", "),
        suggestion: "Check the request body and try again",
      },
    },
    400,
  );
}

// Resolve a TrainingRange from query params.
// ?from / ?to take precedence; else ?range=week|month; else all-time {}.
function resolveRange(c: Context): TrainingRange {
  const from = c.req.query("from");
  const to = c.req.query("to");
  if (from || to) {
    const range: TrainingRange = {};
    if (from) range.from = from;
    if (to) range.to = to;
    return range;
  }

  const range = c.req.query("range");
  const today = new Date();
  const iso = (d: Date) => d.toISOString().slice(0, 10);
  if (range === "week") {
    const start = new Date(today);
    start.setDate(start.getDate() - 6);
    return { from: iso(start), to: iso(today) };
  }
  if (range === "month") {
    const start = new Date(today);
    start.setDate(start.getDate() - 29);
    return { from: iso(start), to: iso(today) };
  }
  return {};
}

export function trainingRoutes(db: DB) {
  const app = new Hono();

  // ---------- hot path ----------

  // GET /today — which routine/session is next
  app.get("/today", (c) => {
    return c.json(getToday(db));
  });

  // GET /routines/:id/plan — full plan with suggestions
  app.get("/routines/:id/plan", (c) => {
    const sessionIndexRaw = c.req.query("sessionIndex");
    const sessionIndex =
      sessionIndexRaw !== undefined ? parseInt(sessionIndexRaw, 10) : undefined;
    const plan = getRoutinePlan(db, c.req.param("id"), sessionIndex);

    const sections = Object.fromEntries(
      Object.entries(plan.sections).map(([section, items]) => [
        section,
        items.map((item) => ({
          ...item,
          lastPerformance: item.lastPerformance.map((set) => ({
            ...set,
            weightFormatted: formatWeight(set.weightG),
          })),
          suggestion: item.suggestion
            ? {
                ...item.suggestion,
                weightFormatted: formatWeight(item.suggestion.weightG),
              }
            : null,
        })),
      ]),
    );

    return c.json({ ...plan, sections });
  });

  // POST /sessions — start a session
  app.post("/sessions", async (c) => {
    const body = await c.req.json();
    const parsed = StartSessionInput.safeParse(body);
    if (!parsed.success) return validationError(c, parsed.error.issues);
    return c.json(startSession(db, parsed.data), 201);
  });

  // POST /sessions/:id/sets — log a set
  app.post("/sessions/:id/sets", async (c) => {
    const body = await c.req.json();
    const parsed = LogSetInput.safeParse(body);
    if (!parsed.success) return validationError(c, parsed.error.issues);
    return c.json(logSet(db, c.req.param("id"), parsed.data), 201);
  });

  // POST /sessions/:id/sets/quick — repeat last set for an exercise
  app.post("/sessions/:id/sets/quick", async (c) => {
    const body = await c.req.json();
    if (!body || typeof body.exercise_id !== "string" || !body.exercise_id) {
      return validationError(c, [{ message: "exercise_id is required" }]);
    }
    try {
      return c.json(
        quickRepeatLastSet(db, c.req.param("id"), body.exercise_id),
        201,
      );
    } catch (err: any) {
      throw new AppError(
        "NOT_FOUND",
        err.message,
        404,
        "Log at least one set for this exercise first",
      );
    }
  });

  // PATCH /sessions/:id — end a session
  app.patch("/sessions/:id", async (c) => {
    const body = await c.req.json();
    const parsed = EndSessionInput.safeParse(body);
    if (!parsed.success) return validationError(c, parsed.error.issues);
    try {
      return c.json(endSession(db, c.req.param("id"), parsed.data), 200);
    } catch (err: any) {
      throw new AppError("NOT_FOUND", err.message, 404);
    }
  });

  // ---------- analytics ----------

  // GET /progression/:exerciseId — e1RM history
  app.get("/progression/:exerciseId", (c) => {
    const history = getProgression(
      db,
      c.req.param("exerciseId"),
      resolveRange(c),
    );
    return c.json({
      ...history,
      currentE1rmFormatted: formatWeight(history.currentE1rmG),
      changeE1rmFormatted: formatWeight(history.changeE1rmG),
      currentDurationFormatted: formatDuration(history.currentDurationS),
      changeDurationFormatted: formatDuration(history.changeDurationS),
      points: history.points.map((p) => ({
        ...p,
        weightFormatted: formatWeight(p.weightG),
        e1rmFormatted: formatWeight(p.e1rmG),
        durationFormatted: p.durationS != null ? formatDuration(p.durationS) : null,
      })),
    });
  });

  // GET /stats/volume — volume by muscle group
  app.get("/stats/volume", (c) => {
    const stats = getVolumeStats(db, resolveRange(c));
    return c.json({
      ...stats,
      totalVolumeFormatted: formatVolume(stats.totalVolumeG),
      totalDurationFormatted: formatDuration(stats.totalDurationS),
      byGroup: stats.byGroup.map((g) => ({
        ...g,
        volumeFormatted: formatVolume(g.volumeG),
        durationFormatted: formatDuration(g.durationS),
      })),
    });
  });

  // GET /sessions — session history
  app.get("/sessions", (c) => {
    const sessions = listSessions(db, resolveRange(c));
    return c.json(
      sessions.map((s) => ({
        ...s,
        volumeFormatted: formatVolume(s.totalVolumeG),
      })),
    );
  });

  // ---------- plan edits ----------

  // PATCH /routines/:id/exercises/:reId — edit a routine exercise
  app.patch("/routines/:id/exercises/:reId", async (c) => {
    const body = await c.req.json();
    const parsed = PatchRoutineExerciseInput.safeParse(body);
    if (!parsed.success) return validationError(c, parsed.error.issues);
    try {
      return c.json(
        patchRoutineExercise(db, c.req.param("reId"), parsed.data),
        200,
      );
    } catch (err: any) {
      throw new AppError(
        "NOT_FOUND",
        err.message,
        404,
        "Check the routine exercise id",
      );
    }
  });

  // POST /progression/:exerciseId/override — advisory override (not persisted in v1)
  app.post("/progression/:exerciseId/override", async (c) => {
    const body = await c.req.json();
    const parsed = OverrideProgressionInput.safeParse(body);
    if (!parsed.success) return validationError(c, parsed.error.issues);

    const engineSuggestion = suggestProgression(
      db,
      c.req.param("exerciseId"),
    );
    return c.json(
      {
        engineSuggestion: {
          ...engineSuggestion,
          weightFormatted: formatWeight(engineSuggestion.weightG),
        },
        override: {
          weightG: parsed.data.weight_g,
          weightFormatted: formatWeight(parsed.data.weight_g),
          reason: parsed.data.reason,
        },
        note: "Override is advisory in v1 — it is realized when you log the set at this weight.",
      },
      200,
    );
  });

  // ---------- exercise catalog CRUD ----------

  // GET /exercises — list/search exercises
  app.get("/exercises", (c) => {
    return c.json(
      listExercises(db, {
        q: c.req.query("q"),
        muscleGroup: c.req.query("muscleGroup"),
        includeDeleted: c.req.query("includeDeleted") === "true",
      }),
    );
  });

  // GET /exercises/:id — single exercise
  app.get("/exercises/:id", (c) => {
    const exercise = getExerciseById(db, c.req.param("id"));
    if (!exercise || exercise.isDeleted) {
      throw new AppError("NOT_FOUND", "Exercise not found", 404);
    }
    return c.json(exercise);
  });

  // POST /exercises — create exercise
  app.post("/exercises", async (c) => {
    const body = await c.req.json();
    const parsed = CreateExerciseInput.safeParse(body);
    if (!parsed.success) return validationError(c, parsed.error.issues);
    return c.json(createExercise(db, parsed.data), 201);
  });

  // PATCH /exercises/:id — update exercise
  app.patch("/exercises/:id", async (c) => {
    const body = await c.req.json();
    const parsed = UpdateExerciseInput.safeParse(body);
    if (!parsed.success) return validationError(c, parsed.error.issues);
    try {
      return c.json(updateExercise(db, c.req.param("id"), parsed.data), 200);
    } catch (err: any) {
      throw new AppError("NOT_FOUND", err.message, 404);
    }
  });

  // DELETE /exercises/:id — soft delete exercise
  app.delete("/exercises/:id", (c) => {
    deleteExercise(db, c.req.param("id"));
    return c.json({ success: true });
  });

  // ---------- routine CRUD ----------

  // GET /routines — list routines
  app.get("/routines", (c) => {
    return c.json(listRoutines(db));
  });

  // POST /routines — create routine
  app.post("/routines", async (c) => {
    const body = await c.req.json();
    const parsed = CreateRoutineInput.safeParse(body);
    if (!parsed.success) return validationError(c, parsed.error.issues);
    return c.json(createRoutine(db, parsed.data), 201);
  });

  // PATCH /routines/:id — update routine
  app.patch("/routines/:id", async (c) => {
    const body = await c.req.json();
    const parsed = UpdateRoutineInput.safeParse(body);
    if (!parsed.success) return validationError(c, parsed.error.issues);
    try {
      return c.json(updateRoutine(db, c.req.param("id"), parsed.data), 200);
    } catch (err: any) {
      throw new AppError("NOT_FOUND", err.message, 404);
    }
  });

  // DELETE /routines/:id — soft delete routine (cascade positions)
  app.delete("/routines/:id", (c) => {
    deleteRoutine(db, c.req.param("id"));
    return c.json({ success: true });
  });

  // ---------- routine composition ----------

  // GET /routines/:id/exercises — list a routine's exercises
  app.get("/routines/:id/exercises", (c) => {
    return c.json(listRoutineExercises(db, c.req.param("id")));
  });

  // POST /routines/:id/exercises — add an exercise to a routine
  app.post("/routines/:id/exercises", async (c) => {
    const body = await c.req.json();
    const parsed = AddRoutineExerciseInput.safeParse(body);
    if (!parsed.success) return validationError(c, parsed.error.issues);
    try {
      return c.json(
        addRoutineExercise(db, c.req.param("id"), parsed.data),
        201,
      );
    } catch (err: any) {
      throw new AppError("NOT_FOUND", err.message, 404);
    }
  });

  // DELETE /routines/:id/exercises/:reId — remove an exercise from a routine
  app.delete("/routines/:id/exercises/:reId", (c) => {
    deleteRoutineExercise(db, c.req.param("reId"));
    return c.json({ success: true });
  });

  // ---------- session / set soft delete ----------

  // DELETE /sessions/:id — soft delete a session (cascade sets)
  app.delete("/sessions/:id", (c) => {
    deleteSession(db, c.req.param("id"));
    return c.json({ success: true });
  });

  // DELETE /sessions/:sid/sets/:setId — soft delete a set
  app.delete("/sessions/:sid/sets/:setId", (c) => {
    deleteSet(db, c.req.param("setId"));
    return c.json({ success: true });
  });

  // ---------- session plan overrides ----------

  // POST /sessions/:id/overrides — record a plan override
  app.post("/sessions/:id/overrides", async (c) => {
    const body = await c.req.json();
    const parsed = RecordOverrideInput.safeParse(body);
    if (!parsed.success) return validationError(c, parsed.error.issues);
    return c.json(recordOverride(db, c.req.param("id"), parsed.data), 201);
  });

  // GET /sessions/:id/overrides — overrides for a session
  app.get("/sessions/:id/overrides", (c) => {
    return c.json(listOverrides(db, c.req.param("id")));
  });

  // GET /stats/adherence — how often the plan is deviated from
  app.get("/stats/adherence", (c) => {
    return c.json(getPlanDeviation(db, resolveRange(c)));
  });

  return app;
}
