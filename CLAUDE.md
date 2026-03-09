# HTR — Health Tracker

Turborepo monorepo. Calorie/macro/weight/water/sleep tracking engine + REST API.

## Structure

- `packages/engine` — @htr/engine: core library (nutrition, weight, water, sleep engines, formatting, db)
- `apps/api` — Hono REST server, depends on @htr/engine
- `packages/skill` — OpenClaw skill (curl-based API wrapper)

## Tech Stack

- Monorepo: Turborepo + pnpm workspaces
- Runtime: Node.js 22
- TS execution: tsx
- ORM: Drizzle + better-sqlite3
- Validation: Zod
- Testing: Vitest
- API: Hono + @hono/node-server
- Deploy: Railway (Dockerfile)

## Key Conventions

### Units & Storage

All values stored as integers to avoid floating-point errors.

| Domain    | Storage unit     | Example                  |
|-----------|------------------|--------------------------|
| Weight    | grams (int)      | 75.5 kg → `75500`       |
| Calories  | kcal (int)       | 2150 kcal → `2150`      |
| Macros    | tenths of grams  | 25.3 g protein → `253`  |
| Water     | ml (int)         | 250 ml → `250`          |
| Body fat  | permille (int)   | 15.2% → `152`           |
| Sleep     | ISO timestamps   | duration computed        |

- Formatting: `formatWeight()`, `formatMacro()`, `formatWater()` etc. only at API response layer
- Never use raw JS arithmetic for macro calculations — use integer math throughout

### IDs

- Generator: cuid2
- System IDs (hardcoded, never change):
  - `"meal-breakfast"` — Breakfast
  - `"meal-lunch"` — Lunch
  - `"meal-dinner"` — Dinner
  - `"meal-snack"` — Snack

### Dates & Time

- Food/weight/water logs: `YYYY-MM-DD` (date string)
- Sleep logs: ISO 8601 timestamps for start/end (sleep crosses midnight)
- Date ranges: string comparison `date >= '2026-01-01' AND date <= '2026-01-31'`
- Weekly stats: ISO week (Monday start)

### Data Model Rules

- Daily totals: COMPUTED from `SUM(food_logs)` per date, never stored
- Weight trend: COMPUTED via exponential moving average over weight_logs
- Water total: COMPUTED from `SUM(water_logs.amount_ml)` per date
- Sleep duration: COMPUTED from `end_time - start_time` per entry
- Target lookup: latest `daily_targets` row where `effective_date <= target_date`
- Soft delete: `is_deleted = true` (never physical delete)
- Food items are reusable — food_logs reference them with a serving multiplier

## Database Schema (9 tables)

### food_items

Nutritional info per 100g serving. Reusable food database.

```sql
CREATE TABLE food_items (
  id                TEXT PRIMARY KEY,
  name              TEXT NOT NULL,
  brand             TEXT,                    -- nullable, e.g. "Lactalis"
  calories_per_100g INTEGER NOT NULL,        -- kcal
  protein_per_100g  INTEGER NOT NULL,        -- tenths of grams (25.3g = 253)
  fat_per_100g      INTEGER NOT NULL,        -- tenths of grams
  carbs_per_100g    INTEGER NOT NULL,        -- tenths of grams
  fiber_per_100g    INTEGER NOT NULL DEFAULT 0, -- tenths of grams
  serving_size_g    INTEGER NOT NULL DEFAULT 100, -- default serving in grams
  barcode           TEXT,                    -- nullable, for future barcode scan
  is_deleted        INTEGER NOT NULL DEFAULT 0,
  created_at        TEXT NOT NULL DEFAULT (datetime('now'))
);
```

### meals

System + custom meal slots. System meals are seeded, users can add custom ones.

```sql
CREATE TABLE meals (
  id         TEXT PRIMARY KEY,              -- "meal-breakfast", "meal-lunch", etc.
  name       TEXT NOT NULL,                 -- "Breakfast", "Lunch", etc.
  sort_order INTEGER NOT NULL,              -- display order
  is_system  INTEGER NOT NULL DEFAULT 0,    -- 1 for system meals
  is_deleted INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
```

**Seed data:**
```
("meal-breakfast", "Breakfast", 1, 1)
("meal-lunch",     "Lunch",     2, 1)
("meal-dinner",    "Dinner",    3, 1)
("meal-snack",     "Snack",     4, 1)
```

### food_logs

Individual food entries. Pre-computed macros for fast aggregation.

