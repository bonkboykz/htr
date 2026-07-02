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
  is_warmup: z.boolean().default(false),
});

export const StartSessionInput = z.object({
  routine_id: z.string(),
  session_index: z.number().int().min(1).optional(), // derived if omitted
});

export const EndSessionInput = z.object({
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
  target_sets: z.number().int().positive().optional(),
  rep_min: z.number().int().positive().optional(),
  rep_max: z.number().int().positive().optional(),
  target_rir: z.number().int().min(0).max(5).optional(),
  notes: z.string().optional(),
});

export type Section = z.infer<typeof SectionEnum>;
export type Pattern = z.infer<typeof PatternEnum>;
export type LogSetInputT = z.infer<typeof LogSetInput>;
export type StartSessionInputT = z.infer<typeof StartSessionInput>;
export type EndSessionInputT = z.infer<typeof EndSessionInput>;
export type OverrideProgressionInputT = z.infer<typeof OverrideProgressionInput>;
export type PatchRoutineExerciseInputT = z.infer<
  typeof PatchRoutineExerciseInput
>;
