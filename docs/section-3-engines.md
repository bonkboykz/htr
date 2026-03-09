# Секция 3: Engine Functions & Algorithms

## Промпт для Claude Code

```
Read docs/section-1-spec.md, docs/section-2-schema.md, and docs/section-3-engines.md.

Implement all engines and formatting in packages/engine.

1. Create packages/engine/src/format/index.ts — ALL formatting functions from spec
2. Create packages/engine/src/nutrition/engine.ts — logFood, getDailyNutrition, quickLog
3. Create packages/engine/src/weight/engine.ts — logWeight, getLatestWeight, getWeightTrend
4. Create packages/engine/src/water/engine.ts — logWater, getDailyWater
5. Create packages/engine/src/sleep/engine.ts — logSleep, getSleepForDate, getSleepTrend
6. Create packages/engine/src/stats/engine.ts — getWeekSummary, getStreaks, getRangeStats
7. Create packages/engine/src/targets/engine.ts — getActiveTarget, setTarget
8. Update packages/engine/src/index.ts — re-export everything

9. Write packages/engine/tests/format.test.ts
10. Write packages/engine/tests/nutrition.test.ts
11. Write packages/engine/tests/weight.test.ts
12. Write packages/engine/tests/water.test.ts
13. Write packages/engine/tests/sleep.test.ts
14. Write packages/engine/tests/stats.test.ts

15. Create packages/engine/vitest.config.ts:
    import { defineConfig } from 'vitest/config';
    export default defineConfig({ test: { globals: true } });

Run `pnpm test` from packages/engine, fix ALL failures.
```

---

## Types

Все интерфейсы определяются рядом с engine-функциями или в отдельном types.ts:

```typescript
// ═══════════════════════════════════════
// Food / Nutrition
// ═══════════════════════════════════════

interface FoodLogEntry {
  id: string;
  date: string;
  mealId: string;
  foodItemId: string;
  foodName: string;          // denormalized for display
  servingGrams: number;
  calories: number;          // kcal
  protein: number;           // tenths of grams
  fat: number;               // tenths of grams
  carbs: number;             // tenths of grams
  fiber: number;             // tenths of grams
}

interface DailyNutrition {
  date: string;
  meals: {
    meal: { id: string; name: string; sortOrder: number };
    entries: FoodLogEntry[];
    subtotals: {
      calories: number;
      protein: number;
      fat: number;
      carbs: number;
      fiber: number;
    };
  }[];
  totals: {
    calories: number;
    protein: number;
    fat: number;
    carbs: number;
    fiber: number;
  };
  target: DailyTarget | null;
}

// ═══════════════════════════════════════
// Weight
// ═══════════════════════════════════════

interface WeightLogEntry {
  id: string;
  date: string;
  weightGrams: number;
  bodyFat: number | null;    // permille
  note: string | null;
}

interface WeightTrend {
  entries: WeightLogEntry[];
  trendGrams: number;        // EMA smoothed current weight
  changeGrams: number;       // vs first entry in period
}

// ═══════════════════════════════════════
// Water
// ═══════════════════════════════════════

interface WaterLogEntry {
  id: string;
  date: string;
  amountMl: number;
}

interface DailyWater {
  totalMl: number;
  targetMl: number;
  entries: WaterLogEntry[];
}

// ═══════════════════════════════════════
// Sleep
// ═══════════════════════════════════════

interface SleepLogEntry {
  id: string;
  startTime: string;         // ISO 8601
  endTime: string;           // ISO 8601
  durationMinutes: number;   // computed
  quality: number | null;    // 1-5
  note: string | null;
}

interface SleepTrend {
  entries: SleepLogEntry[];
  avgMinutes: number;
  avgQuality: number | null;
}

// ═══════════════════════════════════════
// Daily Summary (assembled in API route)
// ═══════════════════════════════════════

interface DailySummary {
  date: string;
  nutrition: DailyNutrition;
  water: { totalMl: number; targetMl: number };
  sleep: { totalMinutes: number; targetMinutes: number; quality: number | null };
  weight: WeightLogEntry | null;
}

// ═══════════════════════════════════════
// Stats
// ═══════════════════════════════════════

interface WeekSummary {
  weekStart: string;          // Monday YYYY-MM-DD
  avgCalories: number;
  avgProtein: number;
  avgFat: number;
  avgCarbs: number;
  avgWaterMl: number;
  avgSleepMinutes: number;
  daysLogged: number;
}

interface Streaks {
  foodLogging: { current: number; best: number };
  waterGoal: { current: number; best: number };
  sleepGoal: { current: number; best: number };
}

interface RangeStats {
  from: string;
  to: string;
  daysLogged: number;
  avgCalories: number;
  avgProtein: number;
  avgFat: number;
  avgCarbs: number;
  totalWaterMl: number;
  avgWaterMl: number;
  avgSleepMinutes: number;
}

// ═══════════════════════════════════════
// Targets
// ═══════════════════════════════════════

interface DailyTarget {
  id: string;
  effectiveDate: string;
  calories: number;
  protein: number;
  fat: number;
  carbs: number;
  waterMl: number;
  sleepMinutes: number;
}
```