```sql
CREATE TABLE food_logs (
  id              TEXT PRIMARY KEY,
  date            TEXT NOT NULL,              -- YYYY-MM-DD
  meal_id         TEXT NOT NULL REFERENCES meals(id),
  food_item_id    TEXT NOT NULL REFERENCES food_items(id),
  serving_grams   INTEGER NOT NULL,           -- actual grams consumed
  -- Pre-computed from food_item × (serving_grams / 100):
  calories        INTEGER NOT NULL,           -- kcal
  protein         INTEGER NOT NULL,           -- tenths of grams
  fat             INTEGER NOT NULL,           -- tenths of grams
  carbs           INTEGER NOT NULL,           -- tenths of grams
  fiber           INTEGER NOT NULL DEFAULT 0, -- tenths of grams
  is_deleted      INTEGER NOT NULL DEFAULT 0,
  created_at      TEXT NOT NULL DEFAULT (datetime('now'))
);
```

**Pre-computation formula** (in engine, using integer math):
```typescript
calories = Math.round(foodItem.caloriesPer100g * servingGrams / 100);
protein  = Math.round(foodItem.proteinPer100g  * servingGrams / 100);
// same for fat, carbs, fiber
```

### daily_targets

Goal settings with effective dates. Latest row where `effective_date <= date` wins.

```sql
CREATE TABLE daily_targets (
  id              TEXT PRIMARY KEY,
  effective_date  TEXT NOT NULL,              -- YYYY-MM-DD, when this target starts
  calories        INTEGER NOT NULL,           -- kcal target
  protein         INTEGER NOT NULL,           -- tenths of grams
  fat             INTEGER NOT NULL,           -- tenths of grams
  carbs           INTEGER NOT NULL,           -- tenths of grams
  water_ml        INTEGER NOT NULL DEFAULT 2500, -- ml target
  sleep_minutes   INTEGER NOT NULL DEFAULT 480,  -- target sleep in minutes (8h = 480)
  is_deleted      INTEGER NOT NULL DEFAULT 0,
  created_at      TEXT NOT NULL DEFAULT (datetime('now'))
);
```

### weight_logs

One entry per day. Optional body fat percentage.

```sql
CREATE TABLE weight_logs (
  id           TEXT PRIMARY KEY,
  date         TEXT NOT NULL UNIQUE,          -- YYYY-MM-DD, one per day
  weight_grams INTEGER NOT NULL,              -- 75.5kg = 75500
  body_fat     INTEGER,                       -- permille, nullable (15.2% = 152)
  note         TEXT,                          -- optional note
  is_deleted   INTEGER NOT NULL DEFAULT 0,
  created_at   TEXT NOT NULL DEFAULT (datetime('now'))
);
```

### water_logs

Multiple entries per day (each glass/bottle logged separately).

```sql
CREATE TABLE water_logs (
  id         TEXT PRIMARY KEY,
  date       TEXT NOT NULL,                   -- YYYY-MM-DD
  amount_ml  INTEGER NOT NULL,                -- e.g. 250, 500
  is_deleted INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
```

### sleep_logs

Sleep periods with timestamps (handles cross-midnight).

```sql
CREATE TABLE sleep_logs (
  id          TEXT PRIMARY KEY,
  start_time  TEXT NOT NULL,                  -- ISO 8601 timestamp
  end_time    TEXT NOT NULL,                  -- ISO 8601 timestamp
  quality     INTEGER,                        -- 1-5 rating, nullable
  note        TEXT,                           -- optional note
  is_deleted  INTEGER NOT NULL DEFAULT 0,
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);
```

### user_profile

User profile (single row, id='default').

```sql
CREATE TABLE user_profile (
  id              TEXT PRIMARY KEY,            -- always 'default'
  height_cm       INTEGER NOT NULL,            -- cm
  birth_date      TEXT NOT NULL,               -- YYYY-MM-DD
  sex             TEXT NOT NULL,               -- 'male' | 'female'
  activity_level  TEXT NOT NULL DEFAULT 'moderate', -- sedentary/light/moderate/active/very_active
  created_at      TEXT NOT NULL,
  updated_at      TEXT NOT NULL
);
```

### weight_goals

Weight goals with pace and progress tracking.

```sql
CREATE TABLE weight_goals (
  id           TEXT PRIMARY KEY,              -- cuid2
  target_grams INTEGER NOT NULL,              -- 70000 = 70 kg
  pace         TEXT NOT NULL DEFAULT 'normal', -- slow/normal/fast
  start_date   TEXT NOT NULL,                 -- YYYY-MM-DD
  start_grams  INTEGER NOT NULL,              -- weight at goal creation
  is_active    INTEGER NOT NULL DEFAULT 1,    -- only one active at a time
  is_deleted   INTEGER NOT NULL DEFAULT 0,
  created_at   TEXT NOT NULL
);
```

