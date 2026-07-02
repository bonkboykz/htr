import { eq, and, desc, asc, sql } from "drizzle-orm";
import type { DB } from "../db/index.js";
import { schema } from "../db/index.js";
import { newId } from "../id.js";
import type {
  Exercise,
  Routine,
  RoutineExercise,
  WorkoutSession,
  SetRow,
  ProgressionSuggestion,
  RoutinePlan,
  RoutinePlanItem,
  ProgressionHistory,
  ProgressionPoint,
  VolumeByGroup,
  VolumeGroupStat,
  SessionSummary,
  TrainingRange,
} from "../types.js";
import type {
  StartSessionInputT,
  LogSetInputT,
  EndSessionInputT,
  PatchRoutineExerciseInputT,
} from "./schemas.js";
import { epley1RM, setVolumeG, roundToIncrement } from "./calc.js";

const DEFAULT_INCREMENT_G = 2500;
const RAMPUP_MAX_INDEX = 3;
const RAMPUP_PCT = 0.65; // ~60–70% of working weight during ramp-up

// ---------- internal helpers ----------

function lastSession(db: DB): WorkoutSession | null {
  return (
    (db
      .select()
      .from(schema.workoutSessions)
      .where(eq(schema.workoutSessions.isDeleted, 0))
      .orderBy(sql`rowid DESC`)
      .limit(1)
      .get() as WorkoutSession) ?? null
  );
}

function activeRoutinesOrdered(db: DB): Routine[] {
  return db
    .select()
    .from(schema.routines)
    .where(eq(schema.routines.isDeleted, 0))
    .orderBy(asc(schema.routines.sortOrder))
    .all() as Routine[];
}

function getExercise(db: DB, exerciseId: string): Exercise | null {
  return (
    (db
      .select()
      .from(schema.exercises)
      .where(eq(schema.exercises.id, exerciseId))
      .get() as Exercise) ?? null
  );
}

// Config (rep range / target RIR) for an exercise — taken from a routine position,
// preferring the `main` section. Falls back to the exercise's catalog defaults.
function configFor(
  db: DB,
  exerciseId: string,
): { repMin: number; repMax: number; targetRir: number; incrementG: number } {
  const ex = getExercise(db, exerciseId);
  const rows = db
    .select()
    .from(schema.routineExercises)
    .where(
      and(
        eq(schema.routineExercises.exerciseId, exerciseId),
        eq(schema.routineExercises.isDeleted, 0),
      ),
    )
    .all() as RoutineExercise[];
  const re = rows.find((r) => r.section === "main") ?? rows[0];
  return {
    repMin: re?.repMin ?? ex?.defaultRepMin ?? 8,
    repMax: re?.repMax ?? ex?.defaultRepMax ?? 12,
    targetRir: re?.targetRir ?? 2,
    incrementG: ex?.minIncrementG ?? DEFAULT_INCREMENT_G,
  };
}

// ---------- write (hot path) ----------

export function startSession(
  db: DB,
  input: StartSessionInputT,
): { session_id: string; session_index: number } {
  const id = newId();
  const last = lastSession(db);
  const sessionIndex =
    input.session_index ?? (last ? (last.sessionIndex % 10) + 1 : 1);
  const startedAt = new Date().toISOString();
  db.insert(schema.workoutSessions)
    .values({
      id,
      routineId: input.routine_id,
      sessionIndex,
      startedAt,
    })
    .run();
  return { session_id: id, session_index: sessionIndex };
}

export function logSet(
  db: DB,
  sessionId: string,
  input: LogSetInputT,
): { set_id: string } {
  const id = newId();
  db.insert(schema.setLogs)
    .values({
      id,
      sessionId,
      exerciseId: input.exercise_id,
      setNumber: input.set_number,
      weightG: input.weight_g,
      reps: input.reps,
      rir: input.rir ?? null,
      isWarmup: input.is_warmup ? 1 : 0,
    })
    .run();
  return { set_id: id };
}

