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
  epley1RM,
  setVolumeG,
  roundToIncrement,
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