## Engine Pattern

Every engine function takes `db: DB` as first argument (dependency injection):

```typescript
// Nutrition engine
export function logFood(db: DB, data: { date: string; mealId: string; foodItemId: string; servingGrams: number }): FoodLogEntry { ... }
export function getDailyNutrition(db: DB, date: string): DailyNutrition { ... }
export function quickLog(db: DB, data: { date: string; mealId: string; name: string; calories: number; protein?: number; fat?: number; carbs?: number }): FoodLogEntry { ... }

// Weight engine
export function logWeight(db: DB, data: { date: string; weightGrams: number; bodyFat?: number; note?: string }): WeightLogEntry { ... }
export function getWeightTrend(db: DB, days: number): WeightTrend { ... }
export function getLatestWeight(db: DB): WeightLogEntry | null { ... }

// Water engine
export function logWater(db: DB, data: { date: string; amountMl: number }): WaterLogEntry { ... }
export function getDailyWater(db: DB, date: string): { totalMl: number; targetMl: number; entries: WaterLogEntry[] } { ... }

// Sleep engine
export function logSleep(db: DB, data: { startTime: string; endTime: string; quality?: number; note?: string }): SleepLogEntry { ... }
export function getSleepForDate(db: DB, date: string): SleepLogEntry[] { ... }

// Stats engine
export function getWeekSummary(db: DB, date: string): WeekSummary { ... }
export function getStreaks(db: DB): Streaks { ... }
export function getRangeStats(db: DB, from: string, to: string): RangeStats { ... }

// Targets
export function getActiveTarget(db: DB, date: string): DailyTarget | null { ... }
export function setTarget(db: DB, data: { effectiveDate: string; calories: number; protein: number; fat: number; carbs: number; waterMl?: number; sleepMinutes?: number }): DailyTarget { ... }

// Profile engine
export function setProfile(db: DB, data: { heightCm: number; birthDate: string; sex: string; activityLevel?: string }): UserProfile { ... }
export function getProfile(db: DB): UserProfile | null { ... }
export function calculateAge(birthDate: string, atDate?: string): number { ... }
export function calculateBmr(profile: UserProfile, weightGrams: number): number { ... }
export function calculateTdee(bmr: number, activityLevel: string): number { ... }
export function getTargetCalories(db: DB, date?: string): TdeeCalculation | null { ... }

// Goals engine
export function setWeightGoal(db: DB, data: { targetGrams: number; pace?: string }): WeightGoal { ... }
export function getActiveGoal(db: DB): WeightGoal | null { ... }
export function getGoalProgress(db: DB): WeightGoalProgress | null { ... }
export function deleteWeightGoal(db: DB, id: string): void { ... }
```

This lets apps/api and tests each create their own db instance.

### Key Computed Types

```typescript
interface DailyNutrition {
  date: string;
  meals: { meal: Meal; entries: FoodLogEntry[] }[];
  totals: { calories: number; protein: number; fat: number; carbs: number; fiber: number };
  target: DailyTarget | null;
}

interface CaloriesBudget {
  targetCalories: number; consumedCalories: number; remainingCalories: number;
  targetCaloriesFormatted: string; consumedCaloriesFormatted: string;
  remainingCaloriesFormatted: string; progress: number;
}

interface DailySummary {
  date: string;
  caloriesBudget: CaloriesBudget | null;
  tdee: TdeeCalculation | null;
  nutrition: DailyNutrition;
  water: { totalMl: number; targetMl: number };
  sleep: { totalMinutes: number; targetMinutes: number; quality: number | null };
  weight: WeightLogEntry | null;
}

interface UserProfile {
  id: string; heightCm: number; birthDate: string; sex: string;
  activityLevel: string; createdAt: string; updatedAt: string;
}

interface TdeeCalculation { bmr: number; tdee: number; targetCalories: number; deficit: number; }

interface WeightGoal {
  id: string; targetGrams: number; pace: string; startDate: string;
  startGrams: number; isActive: number; isDeleted: number; createdAt: string;
}

interface WeightGoalProgress {
  goal: WeightGoal; currentGrams: number; remainingGrams: number;
  progressPercent: number; estimatedDaysLeft: number; estimatedDate: string;
  direction: "loss" | "gain"; tdee: TdeeCalculation | null;
}

interface WeekSummary {
  weekStart: string; // Monday
  avgCalories: number;
  avgProtein: number;
  avgFat: number;
  avgCarbs: number;
  avgWaterMl: number;
  avgSleepMinutes: number;
  daysLogged: number;
}

interface WeightTrend {
  entries: WeightLogEntry[];
  trendGrams: number; // EMA smoothed current
  changeGrams: number; // vs period start
}

interface Streaks {
  foodLogging: { current: number; best: number };
  waterGoal: { current: number; best: number };
  sleepGoal: { current: number; best: number };
}
```

