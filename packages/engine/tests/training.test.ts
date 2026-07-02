import { describe, it, expect, beforeEach } from "vitest";
import {
  setupTestDb,
  schema,
  startSession,
  logSet,
  quickRepeatLastSet,
  endSession,
  patchRoutineExercise,
  getToday,
  getLastPerformance,
  getRoutinePlan,
  suggestProgression,
  getProgression,
  getVolumeStats,
  listSessions,
  createExercise,
  updateExercise,
  deleteExercise,
  listExercises,
  getExerciseById,
  createRoutine,
  updateRoutine,
  deleteRoutine,
  listRoutines,
  addRoutineExercise,
  deleteRoutineExercise,
  listRoutineExercises,
  deleteSet,
  deleteSession,
  recordOverride,
  listOverrides,
  getPlanDeviation,
  epley1RM,
  setVolumeG,
  roundToIncrement,
  formatDuration,
  type DB,
} from "../src/index.js";
import { eq } from "drizzle-orm";

const BENCH = "ex-bench_press"; // main in routine A, rep range 8–10, targetRir 2, incr 2500
const LEG_PRESS = "ex-leg_press"; // main in routine A, rep range 10–12, incr 5000

// Log a completed session on routine A with the given bench sets, past ramp-up.
function completedBenchSession(
  db: DB,
  sessionIndex: number,
  sets: { weight_g: number; reps: number; rir: number }[],
) {
  const s = startSession(db, { routine_id: "routine-a", session_index: sessionIndex });
  sets.forEach((set, i) =>
    logSet(db, s.session_id, {
      exercise_id: BENCH,
      set_number: i + 1,
      weight_g: set.weight_g,
      reps: set.reps,
      rir: set.rir,
      is_warmup: false,
    }),
  );
  endSession(db, s.session_id, {});
  return s;
}

describe("training: calc", () => {
  it("epley1RM control values", () => {
    expect(epley1RM(50000, 10)).toBe(66667); // 50000 * 1.3333
    expect(epley1RM(60000, 5)).toBe(70000); // 60000 * 1.16667
    expect(epley1RM(100000, 1)).toBe(103333); // 100000 * 1.0333
    expect(epley1RM(80000, 0)).toBe(0); // zero reps
    expect(epley1RM(0, 8)).toBe(0); // zero weight
  });

  it("setVolumeG and roundToIncrement", () => {
    expect(setVolumeG(50000, 10)).toBe(500000);
    expect(roundToIncrement(51200, 2500)).toBe(50000);
    expect(roundToIncrement(51300, 2500)).toBe(52500);
    expect(roundToIncrement(1234, 0)).toBe(1234); // no increment → passthrough
  });
});

describe("training: getToday rotation & ramp-up", () => {
  let db: DB;
  beforeEach(() => {
    db = setupTestDb();
  });

  it("fresh state → routine A, index 1, ramp-up", () => {
    expect(getToday(db)).toEqual({
      routine_id: "routine-a",
      session_index: 1,
      is_rampup: true,
    });
  });

  it("alternates A→B and increments index", () => {
    startSession(db, { routine_id: "routine-a", session_index: 1 });
    const t = getToday(db);
    expect(t.routine_id).toBe("routine-b");
    expect(t.session_index).toBe(2);
    expect(t.is_rampup).toBe(true);
  });

  it("index 4 is not ramp-up", () => {
    startSession(db, { routine_id: "routine-a", session_index: 3 });
    expect(getToday(db).session_index).toBe(4);
    expect(getToday(db).is_rampup).toBe(false);
  });

  it("index resets 10 → 1 (new block)", () => {
    startSession(db, { routine_id: "routine-a", session_index: 10 });
    expect(getToday(db).session_index).toBe(1);
  });
});