export function quickRepeatLastSet(
  db: DB,
  sessionId: string,
  exerciseId: string,
): { set_id: string } {
  const previous = db
    .select()
    .from(schema.setLogs)
    .where(
      and(
        eq(schema.setLogs.exerciseId, exerciseId),
        eq(schema.setLogs.isDeleted, 0),
      ),
    )
    .orderBy(sql`rowid DESC`)
    .limit(1)
    .get() as SetRow | undefined;
  if (!previous) {
    throw new Error("No previous set to repeat for this exercise");
  }

  const existing = db
    .select()
    .from(schema.setLogs)
    .where(
      and(
        eq(schema.setLogs.sessionId, sessionId),
        eq(schema.setLogs.exerciseId, exerciseId),
        eq(schema.setLogs.isDeleted, 0),
      ),
    )
    .all() as SetRow[];
  const nextSetNumber = existing.length + 1;

  const id = newId();
  db.insert(schema.setLogs)
    .values({
      id,
      sessionId,
      exerciseId,
      setNumber: nextSetNumber,
      weightG: previous.weightG,
      reps: previous.reps,
      rir: previous.rir,
      isWarmup: previous.isWarmup,
    })
    .run();
  return { set_id: id };
}

export function endSession(
  db: DB,
  sessionId: string,
  input: EndSessionInputT,
): { duration_s: number } {
  const session = db
    .select()
    .from(schema.workoutSessions)
    .where(eq(schema.workoutSessions.id, sessionId))
    .get() as WorkoutSession | undefined;
  if (!session) {
    throw new Error("Session not found");
  }

  const endedAt = input.ended_at ?? new Date().toISOString();
  const updates: { endedAt: string; notes?: string } = { endedAt };
  if (input.notes !== undefined) updates.notes = input.notes;
  db.update(schema.workoutSessions)
    .set(updates)
    .where(eq(schema.workoutSessions.id, sessionId))
    .run();

  const durationS = Math.max(
    0,
    Math.round(
      (new Date(endedAt).getTime() - new Date(session.startedAt).getTime()) /
        1000,
    ),
  );
  return { duration_s: durationS };
}

// ---------- screen reads ----------

export function getToday(db: DB): {
  routine_id: string;
  session_index: number;
  is_rampup: boolean;
} {
  const routines = activeRoutinesOrdered(db);
  if (routines.length === 0) {
    throw new Error("No routines configured. Seed the training program first.");
  }
  const last = lastSession(db);
  let routineId: string;
  let sessionIndex: number;
  if (!last) {
    routineId = routines[0].id;
    sessionIndex = 1;
  } else {
    const idx = routines.findIndex((r) => r.id === last.routineId);
    const next = routines[(idx + 1) % routines.length] ?? routines[0];
    routineId = next.id;
    sessionIndex = (last.sessionIndex % 10) + 1;
  }
  return {
    routine_id: routineId,
    session_index: sessionIndex,
    is_rampup: sessionIndex <= RAMPUP_MAX_INDEX,
  };
}

// Working (non-warmup, non-deleted) sets of the most recent session that has
// any such set for this exercise. Ordered by set number.
export function getLastPerformance(db: DB, exerciseId: string): SetRow[] {
  const lastSet = db
    .select()
    .from(schema.setLogs)
    .where(
      and(
        eq(schema.setLogs.exerciseId, exerciseId),
        eq(schema.setLogs.isWarmup, 0),
        eq(schema.setLogs.isDeleted, 0),
      ),
    )
    .orderBy(sql`rowid DESC`)
    .limit(1)
    .get() as SetRow | undefined;
  if (!lastSet) return [];

  return db
    .select()
    .from(schema.setLogs)
    .where(
      and(
        eq(schema.setLogs.sessionId, lastSet.sessionId),
        eq(schema.setLogs.exerciseId, exerciseId),
        eq(schema.setLogs.isWarmup, 0),
        eq(schema.setLogs.isDeleted, 0),
      ),
    )
    .orderBy(asc(schema.setLogs.setNumber))
    .all() as SetRow[];
}