---

## Formatting: packages/engine/src/format/index.ts

```typescript
/**
 * Format calories: 2150 → "2 150 kcal"
 */
export function formatCalories(kcal: number): string {
  return `${kcal.toLocaleString('ru-RU')} kcal`;
}

/**
 * Format macro (stored as tenths of grams): 253 → "25.3 g"
 */
export function formatMacro(tenths: number): string {
  const grams = tenths / 10;
  return `${grams.toFixed(1)} g`;
}

/**
 * Format weight (stored as grams): 75500 → "75.5 kg"
 */
export function formatWeight(grams: number): string {
  const kg = grams / 1000;
  return `${kg.toFixed(1)} kg`;
}

/**
 * Format water (stored as ml): 250 → "250 ml", 2100 → "2.1 L"
 */
export function formatWater(ml: number): string {
  if (ml >= 1000) {
    return `${(ml / 1000).toFixed(1)} L`;
  }
  return `${ml} ml`;
}

/**
 * Format sleep (stored as minutes): 465 → "7h 45m"
 */
export function formatSleep(minutes: number): string {
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  if (h === 0) return `${m}m`;
  if (m === 0) return `${h}h`;
  return `${h}h ${m}m`;
}

/**
 * Format body fat (stored as permille): 152 → "15.2%"
 */
export function formatBodyFat(permille: number): string {
  return `${(permille / 10).toFixed(1)}%`;
}

/**
 * Progress percentage: formatProgress(1500, 2150) → 70
 * Capped at 100 for display purposes, but can exceed for "over target"
 */
export function formatProgress(current: number, target: number): number {
  if (target === 0) return 0;
  return Math.round((current / target) * 100);
}
```

---

## Nutrition Engine: packages/engine/src/nutrition/engine.ts

Каждая функция принимает `db: DB` первым аргументом.

### logFood(db, data) → FoodLogEntry

**Алгоритм:**
1. Найти food_item по `foodItemId` (проверить `is_deleted = false`)
2. Вычислить КБЖУ: `Math.round(nutrient_per_100g * servingGrams / 100)`
3. Вставить в `food_logs` с pre-computed значениями
4. Вернуть запись с `foodName` из food_item

```typescript
export function logFood(db: DB, data: {
  date: string;
  mealId: string;
  foodItemId: string;
  servingGrams: number;
}): FoodLogEntry {
  // 1. Find food item
  const foodItem = db.select().from(schema.foodItems)
    .where(and(eq(schema.foodItems.id, data.foodItemId), eq(schema.foodItems.isDeleted, false)))
    .get();
  if (!foodItem) throw new Error(`Food item '${data.foodItemId}' not found`);

  // 2. Pre-compute macros
  const calories = Math.round(foodItem.caloriesPer100g * data.servingGrams / 100);
  const protein  = Math.round(foodItem.proteinPer100g  * data.servingGrams / 100);
  const fat      = Math.round(foodItem.fatPer100g      * data.servingGrams / 100);
  const carbs    = Math.round(foodItem.carbsPer100g    * data.servingGrams / 100);
  const fiber    = Math.round(foodItem.fiberPer100g    * data.servingGrams / 100);

  // 3. Insert
  const id = createId();
  db.insert(schema.foodLogs).values({
    id, date: data.date, mealId: data.mealId, foodItemId: data.foodItemId,
    servingGrams: data.servingGrams,
    calories, protein, fat, carbs, fiber,
  }).run();

  // 4. Return
  return { id, ...data, foodName: foodItem.name, calories, protein, fat, carbs, fiber };
}
```