describe("training: suggestProgression branches", () => {
  let db: DB;
  beforeEach(() => {
    db = setupTestDb();
  });

  it("rampup: session_index ≤ 3 → action rampup, ~65% of working, no increase", () => {
    completedBenchSession(db, 5, [
      { weight_g: 50000, reps: 10, rir: 2 },
      { weight_g: 50000, reps: 10, rir: 2 },
      { weight_g: 50000, reps: 10, rir: 2 },
    ]);
    const s = suggestProgression(db, BENCH, 2);
    expect(s.action).toBe("rampup");
    expect(s.weightG).toBe(roundToIncrement(50000 * 0.65, 2500)); // 32500
    expect(s.rirTarget).toBe(4);
  });

  it("increase: all sets at rep_max AND rir ≤ target (boundary) → +increment, reps→rep_min", () => {
    completedBenchSession(db, 5, [
      { weight_g: 50000, reps: 10, rir: 2 }, // reps == rep_max, rir == target
      { weight_g: 50000, reps: 10, rir: 1 },
      { weight_g: 50000, reps: 10, rir: 2 },
    ]);
    const s = suggestProgression(db, BENCH, 5);
    expect(s.action).toBe("increase");
    expect(s.weightG).toBe(52500); // +2500
    expect(s.repsTarget).toBe(8); // rep_min
  });

  it("hold: hit reps but rir above target → hold (not increase)", () => {
    completedBenchSession(db, 5, [
      { weight_g: 50000, reps: 10, rir: 3 }, // rir 3 > target 2
      { weight_g: 50000, reps: 10, rir: 3 },
      { weight_g: 50000, reps: 10, rir: 3 },
    ]);
    expect(suggestProgression(db, BENCH, 5).action).toBe("hold");
  });

  it("hold: mid-range reps, no failure → hold with weight unchanged", () => {
    completedBenchSession(db, 5, [
      { weight_g: 50000, reps: 10, rir: 2 },
      { weight_g: 50000, reps: 10, rir: 2 },
      { weight_g: 50000, reps: 9, rir: 1 }, // below rep_max but above rep_min
    ]);
    const s = suggestProgression(db, BENCH, 5);
    expect(s.action).toBe("hold");
    expect(s.weightG).toBe(50000);
  });

  it("deload_or_hold: a set below rep_min (failure) → deload_or_hold", () => {
    completedBenchSession(db, 5, [
      { weight_g: 50000, reps: 10, rir: 2 },
      { weight_g: 50000, reps: 7, rir: 0 }, // 7 < rep_min 8
      { weight_g: 50000, reps: 6, rir: 0 },
    ]);
    const s = suggestProgression(db, BENCH, 5);
    expect(s.action).toBe("deload_or_hold");
    expect(s.weightG).toBe(50000);
  });

  it("no history → hold at 0 (comfortable start)", () => {
    const s = suggestProgression(db, BENCH, 5);
    expect(s.action).toBe("hold");
    expect(s.weightG).toBe(0);
  });

  it("uses exercise-specific increment (leg press +5000)", () => {
    const s = startSession(db, { routine_id: "routine-a", session_index: 5 });
    // leg press rep range 10–12
    [12, 12, 12].forEach((reps, i) =>
      logSet(db, s.session_id, {
        exercise_id: LEG_PRESS,
        set_number: i + 1,
        weight_g: 100000,
        reps,
        rir: 1,
        is_warmup: false,
      }),
    );
    endSession(db, s.session_id, {});
    const sug = suggestProgression(db, LEG_PRESS, 6);
    expect(sug.action).toBe("increase");
    expect(sug.weightG).toBe(105000); // +5000
  });
});