## API Routes

### Food Items — `/api/v1/foods`

| Method | Path                  | Description              |
|--------|-----------------------|--------------------------|
| GET    | `/api/v1/foods`       | List all (+ `?q=search`) |
| GET    | `/api/v1/foods/:id`   | Get by ID                |
| POST   | `/api/v1/foods`       | Create food item         |
| PATCH  | `/api/v1/foods/:id`   | Update food item         |
| DELETE | `/api/v1/foods/:id`   | Soft delete              |

### Food Logs — `/api/v1/food-logs`

| Method | Path                         | Description                                |
|--------|------------------------------|--------------------------------------------|
| GET    | `/api/v1/food-logs?date=`    | Get food logs for date (grouped by meal)   |
| POST   | `/api/v1/food-logs`          | Log food (from food_item + serving_grams)  |
| POST   | `/api/v1/food-logs/quick`    | Quick-log (inline name + calories + macros, auto-creates food_item) |
| DELETE | `/api/v1/food-logs/:id`      | Soft delete                                |

### Weight — `/api/v1/weight`

| Method | Path                          | Description              |
|--------|-------------------------------|--------------------------|
| GET    | `/api/v1/weight`              | List entries (+ `?days=30`) |
| GET    | `/api/v1/weight/latest`       | Latest entry + trend     |
| POST   | `/api/v1/weight`              | Log weight               |
| DELETE | `/api/v1/weight/:id`          | Soft delete              |

### Water — `/api/v1/water`

| Method | Path                          | Description              |
|--------|-------------------------------|--------------------------|
| GET    | `/api/v1/water?date=`         | Daily water summary      |
| POST   | `/api/v1/water`               | Log water intake         |
| DELETE | `/api/v1/water/:id`           | Soft delete              |

### Sleep — `/api/v1/sleep`

| Method | Path                          | Description              |
|--------|-------------------------------|--------------------------|
| GET    | `/api/v1/sleep?date=`         | Sleep entries for date   |
| GET    | `/api/v1/sleep/trend?days=7`  | Sleep trend              |
| POST   | `/api/v1/sleep`               | Log sleep                |
| DELETE | `/api/v1/sleep/:id`           | Soft delete              |

### Daily Summary — `/api/v1/daily/:date`

| Method | Path                     | Description                               |
|--------|--------------------------|-------------------------------------------|
| GET    | `/api/v1/daily/:date`    | Full summary: nutrition + water + sleep + weight + targets |

### Targets — `/api/v1/targets`

| Method | Path                      | Description              |
|--------|---------------------------|--------------------------|
| GET    | `/api/v1/targets`         | List all targets         |
| GET    | `/api/v1/targets/active`  | Active target for today  |
| POST   | `/api/v1/targets`         | Set new target           |

### Stats — `/api/v1/stats`

| Method | Path                              | Description              |
|--------|-----------------------------------|--------------------------|
| GET    | `/api/v1/stats/week?date=`        | Week summary             |
| GET    | `/api/v1/stats/streaks`           | Current streaks          |
| GET    | `/api/v1/stats/range?from=&to=`   | Range averages           |
| GET    | `/api/v1/stats/weight-trend?days=`| Weight trend + EMA       |

### Profile — `/api/v1/profile`

| Method | Path                    | Description                    |
|--------|-------------------------|--------------------------------|
| GET    | `/api/v1/profile`       | Get user profile               |
| PUT    | `/api/v1/profile`       | Create/update profile (UPSERT) |
| GET    | `/api/v1/profile/tdee`  | TDEE + target calories         |

### Weight Goals — `/api/v1/goals`

| Method | Path                         | Description              |
|--------|------------------------------|--------------------------|
| POST   | `/api/v1/goals/weight`       | Set weight goal          |
| GET    | `/api/v1/goals/weight`       | Active goal + progress   |
| DELETE | `/api/v1/goals/weight/:id`   | Soft delete              |

### Health Check

| Method | Path        | Description |
|--------|-------------|-------------|
| GET    | `/health`   | `{ status: "ok" }` |

## API Response Format