### getDailyNutrition(db, date) → DailyNutrition

**Алгоритм:**
1. Загрузить все meals (отсортированные по `sort_order`)
2. Загрузить food_logs за дату (не deleted) с JOIN на food_items для имени
3. Сгруппировать по meal_id
4. Вычислить subtotals для каждого meal
5. Вычислить общие totals
6. Загрузить активный target (через `getActiveTarget`)
7. Собрать `DailyNutrition`

```sql
-- Step 2: food logs for date
SELECT fl.*, fi.name as food_name
FROM food_logs fl
JOIN food_items fi ON fi.id = fl.food_item_id
WHERE fl.date = :date AND fl.is_deleted = 0
ORDER BY fl.created_at
```

### quickLog(db, data) → FoodLogEntry

**Алгоритм:**
1. Автоматически создать food_item с переданными данными:
   - `name` из data
   - `caloriesPer100g = data.calories` (трактуем как per-serving)
   - `proteinPer100g = data.protein ?? 0`
   - `fatPer100g = data.fat ?? 0`
   - `carbsPer100g = data.carbs ?? 0`
   - `servingSizeG = 100` (по умолчанию)
2. Создать food_log с `servingGrams = 100`, чтобы pre-computed = raw values
3. Вернуть FoodLogEntry

```typescript
export function quickLog(db: DB, data: {
  date: string;
  mealId: string;
  name: string;
  calories: number;
  protein?: number;
  fat?: number;
  carbs?: number;
}): FoodLogEntry {
  // Auto-create food item (values are "per 100g" = "per serving")
  const foodItemId = createId();
  db.insert(schema.foodItems).values({
    id: foodItemId,
    name: data.name,
    caloriesPer100g: data.calories,
    proteinPer100g: data.protein ?? 0,
    fatPer100g: data.fat ?? 0,
    carbsPer100g: data.carbs ?? 0,
    servingSizeG: 100,
  }).run();

  // Log with 100g serving (1:1 mapping)
  return logFood(db, {
    date: data.date,
    mealId: data.mealId,
    foodItemId,
    servingGrams: 100,
  });
}
```

---

## Weight Engine: packages/engine/src/weight/engine.ts

### logWeight(db, data) → WeightLogEntry

**Алгоритм:**
1. Проверить, есть ли запись за эту дату (upsert)
2. Если есть — UPDATE weight_grams, body_fat, note
3. Если нет — INSERT
4. Вернуть запись

```typescript
export function logWeight(db: DB, data: {
  date: string;
  weightGrams: number;
  bodyFat?: number;
  note?: string;
}): WeightLogEntry { ... }
```

### getLatestWeight(db) → WeightLogEntry | null

```sql
SELECT * FROM weight_logs
WHERE is_deleted = 0
ORDER BY date DESC
LIMIT 1
```

### getWeightTrend(db, days) → WeightTrend

**Алгоритм EMA (Exponential Moving Average):**

1. Загрузить weight_logs за последние `days` дней, сортировка по date ASC
2. Если пусто — вернуть пустой тренд
3. Рассчитать EMA с alpha = 0.1:
   ```
   EMA_0 = первое_значение
   EMA_i = alpha * value_i + (1 - alpha) * EMA_{i-1}
   ```
4. `trendGrams` = последний EMA
5. `changeGrams` = последний EMA - первый вес

```typescript
export function getWeightTrend(db: DB, days: number = 30): WeightTrend {
  const since = /* today - days */;
  const entries = db.select().from(schema.weightLogs)
    .where(and(
      gte(schema.weightLogs.date, since),
      eq(schema.weightLogs.isDeleted, false)
    ))
    .orderBy(asc(schema.weightLogs.date))
    .all();

  if (entries.length === 0) {
    return { entries: [], trendGrams: 0, changeGrams: 0 };
  }

  // EMA calculation
  const alpha = 0.1;
  let ema = entries[0].weightGrams;
  for (let i = 1; i < entries.length; i++) {
    ema = alpha * entries[i].weightGrams + (1 - alpha) * ema;
  }

  return {
    entries,
    trendGrams: Math.round(ema),
    changeGrams: Math.round(ema) - entries[0].weightGrams,
  };
}
```