describe("training: getLastPerformance", () => {
  let db: DB;
  beforeEach(() => {
    db = setupTestDb();
  });

  it("returns latest non-warmup working sets, excludes warmups", () => {
    const s = startSession(db, { routine_id: "routine-a", session_index: 5 });
    logSet(db, s.session_id, { exercise_id: BENCH, set_number: 0, weight_g: 20000, reps: 15, rir: 5, is_warmup: true });
    logSet(db, s.session_id, { exercise_id: BENCH, set_number: 1, weight_g: 50000, reps: 10, rir: 2, is_warmup: false });
    logSet(db, s.session_id, { exercise_id: BENCH, set_number: 2, weight_g: 50000, reps: 9, rir: 1, is_warmup: false });
    endSession(db, s.session_id, {});

    const perf = getLastPerformance(db, BENCH);
    expect(perf).toHaveLength(2); // warmup excluded
    expect(perf.map((p) => p.reps)).toEqual([10, 9]);
  });

  it("returns the most recent session's sets, not older ones", () => {
    completedBenchSession(db, 5, [{ weight_g: 50000, reps: 10, rir: 2 }]);
    completedBenchSession(db, 6, [{ weight_g: 55000, reps: 8, rir: 1 }]);
    const perf = getLastPerformance(db, BENCH);
    expect(perf).toHaveLength(1);
    expect(perf[0].weightG).toBe(55000);
  });

  it("picks the last session by started_at, not insertion order (backdating aware)", () => {
    // s1 inserted FIRST but dated LATER; s2 inserted SECOND but dated EARLIER.
    const s1 = startSession(db, { routine_id: "routine-a", session_index: 5, started_at: "2026-06-10T09:00:00.000Z" });
    logSet(db, s1.session_id, { exercise_id: BENCH, set_number: 1, weight_g: 55000, reps: 8, rir: 1, is_warmup: false });
    endSession(db, s1.session_id, { ended_at: "2026-06-10T10:00:00.000Z" });

    const s2 = startSession(db, { routine_id: "routine-a", session_index: 6, started_at: "2026-06-03T09:00:00.000Z" });
    logSet(db, s2.session_id, { exercise_id: BENCH, set_number: 1, weight_g: 50000, reps: 10, rir: 2, is_warmup: false });
    endSession(db, s2.session_id, { ended_at: "2026-06-03T10:00:00.000Z" });

    // Latest by DATE is s1 (2026-06-10), even though s2 was inserted later.
    const perf = getLastPerformance(db, BENCH);
    expect(perf).toHaveLength(1);
    expect(perf[0].weightG).toBe(55000);
  });

  it("ignores soft-deleted sets", () => {
    const s = startSession(db, { routine_id: "routine-a", session_index: 5 });
    const a = logSet(db, s.session_id, { exercise_id: BENCH, set_number: 1, weight_g: 50000, reps: 10, rir: 2, is_warmup: false });
    logSet(db, s.session_id, { exercise_id: BENCH, set_number: 2, weight_g: 50000, reps: 9, rir: 1, is_warmup: false });
    endSession(db, s.session_id, {});
    db.update(schema.setLogs).set({ isDeleted: 1 }).where(eq(schema.setLogs.id, a.set_id)).run();

    const perf = getLastPerformance(db, BENCH);
    expect(perf).toHaveLength(1);
    expect(perf[0].reps).toBe(9);
  });

  it("returns empty array for an exercise with no history", () => {
    expect(getLastPerformance(db, BENCH)).toEqual([]);
  });
});