- Errors: `{ error: { code, message, suggestion } }`
- Nutrition fields: always include both raw and formatted variants
  - `calories: 2150` + `caloriesFormatted: "2 150 kcal"`
  - `protein: 253` + `proteinFormatted: "25.3 g"`
  - `weightGrams: 75500` + `weightFormatted: "75.5 kg"`
  - `waterMl: 2100` + `waterFormatted: "2.1 L"` (use L above 1000ml)
  - `sleepMinutes: 465` + `sleepFormatted: "7h 45m"`
  - `bodyFat: 152` + `bodyFatFormatted: "15.2%"`
- Daily summary: individual engines compute data → route assembles into `DailySummary`
- Progress bars: include `progress` field (0-100) for target-based values

## Formatting Functions

```typescript
export function formatCalories(kcal: number): string { ... }      // "2 150 kcal"
export function formatMacro(tenths: number): string { ... }        // "25.3 g"
export function formatWeight(grams: number): string { ... }        // "75.5 kg"
export function formatWater(ml: number): string { ... }            // "250 ml" or "2.1 L"
export function formatSleep(minutes: number): string { ... }       // "7h 45m"
export function formatBodyFat(permille: number): string { ... }    // "15.2%"
export function formatProgress(current: number, target: number): number { ... } // 0-100
```

## Testing

- Framework: Vitest
- DB in tests: `createDb(':memory:')` for isolation
- API tests: `app.request()` (no HTTP server needed)
- Seed test data in `beforeAll` block
- Test each engine independently, then integration via API routes

## Commands (from root)

```bash
pnpm install          # Install all deps
pnpm dev              # Start API with tsx watch (via turbo)
pnpm test             # Run all tests (via turbo)
pnpm build            # Build all packages
pnpm db:migrate       # Create tables (packages/engine)
pnpm db:seed          # Seed system meals (packages/engine)
```

## File Naming

- Schema: `packages/engine/src/db/schema.ts`
- DB connection: `packages/engine/src/db/index.ts` (exports `createDb`, `db`, `schema`)
- Migrations: `packages/engine/src/db/migrate.ts`
- Nutrition engine: `packages/engine/src/nutrition/engine.ts`
- Weight engine: `packages/engine/src/weight/engine.ts`
- Water engine: `packages/engine/src/water/engine.ts`
- Sleep engine: `packages/engine/src/sleep/engine.ts`
- Stats engine: `packages/engine/src/stats/engine.ts`
- Targets engine: `packages/engine/src/targets/engine.ts`
- Profile engine: `packages/engine/src/profile/engine.ts`
- Goals engine: `packages/engine/src/goals/engine.ts`
- Formatting: `packages/engine/src/format/index.ts`
- API routes: `apps/api/src/routes/{resource}.ts`
- API app: `apps/api/src/app.ts`
- API entry: `apps/api/src/index.ts`
- Tests: `{package}/tests/{module}.test.ts`

## OpenClaw Skill

File: `packages/skill/skill.sh`

Environment variables: `HTR_API_URL`, `HTR_API_KEY`

Commands:
- `htr log food <date> <meal> <food_id> <grams>` — Log food
- `htr quick-log <date> <meal> <name> <calories>` — Quick log
- `htr log weight <date> <kg>` — Log weight (converts to grams)
- `htr log water <date> <ml>` — Log water
- `htr log sleep <start> <end>` — Log sleep
- `htr daily [date]` — Daily summary (default: today)
- `htr foods search <query>` — Search food items
- `htr weight [days]` — Weight trend (default: 30 days)
- `htr stats week [date]` — Week summary
- `htr streaks` — Current streaks
- `htr targets` — Active targets

## Spec Files (read these before implementing)

- `docs/section-1-spec.md` — Architecture, entities, tech stack
- `docs/section-2-schema.md` — Database schema, seed data, migrations
- `docs/section-3-engines.md` — Engine functions, algorithms, test scenarios
- `docs/section-4-rest-api.md` — REST API routes, Zod schemas, responses
- `docs/section-5-assembly.md` — Build prompts, OpenClaw skill, deploy
- `docs/section-6-factors-correlations.md` — Factors & correlations spec (future)

## Build Order

1. `packages/engine` — schema, migrations, seed, engines, formatting
2. `apps/api` — routes, middleware, error handling
3. `packages/skill` — curl wrapper
4. Docker + Railway deploy

## Docker

```dockerfile
FROM node:22-slim
WORKDIR /app
COPY . .
RUN corepack enable && pnpm install --frozen-lockfile && pnpm build
ENV PORT=3000 DATABASE_PATH=/data/htr.db
EXPOSE 3000
CMD ["node", "apps/api/dist/index.js"]
```

Volume: `/data` for persistent SQLite database on Railway.