export function getRoutinePlan(
  db: DB,
  routineId: string,
  sessionIndex?: number,
): RoutinePlan {
  const routine = db
    .select()
    .from(schema.routines)
    .where(
      and(eq(schema.routines.id, routineId), eq(schema.routines.isDeleted, 0)),
    )
    .get() as Routine | undefined;
  if (!routine) {
    throw new Error("Routine not found");
  }

  const idx = sessionIndex ?? getToday(db).session_index;
  const isRampup = idx <= RAMPUP_MAX_INDEX;

  const rows = db
    .select()
    .from(schema.routineExercises)
    .where(
      and(
        eq(schema.routineExercises.routineId, routineId),
        eq(schema.routineExercises.isDeleted, 0),
      ),
    )
    .orderBy(asc(schema.routineExercises.sortOrder))
    .all() as RoutineExercise[];

  const sections: RoutinePlan["sections"] = { warmup: [], main: [], reab: [] };
  for (const re of rows) {
    const exercise = getExercise(db, re.exerciseId);
    // Only progressable main-section movements get a suggestion.
    const suggestion =
      re.section === "main" && (exercise?.minIncrementG ?? 0) > 0
        ? suggestProgression(db, re.exerciseId, idx)
        : null;
    const item: RoutinePlanItem = {
      routineExercise: re,
      exercise,
      lastPerformance: getLastPerformance(db, re.exerciseId),
      suggestion,
    };
    const bucket = (sections as Record<string, RoutinePlanItem[]>)[re.section];
    if (bucket) bucket.push(item);
  }

  return { routine, sessionIndex: idx, isRampup, sections };
}

// ---------- progression (hybrid core — deterministic, never writes) ----------

export function suggestProgression(
  db: DB,
  exerciseId: string,
  sessionIndex?: number,
): ProgressionSuggestion {
  const idx = sessionIndex ?? getToday(db).session_index;
  const { repMin, repMax, targetRir, incrementG } = configFor(db, exerciseId);
  const working = getLastPerformance(db, exerciseId);
  const lastWeight = working.length > 0 ? working[0].weightG : 0;

  // Ramp-up: first sessions of a block — learn the movement, don't add load.
  if (idx <= RAMPUP_MAX_INDEX) {
    const weightG =
      lastWeight > 0
        ? roundToIncrement(Math.round(lastWeight * RAMPUP_PCT), incrementG)
        : 0;
    return {
      exerciseId,
      action: "rampup",
      weightG,
      repsTarget: repMin,
      rirTarget: 4,
      rationale:
        "Ramp-up (занятие ≤3): ~60–70% рабочего веса, учим движение — связки адаптируются медленнее мышц.",
    };
  }

  // No history yet — hold at a comfortable starting point.
  if (working.length === 0) {
    return {
      exerciseId,
      action: "hold",
      weightG: 0,
      repsTarget: repMin,
      rirTarget: targetRir,
      rationale: "Нет истории по упражнению — начни с комфортного веса.",
    };
  }

  const allHitTop = working.every(
    (s) => s.reps >= repMax && (s.rir ?? 0) <= targetRir,
  );
  const anyFail = working.some((s) => s.reps < repMin);

  if (allHitTop) {
    return {
      exerciseId,
      action: "increase",
      weightG: lastWeight + incrementG,
      repsTarget: repMin,
      rirTarget: targetRir,
      rationale: "Добил верх диапазона при RIR ≤ target → +шаг веса, повторы к rep_min.",
    };
  }

  if (anyFail) {
    return {
      exerciseId,
      action: "deload_or_hold",
      weightG: lastWeight,
      repsTarget: repMin,
      rirTarget: targetRir,
      rationale: "Был недобор ниже rep_min → удержать вес или снизить, восстановить технику.",
    };
  }

  const maxReps = Math.max(...working.map((s) => s.reps));
  return {
    exerciseId,
    action: "hold",
    weightG: lastWeight,
    repsTarget: Math.min(repMax, maxReps + 1),
    rirTarget: targetRir,
    rationale: "Тот же вес, добери повторы к верху диапазона.",
  };
}