describe("training: getVolumeStats", () => {
  let db: DB;
  beforeEach(() => {
    db = setupTestDb();
  });

  it("excludes warmups and soft-deleted; groups by muscle group", () => {
    const s = startSession(db, { routine_id: "routine-a", session_index: 5 });
    logSet(db, s.session_id, { exercise_id: BENCH, set_number: 0, weight_g: 20000, reps: 15, rir: 5, is_warmup: true }); // warmup — excluded
    logSet(db, s.session_id, { exercise_id: BENCH, set_number: 1, weight_g: 50000, reps: 10, rir: 2, is_warmup: false }); // 500000
    logSet(db, s.session_id, { exercise_id: BENCH, set_number: 2, weight_g: 50000, reps: 10, rir: 2, is_warmup: false }); // 500000
    const deleted = logSet(db, s.session_id, { exercise_id: BENCH, set_number: 3, weight_g: 99000, reps: 10, rir: 2, is_warmup: false });
    endSession(db, s.session_id, {});
    db.update(schema.setLogs).set({ isDeleted: 1 }).where(eq(schema.setLogs.id, deleted.set_id)).run();

    const vol = getVolumeStats(db, {});
    expect(vol.totalVolumeG).toBe(1000000); // warmup + deleted excluded
    const chest = vol.byGroup.find((g) => g.muscleGroup === "chest");
    expect(chest?.volumeG).toBe(1000000);
    expect(chest?.sets).toBe(2);
  });

  it("respects date range (from/to) — out-of-range excluded", () => {
    completedBenchSession(db, 5, [{ weight_g: 50000, reps: 10, rir: 2 }]);
    const past = getVolumeStats(db, { from: "2000-01-01", to: "2000-12-31" });
    expect(past.totalVolumeG).toBe(0);
  });
});

