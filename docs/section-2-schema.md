# Секция 2: Database Schema

## Промпт для Claude Code

```
Read docs/section-1-spec.md and docs/section-2-schema.md.

Set up the Turborepo monorepo and implement the database layer in packages/engine.

### Step 1: Monorepo scaffolding

1. Create pnpm-workspace.yaml:
   packages:
     - 'packages/*'
     - 'apps/*'

2. Create root package.json:
   {
     "name": "htr",
     "private": true,
     "scripts": {
       "dev": "turbo dev",
       "build": "turbo build",
       "test": "turbo test",
       "db:migrate": "pnpm --filter @htr/engine db:migrate",
       "db:seed": "pnpm --filter @htr/engine db:seed"
     },
     "devDependencies": {
       "turbo": "latest",
       "typescript": "latest"
     }
   }

3. Create turbo.json:
   {
     "$schema": "https://turbo.build/schema.json",
     "tasks": {
       "build": { "dependsOn": ["^build"], "outputs": ["dist/**"] },
       "dev": { "cache": false, "persistent": true },
       "test": { "dependsOn": ["^build"] },
       "db:migrate": { "cache": false },
       "db:seed": { "cache": false }
     }
   }

4. Create tsconfig.base.json:
   {
     "compilerOptions": {
       "target": "ES2022",
       "module": "ES2022",
       "moduleResolution": "bundler",
       "strict": true,
       "esModuleInterop": true,
       "skipLibCheck": true,
       "declaration": true,
       "declarationMap": true,
       "sourceMap": true
     }
   }

5. Run `pnpm install` from root.

### Step 2: packages/engine

6. Create packages/engine/package.json:
   {
     "name": "@htr/engine",
     "version": "0.1.0",
     "type": "module",
     "main": "src/index.ts",
     "types": "src/index.ts",
     "scripts": {
       "build": "tsc",
       "test": "vitest run",
       "test:watch": "vitest",
       "db:migrate": "tsx src/db/migrate.ts",
       "db:seed": "tsx src/db/seed.ts"
     },
     "dependencies": {
       "drizzle-orm": "latest",
       "better-sqlite3": "latest",
       "zod": "latest",
       "@paralleldrive/cuid2": "latest"
     },
     "devDependencies": {
       "drizzle-kit": "latest",
       "@types/better-sqlite3": "latest",
       "tsx": "latest",
       "vitest": "latest",
       "typescript": "latest"
     }
   }

7. Create packages/engine/tsconfig.json:
   {
     "extends": "../../tsconfig.base.json",
     "compilerOptions": {
       "outDir": "dist",
       "rootDir": "src"
     },
     "include": ["src/**/*.ts"],
     "exclude": ["node_modules", "dist", "tests"]
   }

8. Implement packages/engine/src/db/schema.ts — ALL tables as specified
9. Create packages/engine/src/db/index.ts — better-sqlite3 + drizzle
10. Create packages/engine/src/db/migrate.ts
11. Create packages/engine/src/db/seed.ts — system meals + sample foods + sample targets
12. Create packages/engine/src/index.ts — re-export everything

13. Run: pnpm db:migrate && pnpm db:seed
    Verify no errors.
```

---

## Schema: packages/engine/src/db/schema.ts

### food_items

Nutritional info per 100g. Переиспользуемая база продуктов.

```typescript
import { sqliteTable, text, integer, index } from 'drizzle-orm/sqlite-core';
import { createId } from '@paralleldrive/cuid2';

export const foodItems = sqliteTable('food_items', {
  id: text('id').primaryKey().$defaultFn(() => createId()),
  name: text('name').notNull(),
  brand: text('brand'),                                        // nullable, e.g. "Lactalis"
  caloriesPer100g: integer('calories_per_100g').notNull(),      // kcal
  proteinPer100g: integer('protein_per_100g').notNull(),        // tenths of grams (25.3g = 253)
  fatPer100g: integer('fat_per_100g').notNull(),                // tenths of grams
  carbsPer100g: integer('carbs_per_100g').notNull(),            // tenths of grams
  fiberPer100g: integer('fiber_per_100g').notNull().default(0), // tenths of grams
  servingSizeG: integer('serving_size_g').notNull().default(100), // default serving in grams
  barcode: text('barcode'),                                     // nullable, future barcode scan
  isDeleted: integer('is_deleted', { mode: 'boolean' }).notNull().default(false),
  createdAt: text('created_at').notNull().$defaultFn(() => new Date().toISOString()),
}, (table) => [
  index('idx_food_items_name').on(table.name),
  index('idx_food_items_barcode').on(table.barcode),
]);
```