// ---------- plan edits (persistent template changes) ----------

export function patchRoutineExercise(
  db: DB,
  routineExerciseId: string,
  input: PatchRoutineExerciseInputT,
): RoutineExercise {
  const existing = db
    .select()
    .from(schema.routineExercises)
    .where(eq(schema.routineExercises.id, routineExerciseId))
    .get() as RoutineExercise | undefined;
  if (!existing || existing.isDeleted) {
    throw new Error("Routine exercise not found");
  }

  const updates: Partial<RoutineExercise> = {};
  if (input.exercise_id !== undefined) updates.exerciseId = input.exercise_id;
  if (input.target_sets !== undefined) updates.targetSets = input.target_sets;
  if (input.rep_min !== undefined) updates.repMin = input.rep_min;
  if (input.rep_max !== undefined) updates.repMax = input.rep_max;
  if (input.target_rir !== undefined) updates.targetRir = input.target_rir;
  if (input.notes !== undefined) updates.notes = input.notes;

  if (Object.keys(updates).length > 0) {
    db.update(schema.routineExercises)
      .set(updates)
      .where(eq(schema.routineExercises.id, routineExerciseId))
      .run();
  }

  return db
    .select()
    .from(schema.routineExercises)
    .where(eq(schema.routineExercises.id, routineExerciseId))
    .get() as RoutineExercise;
}

// ---------- analytics ----------

// Map of session id -> { startedAt, endedAt, routineId } for non-deleted sessions.
function sessionMap(
  db: DB,
): Map<string, { startedAt: string; endedAt: string | null; routineId: string }> {
  const rows = db
    .select({
      id: schema.workoutSessions.id,
      startedAt: schema.workoutSessions.startedAt,
      endedAt: schema.workoutSessions.endedAt,
      routineId: schema.workoutSessions.routineId,
    })
    .from(schema.workoutSessions)
    .where(eq(schema.workoutSessions.isDeleted, 0))
    .all() as {
    id: string;
    startedAt: string;
    endedAt: string | null;
    routineId: string;
  }[];
  const map = new Map<
    string,
    { startedAt: string; endedAt: string | null; routineId: string }
  >();
  for (const r of rows)
    map.set(r.id, {
      startedAt: r.startedAt,
      endedAt: r.endedAt,
      routineId: r.routineId,
    });
  return map;
}

function inRange(date: string, range?: TrainingRange): boolean {
  if (!range) return true;
  const d = date.slice(0, 10);
  if (range.from && d < range.from) return false;
  if (range.to && d > range.to) return false;
  return true;
}

export function getProgression(
  db: DB,
  exerciseId: string,
  range?: TrainingRange,
): ProgressionHistory {
  const sessions = sessionMap(db);
  const sets = db
    .select()
    .from(schema.setLogs)
    .where(
      and(
        eq(schema.setLogs.exerciseId, exerciseId),
        eq(schema.setLogs.isWarmup, 0),
        eq(schema.setLogs.isDeleted, 0),
      ),
    )
    .all() as SetRow[];

  // Group by session; take the top working set per session.
  const bySession = new Map<string, SetRow>();
  for (const s of sets) {
    const meta = sessions.get(s.sessionId);
    if (!meta) continue; // orphan / deleted session
    if (!inRange(meta.startedAt, range)) continue;
    const cur = bySession.get(s.sessionId);
    if (
      !cur ||
      s.weightG > cur.weightG ||
      (s.weightG === cur.weightG && s.reps > cur.reps)
    ) {
      bySession.set(s.sessionId, s);
    }
  }

  const points: ProgressionPoint[] = [...bySession.entries()]
    .map(([sessionId, top]) => ({
      sessionId,
      date: (sessions.get(sessionId)?.startedAt ?? top.createdAt).slice(0, 10),
      weightG: top.weightG,
      reps: top.reps,
      e1rmG: epley1RM(top.weightG, top.reps),
    }))
    .sort((a, b) => a.date.localeCompare(b.date));

  const currentE1rmG = points.length ? points[points.length - 1].e1rmG : 0;
  const changeE1rmG = points.length ? currentE1rmG - points[0].e1rmG : 0;

  return { exerciseId, points, currentE1rmG, changeE1rmG };
}