describe("training: session lifecycle & analytics", () => {
  let db: DB;
  beforeEach(() => {
    db = setupTestDb();
  });

  it("quickRepeatLastSet copies the previous set into the session", () => {
    const s = startSession(db, { routine_id: "routine-a", session_index: 5 });
    logSet(db, s.session_id, { exercise_id: BENCH, set_number: 1, weight_g: 50000, reps: 10, rir: 2, is_warmup: false });
    quickRepeatLastSet(db, s.session_id, BENCH);
    const perf = getLastPerformance(db, BENCH);
    expect(perf).toHaveLength(2);
    expect(perf[1].weightG).toBe(50000);
    expect(perf[1].reps).toBe(10);
    expect(perf[1].setNumber).toBe(2);
  });

  it("endSession computes non-negative duration and getRoutinePlan assembles sections", () => {
    const s = startSession(db, { routine_id: "routine-a", session_index: 5 });
    const end = endSession(db, s.session_id, { ended_at: new Date(Date.parse("2026-07-02T10:30:00Z")).toISOString() });
    expect(end.duration_s).toBeGreaterThanOrEqual(0);

    const plan = getRoutinePlan(db, "routine-a", 5);
    expect(plan.sections.main.length).toBe(5);
    expect(plan.sections.warmup.length).toBeGreaterThan(0);
    expect(plan.isRampup).toBe(false);
    // warmup/reab items carry no suggestion
    expect(plan.sections.warmup.every((i) => i.suggestion === null)).toBe(true);
  });

  it("startSession stores an explicit started_at (backdating), not now()", () => {
    const backdated = "2026-06-03T09:00:00.000Z";
    const s = startSession(db, {
      routine_id: "routine-a",
      session_index: 5,
      started_at: backdated,
    });
    const row = db
      .select()
      .from(schema.workoutSessions)
      .where(eq(schema.workoutSessions.id, s.session_id))
      .get() as any;
    expect(row.startedAt).toBe(backdated);
  });

  it("startSession without started_at stores a recent now() timestamp", () => {
    const before = Date.now();
    const s = startSession(db, { routine_id: "routine-a", session_index: 5 });
    const row = db
      .select()
      .from(schema.workoutSessions)
      .where(eq(schema.workoutSessions.id, s.session_id))
      .get() as any;
    const t = Date.parse(row.startedAt);
    expect(Number.isNaN(t)).toBe(false);
    expect(row.startedAt).not.toBe("2026-06-03T09:00:00.000Z");
    expect(t).toBeGreaterThanOrEqual(before - 1000);
    expect(t).toBeLessThanOrEqual(Date.now() + 1000);
  });

  it("endSession with both manual timestamps computes duration from them", () => {
    const s = startSession(db, { routine_id: "routine-a", session_index: 5 });
    const end = endSession(db, s.session_id, {
      started_at: "2026-06-03T09:00:00.000Z",
      ended_at: "2026-06-03T10:00:00.000Z",
    });
    expect(end.duration_s).toBe(3600);
  });

  it("endSession backdating corrects the start and threads through analytics", () => {
    const s = startSession(db, { routine_id: "routine-a", session_index: 5 });
    logSet(db, s.session_id, {
      exercise_id: BENCH,
      set_number: 1,
      weight_g: 50000,
      reps: 10,
      rir: 2,
      is_warmup: false,
    });
    const end = endSession(db, s.session_id, {
      started_at: "2026-06-03T09:00:00.000Z",
      ended_at: "2026-06-03T10:30:00.000Z",
    });
    expect(end.duration_s).toBe(5400);

    const sessions = listSessions(db);
    const mine = sessions.find((x) => x.id === s.session_id)!;
    expect(mine.startedAt).toBe("2026-06-03T09:00:00.000Z");
    expect(mine.durationS).toBe(5400);

    const prog = getProgression(db, BENCH);
    expect(prog.points).toHaveLength(1);
    expect(prog.points[0].date).toBe("2026-06-03");
  });

  it("getProgression builds an e1RM trend across sessions", () => {
    completedBenchSession(db, 5, [{ weight_g: 50000, reps: 10, rir: 2 }]);
    completedBenchSession(db, 6, [{ weight_g: 55000, reps: 8, rir: 1 }]);
    const prog = getProgression(db, BENCH);
    expect(prog.points).toHaveLength(2);
    expect(prog.currentE1rmG).toBe(epley1RM(55000, 8));
    expect(prog.changeE1rmG).toBe(epley1RM(55000, 8) - epley1RM(50000, 10));
  });

  it("patchRoutineExercise updates the template and leaves other fields intact", () => {
    const plan = getRoutinePlan(db, "routine-a", 5);
    const benchRe = plan.sections.main.find((i) => i.routineExercise.exerciseId === BENCH)!.routineExercise;
    const updated = patchRoutineExercise(db, benchRe.id, { target_sets: 4, rep_max: 12 });
    expect(updated.targetSets).toBe(4);
    expect(updated.repMax).toBe(12);
    expect(updated.repMin).toBe(benchRe.repMin); // unchanged
    expect(() => patchRoutineExercise(db, "nope", { target_sets: 3 })).toThrow();
  });

  it("listSessions reports working set counts and volume", () => {
    completedBenchSession(db, 5, [
      { weight_g: 50000, reps: 10, rir: 2 },
      { weight_g: 50000, reps: 10, rir: 2 },
    ]);
    const sessions = listSessions(db);
    expect(sessions).toHaveLength(1);
    expect(sessions[0].totalSets).toBe(2);
    expect(sessions[0].totalVolumeG).toBe(1000000);
    expect(sessions[0].routineName).toBe("Workout A");
  });
});

describe("training: exercise CRUD", () => {
  let db: DB;
  beforeEach(() => {
    db = setupTestDb();
  });

  it("creates, reads, searches, updates and soft-deletes an exercise", () => {
    const created = createExercise(db, {
      name: "Cable Crossover",
      name_ru: "Кроссовер",
      muscle_group: "chest",
      pattern: "isolation",
      equipment: ["cable"],
      is_unilateral: false,
      is_safe_lower_back: false,
      default_rep_min: 12,
      default_rep_max: 15,
      min_increment_g: 2500,
    });
    expect(created.id).toBeTruthy();
    expect(JSON.parse(created.equipment)).toEqual(["cable"]);

    expect(getExerciseById(db, created.id)?.name).toBe("Cable Crossover");
    expect(listExercises(db, { q: "кроссовер" }).map((e) => e.id)).toContain(created.id);
    expect(listExercises(db, { muscleGroup: "chest" }).some((e) => e.id === created.id)).toBe(true);

    const updated = updateExercise(db, created.id, { min_increment_g: 5000, name_ru: "Сведение" });
    expect(updated.minIncrementG).toBe(5000);
    expect(updated.nameRu).toBe("Сведение");
    expect(updated.name).toBe("Cable Crossover"); // unchanged

    deleteExercise(db, created.id);
    expect(listExercises(db).some((e) => e.id === created.id)).toBe(false);
    expect(listExercises(db, { includeDeleted: true }).some((e) => e.id === created.id)).toBe(true);
  });
});

