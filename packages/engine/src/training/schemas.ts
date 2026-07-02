import { z } from "zod";

export const SectionEnum = z.enum(["warmup", "main", "reab"]);
export const PatternEnum = z.enum([
  "squat",
  "hinge",
  "h_press",
  "v_press",
  "h_pull",
  "v_pull",
  "core",
  "isolation",
]);

export const LogSetInput = z.object({
  exercise_id: z.string(),
  set_number: z.number().int().positive(),
  weight_g: z.number().int().nonnegative(), // grams
  reps: z.number().int().nonnegative(),
  rir: z.number().int().min(0).max(5).nullable().optional(),
  duration_s: z.number().int().nonnegative().nullable().optional(), // seconds for static/timed work
  is_warmup: z.boolean().default(false),
});

// Edit an already-logged set (history correction).
export const UpdateSetInput = z.object({
  weight_g: z.number().int().nonnegative().optional(),
  reps: z.number().int().nonnegative().optional(),
  rir: z.number().int().min(0).max(5).nullable().optional(),
  duration_s: z.number().int().nonnegative().nullable().optional(),
});

export const StartSessionInput = z.object({
  routine_id: z.string(),
  session_index: z.number().int().min(1).optional(), // derived if omitted
  started_at: z.string().datetime().optional(), // ISO 8601, backdating; default = now
});

export const EndSessionInput = z.object({
  started_at: z.string().datetime().optional(), // ISO 8601, corrects/backdates the start
  ended_at: z.string().datetime().optional(), // default = now
  notes: z.string().max(2000).optional(),
});

// AI/chat overrides the engine's suggested weight (see progression §5).
export const OverrideProgressionInput = z.object({
  exercise_id: z.string(),
  weight_g: z.number().int().nonnegative(),
  reason: z.string().max(500), // why the AI overrode
});

export const PatchRoutineExerciseInput = z.object({
  exercise_id: z.string().optional(), // swap exercise
  section: SectionEnum.optional(), // move to another section
  sort_order: z.number().int().optional(), // reorder
  target_sets: z.number().int().positive().optional(),
  rep_min: z.number().int().positive().optional(),
  rep_max: z.number().int().positive().optional(),
  target_rir: z.number().int().min(0).max(5).optional(),
  is_rampup_scaled: z.boolean().optional(),
  notes: z.string().optional(),
});

// ---------- CRUD authoring (build/edit programs) ----------

export const CreateExerciseInput = z.object({
  name: z.string().min(1),
  name_ru: z.string().min(1),
  muscle_group: z.string().min(1),
  pattern: PatternEnum,
  equipment: z.array(z.string()).default([]),
  is_unilateral: z.boolean().default(false),
  is_safe_lower_back: z.boolean().default(false),
  default_rep_min: z.number().int().positive().default(8),
  default_rep_max: z.number().int().positive().default(12),
  min_increment_g: z.number().int().nonnegative().default(2500),
  video_query: z.string().optional(),
  cues_ru: z.string().optional(),
});

export const UpdateExerciseInput = z.object({
  name: z.string().min(1).optional(),
  name_ru: z.string().min(1).optional(),
  muscle_group: z.string().min(1).optional(),
  pattern: PatternEnum.optional(),
  equipment: z.array(z.string()).optional(),
  is_unilateral: z.boolean().optional(),
  is_safe_lower_back: z.boolean().optional(),
  default_rep_min: z.number().int().positive().optional(),
  default_rep_max: z.number().int().positive().optional(),
  min_increment_g: z.number().int().nonnegative().optional(),
  video_query: z.string().optional(),
  cues_ru: z.string().optional(),
});

export const CreateRoutineInput = z.object({
  name: z.string().min(1),
  name_ru: z.string().min(1),
  notes: z.string().optional(),
  sort_order: z.number().int().optional(),
});

export const UpdateRoutineInput = z.object({
  name: z.string().min(1).optional(),
  name_ru: z.string().min(1).optional(),
  notes: z.string().optional(),
  sort_order: z.number().int().optional(),
});

export const AddRoutineExerciseInput = z.object({
  exercise_id: z.string(),
  section: SectionEnum,
  sort_order: z.number().int().optional(), // appended if omitted
  target_sets: z.number().int().positive(),
  rep_min: z.number().int().positive(),
  rep_max: z.number().int().positive(),
  target_rir: z.number().int().min(0).max(5).default(2),
  is_rampup_scaled: z.boolean().optional(),
  notes: z.string().optional(),
});

// Record a one-off substitution/override on a session (v2).
export const RecordOverrideInput = z.object({
  routine_exercise_id: z.string(),
  replaced_exercise_id: z.string(),
  reason: z.string().max(500).optional(),
});

export type Section = z.infer<typeof SectionEnum>;
export type Pattern = z.infer<typeof PatternEnum>;
export type LogSetInputT = z.infer<typeof LogSetInput>;
export type UpdateSetInputT = z.infer<typeof UpdateSetInput>;
export type StartSessionInputT = z.infer<typeof StartSessionInput>;
export type EndSessionInputT = z.infer<typeof EndSessionInput>;
export type OverrideProgressionInputT = z.infer<typeof OverrideProgressionInput>;
export type PatchRoutineExerciseInputT = z.infer<
  typeof PatchRoutineExerciseInput
>;
export type CreateExerciseInputT = z.infer<typeof CreateExerciseInput>;
export type UpdateExerciseInputT = z.infer<typeof UpdateExerciseInput>;
export type CreateRoutineInputT = z.infer<typeof CreateRoutineInput>;
export type UpdateRoutineInputT = z.infer<typeof UpdateRoutineInput>;
export type AddRoutineExerciseInputT = z.infer<typeof AddRoutineExerciseInput>;
export type RecordOverrideInputT = z.infer<typeof RecordOverrideInput>;