### meals

Системные + кастомные приёмы пищи. Системные сидятся при миграции.

```typescript
export const meals = sqliteTable('meals', {
  id: text('id').primaryKey(),                                   // "meal-breakfast", etc.
  name: text('name').notNull(),
  sortOrder: integer('sort_order').notNull(),
  isSystem: integer('is_system', { mode: 'boolean' }).notNull().default(false),
  isDeleted: integer('is_deleted', { mode: 'boolean' }).notNull().default(false),
  createdAt: text('created_at').notNull().$defaultFn(() => new Date().toISOString()),
});
```

**Seed data (4 системные записи):**
```typescript
const systemMeals = [
  { id: 'meal-breakfast', name: 'Breakfast', sortOrder: 1, isSystem: true },
  { id: 'meal-lunch',     name: 'Lunch',     sortOrder: 2, isSystem: true },
  { id: 'meal-dinner',    name: 'Dinner',    sortOrder: 3, isSystem: true },
  { id: 'meal-snack',     name: 'Snack',     sortOrder: 4, isSystem: true },
];
```

### food_logs

Записи о съеденном. Pre-computed КБЖУ для быстрой агрегации.

```typescript
export const foodLogs = sqliteTable('food_logs', {
  id: text('id').primaryKey().$defaultFn(() => createId()),
  date: text('date').notNull(),                                 // YYYY-MM-DD
  mealId: text('meal_id').notNull().references(() => meals.id),
  foodItemId: text('food_item_id').notNull().references(() => foodItems.id),
  servingGrams: integer('serving_grams').notNull(),             // actual grams consumed
  // Pre-computed from food_item × (serving_grams / 100):
  calories: integer('calories').notNull(),                       // kcal
  protein: integer('protein').notNull(),                         // tenths of grams
  fat: integer('fat').notNull(),                                 // tenths of grams
  carbs: integer('carbs').notNull(),                             // tenths of grams
  fiber: integer('fiber').notNull().default(0),                  // tenths of grams
  isDeleted: integer('is_deleted', { mode: 'boolean' }).notNull().default(false),
  createdAt: text('created_at').notNull().$defaultFn(() => new Date().toISOString()),
}, (table) => [
  index('idx_food_logs_date').on(table.date),
  index('idx_food_logs_meal').on(table.mealId),
  index('idx_food_logs_date_meal').on(table.date, table.mealId),
]);
```

**Pre-computation formula** (в engine, integer math):
```typescript
calories = Math.round(foodItem.caloriesPer100g * servingGrams / 100);
protein  = Math.round(foodItem.proteinPer100g  * servingGrams / 100);
fat      = Math.round(foodItem.fatPer100g      * servingGrams / 100);
carbs    = Math.round(foodItem.carbsPer100g    * servingGrams / 100);
fiber    = Math.round(foodItem.fiberPer100g    * servingGrams / 100);
```

### daily_targets

Целевые значения с effective dates. Последняя запись где `effective_date <= date` — активная.

```typescript
export const dailyTargets = sqliteTable('daily_targets', {
  id: text('id').primaryKey().$defaultFn(() => createId()),
  effectiveDate: text('effective_date').notNull(),               // YYYY-MM-DD
  calories: integer('calories').notNull(),                        // kcal target
  protein: integer('protein').notNull(),                          // tenths of grams
  fat: integer('fat').notNull(),                                  // tenths of grams
  carbs: integer('carbs').notNull(),                              // tenths of grams
  waterMl: integer('water_ml').notNull().default(2500),           // ml target
  sleepMinutes: integer('sleep_minutes').notNull().default(480),  // 8h = 480
  isDeleted: integer('is_deleted', { mode: 'boolean' }).notNull().default(false),
  createdAt: text('created_at').notNull().$defaultFn(() => new Date().toISOString()),
}, (table) => [
  index('idx_daily_targets_effective').on(table.effectiveDate),
]);
```

### weight_logs

Один вес в день. Опциональный body fat.