---

## Water Engine: packages/engine/src/water/engine.ts

### logWater(db, data) → WaterLogEntry

Простой INSERT. Каждый стакан — отдельная запись.

```typescript
export function logWater(db: DB, data: { date: string; amountMl: number }): WaterLogEntry {
  const id = createId();
  db.insert(schema.waterLogs).values({ id, ...data }).run();
  return { id, ...data };
}
```

### getDailyWater(db, date) → DailyWater

**Алгоритм:**
1. Загрузить все water_logs за дату (not deleted)
2. Вычислить `totalMl = SUM(amount_ml)`
3. Загрузить target через `getActiveTarget` → `waterMl`
4. Вернуть `{ totalMl, targetMl, entries }`

```sql
SELECT * FROM water_logs
WHERE date = :date AND is_deleted = 0
ORDER BY created_at
```

---

## Sleep Engine: packages/engine/src/sleep/engine.ts

### logSleep(db, data) → SleepLogEntry

**Алгоритм:**
1. Валидация: `endTime > startTime`
2. Вычислить `durationMinutes`:
   ```typescript
   const duration = (new Date(endTime).getTime() - new Date(startTime).getTime()) / 60000;
   ```
3. INSERT в sleep_logs
4. Вернуть запись с computed durationMinutes

### getSleepForDate(db, date) → SleepLogEntry[]

**Обработка перехода через полночь:**

Сон "за дату" — это сон, который **закончился** в эту дату. Например, лёг 2026-03-08 23:00, встал 2026-03-09 07:00 → это сон за 2026-03-09.

```sql
SELECT * FROM sleep_logs
WHERE date(end_time) = :date AND is_deleted = 0
ORDER BY start_time
```

Альтернативный подход — привязка по дате начала сна (если до 6:00 утра — считать за предыдущий день):

```typescript
function getSleepDate(startTime: string): string {
  const d = new Date(startTime);
  const hours = d.getHours();
  // Сон начатый до 6:00 — это "вчерашний" сон
  if (hours < 6) {
    d.setDate(d.getDate() - 1);
  }
  return d.toISOString().split('T')[0];
}
```

### getSleepTrend(db, days) → SleepTrend

**Алгоритм:**
1. Загрузить sleep_logs за последние `days` дней
2. Вычислить `avgMinutes = SUM(duration) / count`
3. Вычислить `avgQuality` (nullable, только по записям с quality)

---

## Stats Engine: packages/engine/src/stats/engine.ts

### getWeekSummary(db, date) → WeekSummary

**Алгоритм:**
1. Определить Monday текущей ISO-недели:
   ```typescript
   function getMonday(dateStr: string): string {
     const d = new Date(dateStr);
     const day = d.getDay();
     const diff = d.getDate() - day + (day === 0 ? -6 : 1);
     d.setDate(diff);
     return d.toISOString().split('T')[0];
   }
   ```
2. Определить Sunday = Monday + 6
3. Загрузить nutrition: `SELECT date, SUM(calories), SUM(protein), SUM(fat), SUM(carbs) FROM food_logs WHERE date BETWEEN monday AND sunday AND is_deleted = 0 GROUP BY date`
4. Загрузить water: `SELECT date, SUM(amount_ml) FROM water_logs WHERE date BETWEEN monday AND sunday AND is_deleted = 0 GROUP BY date`
5. Загрузить sleep: вычислить duration для записей за период
6. `daysLogged` = количество уникальных дат с food_logs
7. Средние по дням с данными

### getStreaks(db) → Streaks

**Алгоритм (для каждого типа streak):**

1. **foodLogging streak**: Дни подряд (от сегодня назад), где есть хотя бы 1 food_log
2. **waterGoal streak**: Дни подряд, где `SUM(water_logs.amount_ml) >= target.waterMl`
3. **sleepGoal streak**: Дни подряд, где `SUM(sleep_duration) >= target.sleepMinutes`