export function getVolumeStats(db: DB, range: TrainingRange): VolumeByGroup {
  const sessions = sessionMap(db);
  const exercises = db
    .select({
      id: schema.exercises.id,
      muscleGroup: schema.exercises.muscleGroup,
    })
    .from(schema.exercises)
    .all() as { id: string; muscleGroup: string }[];
  const groupOf = new Map(exercises.map((e) => [e.id, e.muscleGroup]));

  const sets = db
    .select()
    .from(schema.setLogs)
    .where(
      and(eq(schema.setLogs.isWarmup, 0), eq(schema.setLogs.isDeleted, 0)),
    )
    .all() as SetRow[];

  const acc = new Map<string, { volumeG: number; sets: number }>();
  let total = 0;
  for (const s of sets) {
    const meta = sessions.get(s.sessionId);
    if (!meta) continue;
    if (!inRange(meta.startedAt, range)) continue;
    const group = groupOf.get(s.exerciseId) ?? "unknown";
    const vol = setVolumeG(s.weightG, s.reps);
    const cur = acc.get(group) ?? { volumeG: 0, sets: 0 };
    cur.volumeG += vol;
    cur.sets += 1;
    acc.set(group, cur);
    total += vol;
  }

  const byGroup: VolumeGroupStat[] = [...acc.entries()]
    .map(([muscleGroup, v]) => ({ muscleGroup, volumeG: v.volumeG, sets: v.sets }))
    .sort((a, b) => b.volumeG - a.volumeG);

  return {
    from: range.from ?? null,
    to: range.to ?? null,
    byGroup,
    totalVolumeG: total,
  };
}

export function listSessions(
  db: DB,
  range?: TrainingRange,
): SessionSummary[] {
  const routines = db
    .select({ id: schema.routines.id, name: schema.routines.name })
    .from(schema.routines)
    .all() as { id: string; name: string }[];
  const routineName = new Map(routines.map((r) => [r.id, r.name]));

  const sessions = db
    .select()
    .from(schema.workoutSessions)
    .where(eq(schema.workoutSessions.isDeleted, 0))
    .orderBy(desc(schema.workoutSessions.startedAt))
    .all() as WorkoutSession[];

  const result: SessionSummary[] = [];
  for (const s of sessions) {
    if (!inRange(s.startedAt, range)) continue;
    const sets = db
      .select()
      .from(schema.setLogs)
      .where(
        and(
          eq(schema.setLogs.sessionId, s.id),
          eq(schema.setLogs.isWarmup, 0),
          eq(schema.setLogs.isDeleted, 0),
        ),
      )
      .all() as SetRow[];
    const totalVolumeG = sets.reduce(
      (sum, x) => sum + setVolumeG(x.weightG, x.reps),
      0,
    );
    const durationS = s.endedAt
      ? Math.max(
          0,
          Math.round(
            (new Date(s.endedAt).getTime() -
              new Date(s.startedAt).getTime()) /
              1000,
          ),
        )
      : null;
    result.push({
      id: s.id,
      routineId: s.routineId,
      routineName: routineName.get(s.routineId) ?? "",
      sessionIndex: s.sessionIndex,
      startedAt: s.startedAt,
      endedAt: s.endedAt,
      durationS,
      totalSets: sets.length,
      totalVolumeG,
    });
  }
  return result;
}