```typescript
export const weightLogs = sqliteTable('weight_logs', {
  id: text('id').primaryKey().$defaultFn(() => createId()),
  date: text('date').notNull().unique(),                         // YYYY-MM-DD, one per day
  weightGrams: integer('weight_grams').notNull(),                // 75.5kg = 75500
  bodyFat: integer('body_fat'),                                  // permille, nullable (15.2% = 152)
  note: text('note'),
  isDeleted: integer('is_deleted', { mode: 'boolean' }).notNull().default(false),
  createdAt: text('created_at').notNull().$defaultFn(() => new Date().toISOString()),
}, (table) => [
  index('idx_weight_logs_date').on(table.date),
]);
```

### water_logs

Несколько записей в день (каждый стакан/бутылка отдельно).

```typescript
export const waterLogs = sqliteTable('water_logs', {
  id: text('id').primaryKey().$defaultFn(() => createId()),
  date: text('date').notNull(),                                  // YYYY-MM-DD
  amountMl: integer('amount_ml').notNull(),                      // e.g. 250, 500
  isDeleted: integer('is_deleted', { mode: 'boolean' }).notNull().default(false),
  createdAt: text('created_at').notNull().$defaultFn(() => new Date().toISOString()),
}, (table) => [
  index('idx_water_logs_date').on(table.date),
]);
```

### sleep_logs

Периоды сна с timestamps (обработка перехода через полночь).

```typescript
export const sleepLogs = sqliteTable('sleep_logs', {
  id: text('id').primaryKey().$defaultFn(() => createId()),
  startTime: text('start_time').notNull(),                       // ISO 8601 timestamp
  endTime: text('end_time').notNull(),                           // ISO 8601 timestamp
  quality: integer('quality'),                                    // 1-5 rating, nullable
  note: text('note'),
  isDeleted: integer('is_deleted', { mode: 'boolean' }).notNull().default(false),
  createdAt: text('created_at').notNull().$defaultFn(() => new Date().toISOString()),
});
```

---

## DB Connection: packages/engine/src/db/index.ts

```typescript
import Database from 'better-sqlite3';
import { drizzle } from 'drizzle-orm/better-sqlite3';
import { mkdirSync } from 'node:fs';
import { dirname } from 'node:path';
import * as schema from './schema.js';

export function createDb(dbPath = './data/htr.db') {
  // ':memory:' для тестов — не нужен mkdir
  if (dbPath !== ':memory:') {
    mkdirSync(dirname(dbPath), { recursive: true });
  }
  const sqlite = new Database(dbPath);
  sqlite.pragma('journal_mode = WAL');
  sqlite.pragma('foreign_keys = ON');
  return drizzle(sqlite, { schema });
}

export const db = createDb(process.env.DATABASE_PATH ?? './data/htr.db');
export type DB = ReturnType<typeof createDb>;
export { schema };
```

---

## Migration: packages/engine/src/db/migrate.ts

