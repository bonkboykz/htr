import { eq } from "drizzle-orm";
import type { DB } from "../db/index.js";
import { schema } from "../db/index.js";

// ── Exercise catalog (SPEC §9) ──────────────────────────────────────────────
// minIncrementG: upper body 2500, lower body 5000, warmup/core/mobility 0.
// isSafeLowerBack: 1 for seated_row, rdl_db, shoulder_press.
// defaultRepMin/Max: compounds 8/12, isolation 12/15, core 8/12 (catalog defaults only).
const EXERCISES = [
  {
    id: "ex-cat_cow",
    name: "Cat-Cow",
    nameRu: "Кошка-корова",
    muscleGroup: "core",
    pattern: "core",
    equipment: JSON.stringify(["mat"]),
    isUnilateral: 0,
    isSafeLowerBack: 0,
    defaultRepMin: 8,
    defaultRepMax: 12,
    minIncrementG: 0,
    videoQuery: "cat cow pelvic tilt",
    cuesRu: "Плавно чередуй прогиб и округление спины, дыши в ритм.",
  },
  {
    id: "ex-hip_flexor_dyn",
    name: "Dynamic Hip Flexor Stretch",
    nameRu: "Динамическая растяжка сгибателей бедра",
    muscleGroup: "core",
    pattern: "isolation",
    equipment: JSON.stringify(["mat"]),
    isUnilateral: 0,
    isSafeLowerBack: 0,
    defaultRepMin: 12,
    defaultRepMax: 15,
    minIncrementG: 0,
    videoQuery: "dynamic hip flexor stretch lunge",
    cuesRu: "Выпад вперёд, таз подкручен, тянись передней стороной бедра вниз.",
  },
  {
    id: "ex-face_pull",
    name: "Cable Face Pull",
    nameRu: "Face pull на канате",
    muscleGroup: "shoulders",
    pattern: "h_pull",
    equipment: JSON.stringify(["cable", "rope"]),
    isUnilateral: 0,
    isSafeLowerBack: 0,
    defaultRepMin: 8,
    defaultRepMax: 12,
    minIncrementG: 2500,
    videoQuery: "cable face pull rear delt",
    cuesRu: "Тяни канат к лицу, разводя локти и сводя лопатки.",
  },
  {
    id: "ex-leg_press",
    name: "Leg Press",
    nameRu: "Жим ногами",
    muscleGroup: "quads",
    pattern: "squat",
    equipment: JSON.stringify(["leg_press"]),
    isUnilateral: 0,
    isSafeLowerBack: 0,
    defaultRepMin: 8,
    defaultRepMax: 12,
    minIncrementG: 5000,
    videoQuery: "leg press form foot placement",
    cuesRu: "Стопы на ширине таза, поясницу от спинки не отрывай.",
  },
  {
    id: "ex-bench_press",
    name: "Barbell Bench Press",
    nameRu: "Жим лёжа",
    muscleGroup: "chest",
    pattern: "h_press",
    equipment: JSON.stringify(["barbell", "bench"]),
    isUnilateral: 0,
    isSafeLowerBack: 0,
    defaultRepMin: 8,
    defaultRepMax: 12,
    minIncrementG: 2500,
    videoQuery: "dumbbell bench press form",
    cuesRu: "Лопатки сведены, штангу опускай к низу груди.",
  },
  {
    id: "ex-seated_row",
    name: "Seated Cable Row",
    nameRu: "Тяга в блоке сидя",
    muscleGroup: "back",
    pattern: "h_pull",
    equipment: JSON.stringify(["cable", "handle"]),
    isUnilateral: 0,
    isSafeLowerBack: 1,
    defaultRepMin: 8,
    defaultRepMax: 12,
    minIncrementG: 2500,
    videoQuery: "seated cable row form",
    cuesRu: "Спина прямая, тяни к животу, сводя лопатки.",
  },
  {
    id: "ex-leg_extension",
    name: "Leg Extension",
    nameRu: "Разгибания ног",
    muscleGroup: "quads",
    pattern: "isolation",
    equipment: JSON.stringify(["machine"]),
    isUnilateral: 0,
    isSafeLowerBack: 0,
    defaultRepMin: 12,
    defaultRepMax: 15,
    minIncrementG: 5000,
    videoQuery: "leg extension machine form",
    cuesRu: "Разгибай ногу полностью, без рывков и раскачки.",
  },
  {
    id: "ex-pec_deck",
    name: "Pec Deck Fly",
    nameRu: "Сведения в бабочке",
    muscleGroup: "chest",
    pattern: "isolation",
    equipment: JSON.stringify(["machine", "cable"]),
    isUnilateral: 0,
    isSafeLowerBack: 0,
    defaultRepMin: 12,
    defaultRepMax: 15,
    minIncrementG: 2500,
    videoQuery: "pec deck fly form",
    cuesRu: "Сводя руки, чувствуй грудь, движение плавное.",
  },
  {
    id: "ex-rdl_db",
    name: "Dumbbell Romanian Deadlift",
    nameRu: "Румынская тяга с гантелями",
    muscleGroup: "hamstrings",
    pattern: "hinge",
    equipment: JSON.stringify(["db"]),
    isUnilateral: 0,
    isSafeLowerBack: 1,
    defaultRepMin: 8,
    defaultRepMax: 12,
    minIncrementG: 5000,
    videoQuery: "dumbbell romanian deadlift form",
    cuesRu: "Таз назад, спина прямая, гантели скользят вдоль ног.",
  },
  {
    id: "ex-lat_pulldown",
    name: "Lat Pulldown",
    nameRu: "Тяга верхнего блока",
    muscleGroup: "back",
    pattern: "v_pull",
    equipment: JSON.stringify(["cable", "bar"]),
    isUnilateral: 0,
    isSafeLowerBack: 0,
    defaultRepMin: 8,
    defaultRepMax: 12,
    minIncrementG: 2500,
    videoQuery: "lat pulldown form",
    cuesRu: "Тяни к верху груди, локти вниз, лопатки опускай.",
  },
  {
    id: "ex-shoulder_press",
    name: "Machine Shoulder Press",
    nameRu: "Жим над головой сидя",
    muscleGroup: "shoulders",
    pattern: "v_press",
    equipment: JSON.stringify(["machine"]),
    isUnilateral: 0,
    isSafeLowerBack: 1,
    defaultRepMin: 8,
    defaultRepMax: 12,
    minIncrementG: 2500,
    videoQuery: "seated machine shoulder press",
    cuesRu: "Спина прижата к спинке, жми вверх без рывка.",
  },
  {
    id: "ex-leg_curl",
    name: "Leg Curl",
    nameRu: "Сгибания ног",
    muscleGroup: "hamstrings",
    pattern: "isolation",
    equipment: JSON.stringify(["machine"]),
    isUnilateral: 0,
    isSafeLowerBack: 0,
    defaultRepMin: 12,
    defaultRepMax: 15,
    minIncrementG: 5000,
    videoQuery: "leg curl machine form",
    cuesRu: "Контролируй негатив, без рывков корпусом.",
  },
  {
    id: "ex-bicep_curl",
    name: "Bicep Curl",
    nameRu: "Сгибания на бицепс",
    muscleGroup: "arms",
    pattern: "isolation",
    equipment: JSON.stringify(["machine"]),
    isUnilateral: 0,
    isSafeLowerBack: 0,
    defaultRepMin: 12,
    defaultRepMax: 15,
    minIncrementG: 2500,
    videoQuery: "bicep curl form",
    cuesRu: "Локти прижаты к корпусу, без раскачки.",
  },
  {
    id: "ex-tricep_pushdown",
    name: "Tricep Pushdown",
    nameRu: "Разгибания на трицепс",
    muscleGroup: "arms",
    pattern: "isolation",
    equipment: JSON.stringify(["cable", "rope"]),
    isUnilateral: 0,
    isSafeLowerBack: 0,
    defaultRepMin: 12,
    defaultRepMax: 15,
    minIncrementG: 2500,
    videoQuery: "tricep pushdown form",
    cuesRu: "Локти прижаты, разгибай руки полностью.",
  },
  {
    id: "ex-hip_thrust",
    name: "Hip Thrust",
    nameRu: "Ягодичный мост",
    muscleGroup: "glutes",
    pattern: "hinge",
    equipment: JSON.stringify(["bench", "sandbag"]),
    isUnilateral: 0,
    isSafeLowerBack: 0,
    defaultRepMin: 8,
    defaultRepMax: 12,
    minIncrementG: 5000,
    videoQuery: "hip thrust glutes form",
    cuesRu: "Подбородок к груди, толчок пятками, сжимай ягодицы вверху.",
  },
  {
    id: "ex-dead_bug",
    name: "Dead Bug",
    nameRu: "Мёртвый жук",
    muscleGroup: "core",
    pattern: "core",
    equipment: JSON.stringify(["mat"]),
    isUnilateral: 0,
    isSafeLowerBack: 0,
    defaultRepMin: 8,
    defaultRepMax: 12,
    minIncrementG: 0,
    videoQuery: "dead bug core",
    cuesRu: "Поясница прижата к полу, тянись противоположными рукой и ногой.",
  },
  {
    id: "ex-plank",
    name: "Forearm Plank",
    nameRu: "Планка",
    muscleGroup: "core",
    pattern: "core",
    equipment: JSON.stringify(["mat"]),
    isUnilateral: 0,
    isSafeLowerBack: 0,
    defaultRepMin: 8,
    defaultRepMax: 12,
    minIncrementG: 0,
    videoQuery: "forearm plank form",
    cuesRu: "Тело в одну линию, таз не проваливай и не задирай.",
  },
  {
    id: "ex-bird_dog",
    name: "Bird Dog",
    nameRu: "Птица-собака",
    muscleGroup: "core",
    pattern: "core",
    equipment: JSON.stringify(["mat"]),
    isUnilateral: 0,
    isSafeLowerBack: 0,
    defaultRepMin: 8,
    defaultRepMax: 12,
    minIncrementG: 0,
    videoQuery: "bird dog core stability",
    cuesRu: "Вытягивай руку и противоположную ногу в линию, таз стабилен.",
  },
] as const;