describe("training: routine + composition CRUD", () => {
  let db: DB;
  beforeEach(() => {
    db = setupTestDb();
  });

  it("creates a routine, adds/reorders positions, and cascade-deletes", () => {
    const r = createRoutine(db, { name: "Workout C", name_ru: "Тренировка C", notes: "push" });
    expect(r.sortOrder).toBe(3); // after seeded A(1) + B(2)

    const p1 = addRoutineExercise(db, r.id, {
      exercise_id: "ex-bench_press",
      section: "main",
      target_sets: 3,
      rep_min: 8,
      rep_max: 10,
      target_rir: 2,
    });
    const p2 = addRoutineExercise(db, r.id, {
      exercise_id: "ex-pec_deck",
      section: "main",
      target_sets: 2,
      rep_min: 12,
      rep_max: 15,
      target_rir: 2,
    });
    expect(p1.sortOrder).toBe(1);
    expect(p2.sortOrder).toBe(2); // appended

    expect(listRoutineExercises(db, r.id)).toHaveLength(2);

    const updated = updateRoutine(db, r.id, { notes: "push day" });
    expect(updated.notes).toBe("push day");

    deleteRoutineExercise(db, p1.id);
    expect(listRoutineExercises(db, r.id).map((x) => x.id)).toEqual([p2.id]);

    deleteRoutine(db, r.id);
    expect(listRoutines(db).some((x) => x.id === r.id)).toBe(false);
    expect(listRoutineExercises(db, r.id)).toHaveLength(0); // positions cascade-deleted
  });

  it("patchRoutineExercise can move section, reorder and toggle ramp-up", () => {
    const r = createRoutine(db, { name: "Tmp", name_ru: "Врем" });
    const p = addRoutineExercise(db, r.id, {
      exercise_id: "ex-bench_press",
      section: "main",
      target_sets: 3,
      rep_min: 8,
      rep_max: 10,
      target_rir: 2,
    });
    const patched = patchRoutineExercise(db, p.id, {
      section: "reab",
      sort_order: 9,
      is_rampup_scaled: false,
    });
    expect(patched.section).toBe("reab");
    expect(patched.sortOrder).toBe(9);
    expect(patched.isRampupScaled).toBe(0);
  });
});

describe("training: soft-delete sets & sessions", () => {
  let db: DB;
  beforeEach(() => {
    db = setupTestDb();
  });

  it("deleteSet removes a set from performance and volume", () => {
    const s = startSession(db, { routine_id: "routine-a", session_index: 5 });
    const a = logSet(db, s.session_id, { exercise_id: BENCH, set_number: 1, weight_g: 50000, reps: 10, rir: 2, is_warmup: false });
    logSet(db, s.session_id, { exercise_id: BENCH, set_number: 2, weight_g: 50000, reps: 9, rir: 1, is_warmup: false });
    endSession(db, s.session_id, {});

    deleteSet(db, a.set_id);
    expect(getLastPerformance(db, BENCH).map((x) => x.reps)).toEqual([9]);
    expect(getVolumeStats(db, {}).totalVolumeG).toBe(50000 * 9);
  });

  it("deleteSession excludes it and its sets from all analytics", () => {
    const s = completedBenchSession(db, 5, [
      { weight_g: 50000, reps: 10, rir: 2 },
      { weight_g: 50000, reps: 10, rir: 2 },
    ]);
    deleteSession(db, s.session_id);
    expect(listSessions(db)).toHaveLength(0);
    expect(getVolumeStats(db, {}).totalVolumeG).toBe(0);
    expect(getProgression(db, BENCH).points).toHaveLength(0);
    expect(getLastPerformance(db, BENCH)).toEqual([]);
  });
});