Для каждого:
```
current = 0
best = 0
temp = 0
date = today

while (date has data meeting goal):
  temp++
  date = date - 1 day

current = temp

// Для best: пройти все дни с данными и найти максимальную серию
```

### getRangeStats(db, from, to) → RangeStats

**Алгоритм:**
1. Загрузить food_logs за диапазон, сгруппированные по дате
2. Загрузить water_logs за диапазон, сгруппированные по дате
3. Загрузить sleep_logs за диапазон
4. Вычислить средние для дней с данными
5. `daysLogged` = уникальные даты с food_logs

---

## Targets Engine: packages/engine/src/targets/engine.ts

### getActiveTarget(db, date) → DailyTarget | null

**Алгоритм effective date lookup:**

```sql
SELECT * FROM daily_targets
WHERE effective_date <= :date AND is_deleted = 0
ORDER BY effective_date DESC
LIMIT 1
```

Это даёт последний target, который начал действовать до или в указанную дату.

### setTarget(db, data) → DailyTarget

```typescript
export function setTarget(db: DB, data: {
  effectiveDate: string;
  calories: number;
  protein: number;
  fat: number;
  carbs: number;
  waterMl?: number;
  sleepMinutes?: number;
}): DailyTarget {
  const id = createId();
  db.insert(schema.dailyTargets).values({
    id,
    effectiveDate: data.effectiveDate,
    calories: data.calories,
    protein: data.protein,
    fat: data.fat,
    carbs: data.carbs,
    waterMl: data.waterMl ?? 2500,
    sleepMinutes: data.sleepMinutes ?? 480,
  }).run();

  return { id, ...data, waterMl: data.waterMl ?? 2500, sleepMinutes: data.sleepMinutes ?? 480 };
}
```

---

## Test Scenarios (Vitest)

### format.test.ts

```typescript
import { describe, it, expect } from 'vitest';
import { formatCalories, formatMacro, formatWeight, formatWater, formatSleep, formatBodyFat, formatProgress } from '../src/format/index.js';

describe('formatCalories', () => {
  it('1: formats with space separator', () => {
    expect(formatCalories(2150)).toBe('2 150 kcal');
  });
  it('2: zero', () => {
    expect(formatCalories(0)).toBe('0 kcal');
  });
});

describe('formatMacro', () => {
  it('3: tenths to grams', () => {
    expect(formatMacro(253)).toBe('25.3 g');
  });
  it('4: zero', () => {
    expect(formatMacro(0)).toBe('0.0 g');
  });
});

describe('formatWeight', () => {
  it('5: grams to kg', () => {
    expect(formatWeight(75500)).toBe('75.5 kg');
  });
});

describe('formatWater', () => {
  it('6: ml below 1000', () => {
    expect(formatWater(250)).toBe('250 ml');
  });
  it('7: ml above 1000 → liters', () => {
    expect(formatWater(2100)).toBe('2.1 L');
  });
});

describe('formatSleep', () => {
  it('8: hours and minutes', () => {
    expect(formatSleep(465)).toBe('7h 45m');
  });
  it('9: exact hours', () => {
    expect(formatSleep(480)).toBe('8h');
  });
  it('10: only minutes', () => {
    expect(formatSleep(45)).toBe('45m');
  });
});

describe('formatBodyFat', () => {
  it('11: permille to percent', () => {
    expect(formatBodyFat(152)).toBe('15.2%');
  });
});

describe('formatProgress', () => {
  it('12: percentage', () => {
    expect(formatProgress(1500, 2150)).toBe(70);
  });
  it('13: zero target', () => {
    expect(formatProgress(100, 0)).toBe(0);
  });
  it('14: over 100%', () => {
    expect(formatProgress(2500, 2000)).toBe(125);
  });
});
```

### nutrition.test.ts