// ── Routines (SPEC §9) ──────────────────────────────────────────────────────
const ROUTINES = [
  {
    id: "routine-a",
    name: "Workout A",
    nameRu: "Тренировка A",
    notes: "ноги-перёд · грудь · тяга · кор",
    sortOrder: 1,
  },
  {
    id: "routine-b",
    name: "Workout B",
    nameRu: "Тренировка B",
    notes: "ноги-зад · спина · плечи · ягодицы",
    sortOrder: 2,
  },
] as const;

// ── Routine composition (SPEC §9) ───────────────────────────────────────────
// targetRir: main = 2 (rir1–2), warmup/reab = 3.
// isRampupScaled: 1 for main section rows, 0 otherwise.
const ROUTINE_EXERCISES = [
  // ─── Workout A ───
  // warmup
  { id: "re-a-01", routineId: "routine-a", exerciseId: "ex-cat_cow", section: "warmup", sortOrder: 1, targetSets: 1, repMin: 8, repMax: 10, targetRir: 3, isRampupScaled: 0, notes: null },
  { id: "re-a-02", routineId: "routine-a", exerciseId: "ex-hip_flexor_dyn", section: "warmup", sortOrder: 2, targetSets: 1, repMin: 8, repMax: 8, targetRir: 3, isRampupScaled: 0, notes: null },
  { id: "re-a-03", routineId: "routine-a", exerciseId: "ex-face_pull", section: "warmup", sortOrder: 3, targetSets: 2, repMin: 15, repMax: 15, targetRir: 3, isRampupScaled: 0, notes: null },
  // main
  { id: "re-a-04", routineId: "routine-a", exerciseId: "ex-leg_press", section: "main", sortOrder: 4, targetSets: 3, repMin: 10, repMax: 12, targetRir: 2, isRampupScaled: 1, notes: null },
  { id: "re-a-05", routineId: "routine-a", exerciseId: "ex-bench_press", section: "main", sortOrder: 5, targetSets: 3, repMin: 8, repMax: 10, targetRir: 2, isRampupScaled: 1, notes: null },
  { id: "re-a-06", routineId: "routine-a", exerciseId: "ex-seated_row", section: "main", sortOrder: 6, targetSets: 3, repMin: 10, repMax: 12, targetRir: 2, isRampupScaled: 1, notes: null },
  { id: "re-a-07", routineId: "routine-a", exerciseId: "ex-leg_extension", section: "main", sortOrder: 7, targetSets: 2, repMin: 12, repMax: 15, targetRir: 2, isRampupScaled: 1, notes: null },
  { id: "re-a-08", routineId: "routine-a", exerciseId: "ex-pec_deck", section: "main", sortOrder: 8, targetSets: 2, repMin: 12, repMax: 15, targetRir: 2, isRampupScaled: 1, notes: null },
  // reab
  { id: "re-a-09", routineId: "routine-a", exerciseId: "ex-dead_bug", section: "reab", sortOrder: 9, targetSets: 3, repMin: 8, repMax: 8, targetRir: 3, isRampupScaled: 0, notes: null },
  { id: "re-a-10", routineId: "routine-a", exerciseId: "ex-plank", section: "reab", sortOrder: 10, targetSets: 3, repMin: 30, repMax: 45, targetRir: 3, isRampupScaled: 0, notes: "секунды удержания" },
  { id: "re-a-11", routineId: "routine-a", exerciseId: "ex-hip_flexor_dyn", section: "reab", sortOrder: 11, targetSets: 2, repMin: 30, repMax: 30, targetRir: 3, isRampupScaled: 0, notes: "секунды на сторону" },

  // ─── Workout B ───
  // warmup
  { id: "re-b-01", routineId: "routine-b", exerciseId: "ex-cat_cow", section: "warmup", sortOrder: 1, targetSets: 1, repMin: 8, repMax: 10, targetRir: 3, isRampupScaled: 0, notes: null },
  { id: "re-b-02", routineId: "routine-b", exerciseId: "ex-hip_flexor_dyn", section: "warmup", sortOrder: 2, targetSets: 1, repMin: 8, repMax: 8, targetRir: 3, isRampupScaled: 0, notes: null },
  { id: "re-b-03", routineId: "routine-b", exerciseId: "ex-face_pull", section: "warmup", sortOrder: 3, targetSets: 2, repMin: 15, repMax: 15, targetRir: 3, isRampupScaled: 0, notes: null },
  { id: "re-b-04", routineId: "routine-b", exerciseId: "ex-hip_thrust", section: "warmup", sortOrder: 4, targetSets: 1, repMin: 12, repMax: 12, targetRir: 3, isRampupScaled: 0, notes: "с собственным весом" },
  // main
  { id: "re-b-05", routineId: "routine-b", exerciseId: "ex-rdl_db", section: "main", sortOrder: 5, targetSets: 3, repMin: 10, repMax: 12, targetRir: 2, isRampupScaled: 1, notes: null },
  { id: "re-b-06", routineId: "routine-b", exerciseId: "ex-lat_pulldown", section: "main", sortOrder: 6, targetSets: 3, repMin: 8, repMax: 10, targetRir: 2, isRampupScaled: 1, notes: null },
  { id: "re-b-07", routineId: "routine-b", exerciseId: "ex-shoulder_press", section: "main", sortOrder: 7, targetSets: 3, repMin: 10, repMax: 12, targetRir: 2, isRampupScaled: 1, notes: null },
  { id: "re-b-08", routineId: "routine-b", exerciseId: "ex-leg_curl", section: "main", sortOrder: 8, targetSets: 3, repMin: 12, repMax: 15, targetRir: 2, isRampupScaled: 1, notes: null },
  { id: "re-b-09", routineId: "routine-b", exerciseId: "ex-bicep_curl", section: "main", sortOrder: 9, targetSets: 2, repMin: 10, repMax: 12, targetRir: 2, isRampupScaled: 1, notes: null },
  { id: "re-b-10", routineId: "routine-b", exerciseId: "ex-tricep_pushdown", section: "main", sortOrder: 10, targetSets: 2, repMin: 10, repMax: 12, targetRir: 2, isRampupScaled: 1, notes: null },
  // reab
  { id: "re-b-11", routineId: "routine-b", exerciseId: "ex-hip_thrust", section: "reab", sortOrder: 11, targetSets: 3, repMin: 12, repMax: 15, targetRir: 3, isRampupScaled: 0, notes: "с песочным мешком" },
  { id: "re-b-12", routineId: "routine-b", exerciseId: "ex-bird_dog", section: "reab", sortOrder: 12, targetSets: 3, repMin: 8, repMax: 8, targetRir: 3, isRampupScaled: 0, notes: "на сторону" },
  { id: "re-b-13", routineId: "routine-b", exerciseId: "ex-hip_flexor_dyn", section: "reab", sortOrder: 13, targetSets: 2, repMin: 30, repMax: 30, targetRir: 3, isRampupScaled: 0, notes: "секунды на сторону" },
] as const;

/**
 * Seed the training domain (exercises, routines, routine composition).
 * Idempotent: every row is checked by primary-key id and inserted only if
 * missing, so re-running produces no duplicates.
 */
export function seedTraining(db: DB): void {
  for (const exercise of EXERCISES) {
    const existing = db
      .select()
      .from(schema.exercises)
      .where(eq(schema.exercises.id, exercise.id))
      .get();
    if (!existing) {
      db.insert(schema.exercises).values(exercise).run();
    }
  }

  for (const routine of ROUTINES) {
    const existing = db
      .select()
      .from(schema.routines)
      .where(eq(schema.routines.id, routine.id))
      .get();
    if (!existing) {
      db.insert(schema.routines).values(routine).run();
    }
  }

  for (const re of ROUTINE_EXERCISES) {
    const existing = db
      .select()
      .from(schema.routineExercises)
      .where(eq(schema.routineExercises.id, re.id))
      .get();
    if (!existing) {
      db.insert(schema.routineExercises).values(re).run();
    }
  }
}
