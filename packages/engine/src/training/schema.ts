import { sqliteTable, text, integer, index } from "drizzle-orm/sqlite-core";

// Catalog of exercises. equipment is a JSON array stored as text, e.g. '["barbell","bench"]'.
export const exercises = sqliteTable("exercises", {
  id: text("id").primaryKey(),
  name: text("name").notNull(),
  nameRu: text("name_ru").notNull(),
  muscleGroup: text("muscle_group").notNull(),
  pattern: text("pattern").notNull(),
  equipment: text("equipment").notNull(), // JSON array: '["cable","rope"]'
  isUnilateral: integer("is_unilateral").notNull().default(0),
  isSafeLowerBack: integer("is_safe_lower_back").notNull().default(0),
  defaultRepMin: integer("default_rep_min").notNull(),
  defaultRepMax: integer("default_rep_max").notNull(),
  minIncrementG: integer("min_increment_g").notNull(), // 2500 upper body, 5000 lower body, 0 = no progression
  videoQuery: text("video_query"),
  cuesRu: text("cues_ru"),
  isDeleted: integer("is_deleted").notNull().default(0),
  createdAt: text("created_at")
    .notNull()
    .$defaultFn(() => new Date().toISOString()),
});

// Workout templates (A / B / ...).
export const routines = sqliteTable("routines", {
  id: text("id").primaryKey(),
  name: text("name").notNull(),
  nameRu: text("name_ru").notNull(),
  notes: text("notes"),
  sortOrder: integer("sort_order").notNull(),
  isDeleted: integer("is_deleted").notNull().default(0),
  createdAt: text("created_at")
    .notNull()
    .$defaultFn(() => new Date().toISOString()),
});

// Composition of a template (positions within warmup / main / reab sections).
export const routineExercises = sqliteTable(
  "routine_exercises",
  {
    id: text("id").primaryKey(),
    routineId: text("routine_id").notNull(),
    exerciseId: text("exercise_id").notNull(),
    section: text("section").notNull(), // warmup | main | reab
    sortOrder: integer("sort_order").notNull(),
    targetSets: integer("target_sets").notNull(),
    repMin: integer("rep_min").notNull(),
    repMax: integer("rep_max").notNull(),
    targetRir: integer("target_rir").notNull(),
    isRampupScaled: integer("is_rampup_scaled").notNull().default(0),
    notes: text("notes"),
    isDeleted: integer("is_deleted").notNull().default(0),
  },
  (t) => [
    index("routine_exercises_routine_section_sort_idx").on(
      t.routineId,
      t.section,
      t.sortOrder,
    ),
  ],
);

// A performed workout. duration = ended_at - started_at (not stored).
export const workoutSessions = sqliteTable(
  "workout_sessions",
  {
    id: text("id").primaryKey(),
    routineId: text("routine_id").notNull(),
    sessionIndex: integer("session_index").notNull(), // 1..10, resets each block; drives ramp-up/UI
    startedAt: text("started_at").notNull(),
    endedAt: text("ended_at"), // null = in progress
    notes: text("notes"),
    isDeleted: integer("is_deleted").notNull().default(0),
  },
  (t) => [
    index("workout_sessions_routine_started_idx").on(
      t.routineId,
      t.startedAt,
    ),
  ],
);

// Core of progression: individual sets.
export const setLogs = sqliteTable(
  "set_logs",
  {
    id: text("id").primaryKey(),
    sessionId: text("session_id").notNull(),
    exerciseId: text("exercise_id").notNull(), // duplicated for fast per-exercise history
    setNumber: integer("set_number").notNull(),
    weightG: integer("weight_g").notNull(), // grams
    reps: integer("reps").notNull(),
    rir: integer("rir"), // nullable for warmups
    isWarmup: integer("is_warmup").notNull().default(0),
    isDeleted: integer("is_deleted").notNull().default(0),
    createdAt: text("created_at")
      .notNull()
      .$defaultFn(() => new Date().toISOString()),
  },
  (t) => [
    index("set_logs_exercise_created_idx").on(t.exerciseId, t.createdAt),
  ],
);