```typescript
import { describe, it, expect, beforeAll } from 'vitest';
import { createDb } from '../src/db/index.js';
import * as schema from '../src/db/schema.js';
// import engine functions

describe('Nutrition Engine', () => {
  let db: DB;

  beforeAll(() => {
    db = createDb(':memory:');
    // Run migrations (create tables)
    // Seed system meals
    // Create sample food items
  });

  // 1. logFood — creates entry with pre-computed macros
  it('1: logFood computes КБЖУ correctly', () => {
    // Setup: food item with 165 kcal, 31.0g P, 3.6g F, 0g C per 100g
    // Action: logFood with 150g serving
    // Expected: calories=248, protein=465, fat=54, carbs=0
  });

  // 2. logFood — food item not found
  it('2: logFood throws for missing food item', () => {
    // Action: logFood with non-existent foodItemId
    // Expected: throws Error
  });

  // 3. getDailyNutrition — groups by meal
  it('3: getDailyNutrition groups entries by meal', () => {
    // Setup: 2 breakfast entries, 1 lunch entry
    // Action: getDailyNutrition for date
    // Expected: meals[0] has 2 entries, meals[1] has 1 entry
  });

  // 4. getDailyNutrition — totals across meals
  it('4: getDailyNutrition computes correct totals', () => {
    // Expected: totals.calories = sum of all entries
  });

  // 5. getDailyNutrition — empty day
  it('5: getDailyNutrition returns zero totals for empty day', () => {
    // Action: getDailyNutrition for date with no entries
    // Expected: totals all zero, meals empty or with empty entries
  });

  // 6. quickLog — auto-creates food item
  it('6: quickLog creates food_item and food_log', () => {
    // Action: quickLog("Шаурма", 450 kcal, protein=25)
    // Expected: food_item created, food_log with matching values
  });

  // 7. Soft delete — deleted entries excluded
  it('7: getDailyNutrition excludes deleted entries', () => {
    // Setup: log food, then soft delete
    // Expected: getDailyNutrition does not include deleted entry
  });
});
```

### weight.test.ts

```typescript
describe('Weight Engine', () => {
  // 1. logWeight — basic insert
  // 2. logWeight — upsert (same date updates)
  // 3. getLatestWeight — returns most recent
  // 4. getLatestWeight — returns null when empty
  // 5. getWeightTrend — EMA smoothing
  //    Setup: [80000, 79500, 79800, 79200, 79000] over 5 days
  //    Expected: trendGrams is EMA-smoothed, changeGrams is negative
  // 6. getWeightTrend — empty period
  // 7. logWeight with body fat
});
```

### water.test.ts

```typescript
describe('Water Engine', () => {
  // 1. logWater — basic insert
  // 2. getDailyWater — sums multiple entries
  //    Setup: 250ml + 500ml + 330ml
  //    Expected: totalMl = 1080
  // 3. getDailyWater — empty day returns 0
  // 4. getDailyWater — includes target from getActiveTarget
  // 5. Soft delete — deleted entries excluded from total
});
```

### sleep.test.ts

```typescript
describe('Sleep Engine', () => {
  // 1. logSleep — basic insert, computes duration
  //    Setup: 23:00 → 07:00 (8 hours)
  //    Expected: durationMinutes = 480
  // 2. logSleep — validates endTime > startTime
  // 3. getSleepForDate — cross-midnight
  //    Setup: sleep 2026-03-08 23:00 → 2026-03-09 07:00
  //    Expected: appears in 2026-03-09
  // 4. getSleepTrend — averages
  //    Setup: 3 nights, [480, 420, 450]
  //    Expected: avgMinutes = 450
  // 5. getSleepTrend — avgQuality ignores nulls
});
```

### stats.test.ts

```typescript
describe('Stats Engine', () => {
  // 1. getWeekSummary — correct week boundaries (Monday start)
  // 2. getWeekSummary — averages calculated from days with data only
  // 3. getStreaks — current food logging streak
  //    Setup: food logs for today, yesterday, day before
  //    Expected: current = 3
  // 4. getStreaks — broken streak
  //    Setup: food logs for today, skip yesterday, day before
  //    Expected: current = 1
  // 5. getStreaks — water goal streak
  //    Setup: 3 consecutive days meeting water target
  //    Expected: waterGoal.current = 3
  // 6. getRangeStats — correct date range
  // 7. getRangeStats — empty range
});
```