describe("training: static / timed exercises (duration_s)", () => {
  let db: DB;
  const PLANK = "ex-plank"; // seeded core exercise
  beforeEach(() => {
    db = setupTestDb();
  });

  function plankSession(sessionIndex: number, holdS: number) {
    const s = startSession(db, { routine_id: "routine-a", session_index: sessionIndex });
    logSet(db, s.session_id, {
      exercise_id: PLANK,
      set_number: 1,
      weight_g: 0,
      reps: 0,
      duration_s: holdS,
      is_warmup: false,
    });
    endSession(db, s.session_id, {});
    return s;
  }

  it("formatDuration control values", () => {
    expect(formatDuration(45)).toBe("45s");
    expect(formatDuration(90)).toBe("1m 30s");
    expect(formatDuration(120)).toBe("2m");
    expect(formatDuration(3661)).toBe("1h 1m 1s");
  });

  it("stores duration_s and returns it in last performance", () => {
    plankSession(5, 40);
    const perf = getLastPerformance(db, PLANK);
    expect(perf).toHaveLength(1);
    expect(perf[0].durationS).toBe(40);
  });

  it("getVolumeStats sums hold time and keeps weighted volume at 0", () => {
    plankSession(5, 40);
    const vol = getVolumeStats(db, {});
    expect(vol.totalDurationS).toBe(40);
    expect(vol.totalVolumeG).toBe(0); // bodyweight → no weighted volume
    const core = vol.byGroup.find((g) => g.muscleGroup === "core");
    expect(core?.durationS).toBe(40);
    expect(core?.volumeG).toBe(0);
  });

  it("getProgression uses the duration metric for timed exercises", () => {
    plankSession(5, 30);
    plankSession(6, 45);
    const prog = getProgression(db, PLANK);
    expect(prog.metric).toBe("duration");
    expect(prog.points.map((p) => p.durationS)).toEqual([30, 45]);
    expect(prog.currentDurationS).toBe(45);
    expect(prog.changeDurationS).toBe(15);
    expect(prog.currentE1rmG).toBe(0); // no weight metric
  });

  it("weight-based exercises still use the e1RM metric", () => {
    completedBenchSession(db, 5, [{ weight_g: 50000, reps: 10, rir: 2 }]);
    const prog = getProgression(db, BENCH);
    expect(prog.metric).toBe("weight");
    expect(prog.currentE1rmG).toBe(epley1RM(50000, 10));
    expect(prog.currentDurationS).toBe(0);
  });
});

describe("training: session plan overrides", () => {
  let db: DB;
  beforeEach(() => {
    db = setupTestDb();
  });

  it("records overrides, lists per session, and reports deviation", () => {
    const s = startSession(db, { routine_id: "routine-a", session_index: 5 });
    const re = listRoutineExercises(db, "routine-a").find((x) => x.exerciseId === BENCH)!;
    const o = recordOverride(db, s.session_id, {
      routine_exercise_id: re.id,
      replaced_exercise_id: "ex-pec_deck",
      reason: "скамья занята",
    });
    expect(o.reason).toBe("скамья занята");

    expect(listOverrides(db, s.session_id)).toHaveLength(1);
    expect(listOverrides(db)).toHaveLength(1);

    const dev = getPlanDeviation(db);
    expect(dev.totalOverrides).toBe(1);
    expect(dev.byRoutineExercise[0]).toMatchObject({
      routineExerciseId: re.id,
      replacedExerciseId: "ex-pec_deck",
      count: 1,
    });
  });
});