```typescript
import Database from 'better-sqlite3';
import { drizzle } from 'drizzle-orm/better-sqlite3';
import { sql } from 'drizzle-orm';
import * as schema from './schema.js';

const dbPath = process.env.DATABASE_PATH ?? './data/htr.db';

// Create tables using Drizzle's push or manual CREATE TABLE
// For simplicity, use raw SQL derived from schema:

const sqlite = new Database(dbPath);
sqlite.pragma('journal_mode = WAL');
sqlite.pragma('foreign_keys = ON');

const db = drizzle(sqlite, { schema });

// Create all tables
sqlite.exec(`
  CREATE TABLE IF NOT EXISTS food_items (
    id                TEXT PRIMARY KEY,
    name              TEXT NOT NULL,
    brand             TEXT,
    calories_per_100g INTEGER NOT NULL,
    protein_per_100g  INTEGER NOT NULL,
    fat_per_100g      INTEGER NOT NULL,
    carbs_per_100g    INTEGER NOT NULL,
    fiber_per_100g    INTEGER NOT NULL DEFAULT 0,
    serving_size_g    INTEGER NOT NULL DEFAULT 100,
    barcode           TEXT,
    is_deleted        INTEGER NOT NULL DEFAULT 0,
    created_at        TEXT NOT NULL DEFAULT (datetime('now'))
  );

  CREATE TABLE IF NOT EXISTS meals (
    id         TEXT PRIMARY KEY,
    name       TEXT NOT NULL,
    sort_order INTEGER NOT NULL,
    is_system  INTEGER NOT NULL DEFAULT 0,
    is_deleted INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
  );

  CREATE TABLE IF NOT EXISTS food_logs (
    id              TEXT PRIMARY KEY,
    date            TEXT NOT NULL,
    meal_id         TEXT NOT NULL REFERENCES meals(id),
    food_item_id    TEXT NOT NULL REFERENCES food_items(id),
    serving_grams   INTEGER NOT NULL,
    calories        INTEGER NOT NULL,
    protein         INTEGER NOT NULL,
    fat             INTEGER NOT NULL,
    carbs           INTEGER NOT NULL,
    fiber           INTEGER NOT NULL DEFAULT 0,
    is_deleted      INTEGER NOT NULL DEFAULT 0,
    created_at      TEXT NOT NULL DEFAULT (datetime('now'))
  );

  CREATE TABLE IF NOT EXISTS daily_targets (
    id              TEXT PRIMARY KEY,
    effective_date  TEXT NOT NULL,
    calories        INTEGER NOT NULL,
    protein         INTEGER NOT NULL,
    fat             INTEGER NOT NULL,
    carbs           INTEGER NOT NULL,
    water_ml        INTEGER NOT NULL DEFAULT 2500,
    sleep_minutes   INTEGER NOT NULL DEFAULT 480,
    is_deleted      INTEGER NOT NULL DEFAULT 0,
    created_at      TEXT NOT NULL DEFAULT (datetime('now'))
  );

  CREATE TABLE IF NOT EXISTS weight_logs (
    id           TEXT PRIMARY KEY,
    date         TEXT NOT NULL UNIQUE,
    weight_grams INTEGER NOT NULL,
    body_fat     INTEGER,
    note         TEXT,
    is_deleted   INTEGER NOT NULL DEFAULT 0,
    created_at   TEXT NOT NULL DEFAULT (datetime('now'))
  );

  CREATE TABLE IF NOT EXISTS water_logs (
    id         TEXT PRIMARY KEY,
    date       TEXT NOT NULL,
    amount_ml  INTEGER NOT NULL,
    is_deleted INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
  );

  CREATE TABLE IF NOT EXISTS sleep_logs (
    id          TEXT PRIMARY KEY,
    start_time  TEXT NOT NULL,
    end_time    TEXT NOT NULL,
    quality     INTEGER,
    note        TEXT,
    is_deleted  INTEGER NOT NULL DEFAULT 0,
    created_at  TEXT NOT NULL DEFAULT (datetime('now'))
  );

  -- Indexes
  CREATE INDEX IF NOT EXISTS idx_food_items_name ON food_items(name);
  CREATE INDEX IF NOT EXISTS idx_food_items_barcode ON food_items(barcode);
  CREATE INDEX IF NOT EXISTS idx_food_logs_date ON food_logs(date);
  CREATE INDEX IF NOT EXISTS idx_food_logs_meal ON food_logs(meal_id);
  CREATE INDEX IF NOT EXISTS idx_food_logs_date_meal ON food_logs(date, meal_id);
  CREATE INDEX IF NOT EXISTS idx_daily_targets_effective ON daily_targets(effective_date);
  CREATE INDEX IF NOT EXISTS idx_weight_logs_date ON weight_logs(date);
  CREATE INDEX IF NOT EXISTS idx_water_logs_date ON water_logs(date);
`);

console.log('✅ Tables created successfully');
sqlite.close();
```

---

## Seed: packages/engine/src/db/seed.ts

```typescript
import { createDb } from './index.js';
import { createId } from '@paralleldrive/cuid2';
import * as schema from './schema.js';

const db = createDb(process.env.DATABASE_PATH ?? './data/htr.db');

// ═══════════════════════════════════════
// 1. System Meals (idempotent)
// ═══════════════════════════════════════

const systemMeals = [
  { id: 'meal-breakfast', name: 'Breakfast', sortOrder: 1, isSystem: true },
  { id: 'meal-lunch',     name: 'Lunch',     sortOrder: 2, isSystem: true },
  { id: 'meal-dinner',    name: 'Dinner',    sortOrder: 3, isSystem: true },
  { id: 'meal-snack',     name: 'Snack',     sortOrder: 4, isSystem: true },
];

// Delete existing system meals, then re-insert
db.delete(schema.meals).run();
for (const meal of systemMeals) {
  db.insert(schema.meals).values(meal).run();
}
console.log(`✅ ${systemMeals.length} system meals seeded`);

// ═══════════════════════════════════════
// 2. Sample Food Items (казахские блюда)
// ═══════════════════════════════════════

const sampleFoods = [
  // Казахская кухня
  {
    id: createId(), name: 'Бешбармак',
    caloriesPer100g: 150, proteinPer100g: 80, fatPer100g: 90, carbsPer100g: 100,
    fiberPer100g: 5, servingSizeG: 350,
  },
  {
    id: createId(), name: 'Плов',
    caloriesPer100g: 180, proteinPer100g: 60, fatPer100g: 80, carbsPer100g: 220,
    fiberPer100g: 10, servingSizeG: 300,
  },
  {
    id: createId(), name: 'Лагман',
    caloriesPer100g: 120, proteinPer100g: 55, fatPer100g: 45, carbsPer100g: 140,
    fiberPer100g: 15, servingSizeG: 400,
  },
  {
    id: createId(), name: 'Манты',
    caloriesPer100g: 200, proteinPer100g: 90, fatPer100g: 100, carbsPer100g: 200,
    fiberPer100g: 8, servingSizeG: 200,
  },
  {
    id: createId(), name: 'Баурсак',
    caloriesPer100g: 360, proteinPer100g: 70, fatPer100g: 150, carbsPer100g: 500,
    fiberPer100g: 10, servingSizeG: 100,
  },
  {
    id: createId(), name: 'Шубат (кумыс)',
    caloriesPer100g: 50, proteinPer100g: 30, fatPer100g: 20, carbsPer100g: 50,
    fiberPer100g: 0, servingSizeG: 250,
  },
  {
    id: createId(), name: 'Казы (конская колбаса)',
    caloriesPer100g: 260, proteinPer100g: 120, fatPer100g: 220, carbsPer100g: 0,
    fiberPer100g: 0, servingSizeG: 100,
  },
  // Базовые продукты
  {
    id: createId(), name: 'Куриная грудка',
    caloriesPer100g: 165, proteinPer100g: 310, fatPer100g: 36, carbsPer100g: 0,
    fiberPer100g: 0, servingSizeG: 150,
  },
  {
    id: createId(), name: 'Рис варёный',
    caloriesPer100g: 130, proteinPer100g: 27, fatPer100g: 3, carbsPer100g: 280,
    fiberPer100g: 4, servingSizeG: 200,
  },
  {
    id: createId(), name: 'Гречка варёная',
    caloriesPer100g: 110, proteinPer100g: 38, fatPer100g: 22, carbsPer100g: 200,
    fiberPer100g: 28, servingSizeG: 200,
  },
  {
    id: createId(), name: 'Овсянка на воде',
    caloriesPer100g: 78, proteinPer100g: 27, fatPer100g: 14, carbsPer100g: 136,
    fiberPer100g: 17, servingSizeG: 250,
  },
  {
    id: createId(), name: 'Яйцо куриное',
    caloriesPer100g: 155, proteinPer100g: 130, fatPer100g: 110, carbsPer100g: 11,
    fiberPer100g: 0, servingSizeG: 60,
  },
  {
    id: createId(), name: 'Банан',
    caloriesPer100g: 89, proteinPer100g: 11, fatPer100g: 3, carbsPer100g: 225,
    fiberPer100g: 26, servingSizeG: 120,
  },
  {
    id: createId(), name: 'Творог 5%',
    caloriesPer100g: 121, proteinPer100g: 170, fatPer100g: 50, carbsPer100g: 18,
    fiberPer100g: 0, servingSizeG: 200,
  },
];

db.delete(schema.foodItems).run();
for (const food of sampleFoods) {
  db.insert(schema.foodItems).values(food).run();
}
console.log(`✅ ${sampleFoods.length} food items seeded`);

// ═══════════════════════════════════════
// 3. Sample Daily Target
// ═══════════════════════════════════════

const sampleTarget = {
  id: createId(),
  effectiveDate: '2026-01-01',
  calories: 2150,
  protein: 1200,    // 120.0g
  fat: 700,         // 70.0g
  carbs: 2500,      // 250.0g
  waterMl: 2500,
  sleepMinutes: 480,
};

db.delete(schema.dailyTargets).run();
db.insert(schema.dailyTargets).values(sampleTarget).run();
console.log('✅ Sample daily target seeded');

console.log('\n🎉 Seed complete!');
```

Важно:
- Системные meals с фиксированными ID — никогда не меняются
- Food items: КБЖУ в правильных единицах (kcal + десятые грамма)
- Idempotent: DELETE перед INSERT
- Daily target: стандартные 2150 kcal / 120g P / 70g F / 250g C
