# Секция 4: REST API

## Промпт для Claude Code

```
Read all docs in the docs/ directory (section-1 through section-4).

Implement the REST API in apps/api using Hono + @hono/node-server.

### Step 1: apps/api setup

1. Create apps/api/package.json:
   {
     "name": "@htr/api",
     "version": "0.1.0",
     "type": "module",
     "scripts": {
       "dev": "tsx watch src/index.ts",
       "start": "tsx src/index.ts",
       "build": "tsc",
       "test": "vitest run"
     },
     "dependencies": {
       "@htr/engine": "workspace:*",
       "hono": "latest",
       "@hono/node-server": "latest"
     },
     "devDependencies": {
       "tsx": "latest",
       "vitest": "latest",
       "typescript": "latest"
     }
   }

2. Create apps/api/tsconfig.json extending ../../tsconfig.base.json
3. Create apps/api/vitest.config.ts
4. pnpm install from root

### Step 2: Implementation

5. Create apps/api/src/db.ts (import createDb from @htr/engine)
6. Create apps/api/src/errors.ts (AppError class)
7. Create apps/api/src/app.ts (Hono + middleware + routes)
8. Create all route files in apps/api/src/routes/
9. Create apps/api/src/index.ts (entry point with @hono/node-server)

10. Write apps/api/tests/api.test.ts (use app.request())

11. pnpm db:migrate && pnpm db:seed
12. pnpm dev — start and test manually
13. Fix ALL errors.
```

---

## Entry Point: apps/api/src/index.ts

```typescript
import { serve } from '@hono/node-server';
import { app } from './app.js';

const port = parseInt(process.env.PORT ?? '3000');

serve({ fetch: app.fetch, port }, (info) => {
  console.log(`
╔══════════════════════════════════╗
║       HTR API v0.1.0             ║
║    Health Tracker Engine         ║
╚══════════════════════════════════╝
→ http://localhost:${info.port}
  `);
});
```

## DB: apps/api/src/db.ts

```typescript
import { createDb } from '@htr/engine';
const dbPath = process.env.DATABASE_PATH ?? './data/htr.db';
export const db = createDb(dbPath);
```

## Errors: apps/api/src/errors.ts

```typescript
export class AppError extends Error {
  constructor(
    public code: string,
    message: string,
    public status = 400,
    public suggestion = ''
  ) { super(message); }
}

export const notFound = (entity: string, id: string) =>
  new AppError('NOT_FOUND', `${entity} '${id}' not found`, 404,
    `Use GET /api/v1/${entity.toLowerCase()}s to list available IDs`);

export const validationError = (message: string) =>
  new AppError('VALIDATION_ERROR', message, 400, 'Check request body');
```

## App: apps/api/src/app.ts

```typescript
import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { logger } from 'hono/logger';
import { foodRoutes } from './routes/foods.js';
import { foodLogRoutes } from './routes/food-logs.js';
import { weightRoutes } from './routes/weight.js';
import { waterRoutes } from './routes/water.js';
import { sleepRoutes } from './routes/sleep.js';
import { dailyRoutes } from './routes/daily.js';
import { targetRoutes } from './routes/targets.js';
import { statRoutes } from './routes/stats.js';

export const app = new Hono();
app.use('*', cors());
app.use('*', logger());

app.onError((err, c) => {
  console.error(err);
  return c.json({
    error: {
      code: (err as any).code ?? 'INTERNAL_ERROR',
      message: err.message,
      suggestion: (err as any).suggestion ?? 'Check server logs'
    }
  }, (err as any).status ?? 500);
});

app.get('/health', (c) => c.json({ status: 'ok', version: '0.1.0' }));

app.route('/api/v1/foods', foodRoutes);
app.route('/api/v1/food-logs', foodLogRoutes);
app.route('/api/v1/weight', weightRoutes);
app.route('/api/v1/water', waterRoutes);
app.route('/api/v1/sleep', sleepRoutes);
app.route('/api/v1/daily', dailyRoutes);
app.route('/api/v1/targets', targetRoutes);
app.route('/api/v1/stats', statRoutes);
```

---

## Routes

Все routes импортируют из `@htr/engine` и `../db.js`. Все response включают raw + formatted варианты.

### foods.ts — Food Items CRUD + Search

```
GET  /              → list all (+ ?q=search for name search)
GET  /:id           → get by ID
POST /              → create food item
PATCH /:id          → update food item
DELETE /:id         → soft delete
```

**Zod schema:**

```typescript
import { z } from 'zod';

const createFoodSchema = z.object({
  name: z.string().min(1),
  brand: z.string().optional(),
  caloriesPer100g: z.number().int().min(0),
  proteinPer100g: z.number().int().min(0),
  fatPer100g: z.number().int().min(0),
  carbsPer100g: z.number().int().min(0),
  fiberPer100g: z.number().int().min(0).optional(),
  servingSizeG: z.number().int().min(1).optional(),
  barcode: z.string().optional(),
});
```

**GET / response:**

```json
{
  "foods": [
    {
      "id": "abc123",
      "name": "Бешбармак",
      "brand": null,
      "caloriesPer100g": 150,
      "proteinPer100g": 80,
      "proteinFormatted": "8.0 g",
      "fatPer100g": 90,
      "fatFormatted": "9.0 g",
      "carbsPer100g": 100,
      "carbsFormatted": "10.0 g",
      "servingSizeG": 350
    }
  ]
}
```

**Search:** `GET /api/v1/foods?q=беш` → SQL `WHERE name LIKE '%беш%'`

### food-logs.ts — Log Food + Quick Log

```
GET    /?date=YYYY-MM-DD    → food logs for date (grouped by meal) — uses getDailyNutrition
POST   /                    → log food (from food_item + serving_grams) — uses logFood
POST   /quick               → quick-log (inline name+calories) — uses quickLog
DELETE /:id                 → soft delete
```

**POST / Zod schema:**

```typescript
const logFoodSchema = z.object({
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  mealId: z.string(),
  foodItemId: z.string(),
  servingGrams: z.number().int().min(1),
});
```

**POST /quick Zod schema:**

```typescript
const quickLogSchema = z.object({
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  mealId: z.string(),
  name: z.string().min(1),
  calories: z.number().int().min(0),
  protein: z.number().int().min(0).optional(),
  fat: z.number().int().min(0).optional(),
  carbs: z.number().int().min(0).optional(),
});
```

**GET /?date= response:**

```json
{
  "date": "2026-03-09",
  "meals": [
    {
      "meal": { "id": "meal-breakfast", "name": "Breakfast" },
      "entries": [
        {
          "id": "log1",
          "foodName": "Овсянка на воде",
          "servingGrams": 250,
          "calories": 195,
          "caloriesFormatted": "195 kcal",
          "protein": 68,
          "proteinFormatted": "6.8 g",
          "fat": 35,
          "fatFormatted": "3.5 g",
          "carbs": 340,
          "carbsFormatted": "34.0 g"
        }
      ],
      "subtotals": {
        "calories": 195,
        "caloriesFormatted": "195 kcal",
        "protein": 68,
        "proteinFormatted": "6.8 g"
      }
    }
  ],
  "totals": {
    "calories": 1850,
    "caloriesFormatted": "1 850 kcal",
    "protein": 980,
    "proteinFormatted": "98.0 g",
    "fat": 650,
    "fatFormatted": "65.0 g",
    "carbs": 2100,
    "carbsFormatted": "210.0 g"
  },
  "target": {
    "calories": 2150,
    "caloriesFormatted": "2 150 kcal",
    "caloriesProgress": 86
  }
}
```

### weight.ts — Weight Logging & Trend

```
GET    /                     → list entries (+ ?days=30)
GET    /latest               → latest entry + trend
POST   /                     → log weight
DELETE /:id                  → soft delete
```

**POST / Zod schema:**

```typescript
const logWeightSchema = z.object({
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  weightGrams: z.number().int().min(1),
  bodyFat: z.number().int().min(0).max(1000).optional(),
  note: z.string().optional(),
});
```

**GET /latest response:**

```json
{
  "latest": {
    "id": "w1",
    "date": "2026-03-09",
    "weightGrams": 75500,
    "weightFormatted": "75.5 kg",
    "bodyFat": 152,
    "bodyFatFormatted": "15.2%"
  },
  "trend": {
    "trendGrams": 75200,
    "trendFormatted": "75.2 kg",
    "changeGrams": -800,
    "changeFormatted": "-0.8 kg"
  }
}
```

### water.ts — Water Logging

```
GET    /?date=YYYY-MM-DD     → daily water summary
POST   /                     → log water intake
DELETE /:id                  → soft delete
```

**POST / Zod schema:**

```typescript
const logWaterSchema = z.object({
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  amountMl: z.number().int().min(1),
});
```

**GET /?date= response:**

```json
{
  "date": "2026-03-09",
  "totalMl": 1750,
  "totalFormatted": "1.8 L",
  "targetMl": 2500,
  "targetFormatted": "2.5 L",
  "progress": 70,
  "entries": [
    { "id": "w1", "amountMl": 250, "amountFormatted": "250 ml", "createdAt": "..." },
    { "id": "w2", "amountMl": 500, "amountFormatted": "500 ml", "createdAt": "..." },
    { "id": "w3", "amountMl": 1000, "amountFormatted": "1.0 L", "createdAt": "..." }
  ]
}
```

### sleep.ts — Sleep Logging & Trend

```
GET    /?date=YYYY-MM-DD     → sleep entries for date
GET    /trend?days=7         → sleep trend
POST   /                     → log sleep
DELETE /:id                  → soft delete
```

**POST / Zod schema:**

```typescript
const logSleepSchema = z.object({
  startTime: z.string(),          // ISO 8601
  endTime: z.string(),            // ISO 8601
  quality: z.number().int().min(1).max(5).optional(),
  note: z.string().optional(),
});
```

**GET /?date= response:**

```json
{
  "date": "2026-03-09",
  "entries": [
    {
      "id": "s1",
      "startTime": "2026-03-08T23:30:00.000Z",
      "endTime": "2026-03-09T07:15:00.000Z",
      "durationMinutes": 465,
      "durationFormatted": "7h 45m",
      "quality": 4
    }
  ],
  "totalMinutes": 465,
  "totalFormatted": "7h 45m",
  "targetMinutes": 480,
  "targetFormatted": "8h",
  "progress": 97
}
```

### daily.ts — Full Daily Summary

```
GET /:date → full summary: nutrition + water + sleep + weight + targets
```

Ассемблирует данные из всех engines:

```typescript
// Route handler pseudocode:
app.get('/:date', (c) => {
  const date = c.req.param('date');
  const nutrition = getDailyNutrition(db, date);
  const water = getDailyWater(db, date);
  const sleep = getSleepForDate(db, date);
  const weight = /* select from weight_logs where date */;
  const target = getActiveTarget(db, date);

  return c.json({
    date,
    nutrition: formatNutritionResponse(nutrition),
    water: formatWaterResponse(water),
    sleep: formatSleepResponse(sleep, target),
    weight: weight ? formatWeightResponse(weight) : null,
    target: target ? formatTargetResponse(target) : null,
  });
});
```

**GET /2026-03-09 response:**

```json
{
  "date": "2026-03-09",
  "nutrition": {
    "totals": {
      "calories": 1850,
      "caloriesFormatted": "1 850 kcal",
      "caloriesProgress": 86,
      "protein": 980,
      "proteinFormatted": "98.0 g",
      "proteinProgress": 82
    },
    "meals": [ "..." ]
  },
  "water": {
    "totalMl": 1750,
    "totalFormatted": "1.8 L",
    "progress": 70
  },
  "sleep": {
    "totalMinutes": 465,
    "totalFormatted": "7h 45m",
    "progress": 97
  },
  "weight": {
    "weightGrams": 75500,
    "weightFormatted": "75.5 kg"
  },
  "target": {
    "calories": 2150,
    "protein": 1200,
    "fat": 700,
    "carbs": 2500,
    "waterMl": 2500,
    "sleepMinutes": 480
  }
}
```

### targets.ts — Target Management

```
GET  /           → list all targets
GET  /active     → active target for today (or ?date=)
POST /           → set new target
```

**POST / Zod schema:**

```typescript
const setTargetSchema = z.object({
  effectiveDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  calories: z.number().int().min(0),
  protein: z.number().int().min(0),
  fat: z.number().int().min(0),
  carbs: z.number().int().min(0),
  waterMl: z.number().int().min(0).optional(),
  sleepMinutes: z.number().int().min(0).optional(),
});
```

**GET /active response:**

```json
{
  "target": {
    "id": "t1",
    "effectiveDate": "2026-01-01",
    "calories": 2150,
    "caloriesFormatted": "2 150 kcal",
    "protein": 1200,
    "proteinFormatted": "120.0 g",
    "fat": 700,
    "fatFormatted": "70.0 g",
    "carbs": 2500,
    "carbsFormatted": "250.0 g",
    "waterMl": 2500,
    "waterFormatted": "2.5 L",
    "sleepMinutes": 480,
    "sleepFormatted": "8h"
  }
}
```

### stats.ts — Statistics

```
GET /week?date=          → week summary (ISO week, Monday start)
GET /streaks             → current streaks (food, water, sleep)
GET /range?from=&to=     → range averages
GET /weight-trend?days=  → weight trend + EMA
```

**GET /week response:**

```json
{
  "weekStart": "2026-03-02",
  "weekEnd": "2026-03-08",
  "daysLogged": 5,
  "avgCalories": 2050,
  "avgCaloriesFormatted": "2 050 kcal",
  "avgProtein": 1050,
  "avgProteinFormatted": "105.0 g",
  "avgFat": 680,
  "avgFatFormatted": "68.0 g",
  "avgCarbs": 2300,
  "avgCarbsFormatted": "230.0 g",
  "avgWaterMl": 2200,
  "avgWaterFormatted": "2.2 L",
  "avgSleepMinutes": 445,
  "avgSleepFormatted": "7h 25m"
}
```

**GET /streaks response:**

```json
{
  "foodLogging": { "current": 7, "best": 14 },
  "waterGoal": { "current": 3, "best": 10 },
  "sleepGoal": { "current": 5, "best": 8 }
}
```

**GET /weight-trend?days=30 response:**

```json
{
  "entries": [
    { "date": "2026-02-10", "weightGrams": 76000, "weightFormatted": "76.0 kg" },
    { "date": "2026-02-15", "weightGrams": 75800, "weightFormatted": "75.8 kg" },
    { "date": "2026-03-09", "weightGrams": 75500, "weightFormatted": "75.5 kg" }
  ],
  "trendGrams": 75200,
  "trendFormatted": "75.2 kg",
  "changeGrams": -800,
  "changeFormatted": "-0.8 kg"
}
```

---

## Tests: apps/api/tests/api.test.ts

```typescript
import { describe, it, expect, beforeAll } from 'vitest';
import { app } from '../src/app.js';

async function api(method: string, path: string, body?: any) {
  const init: RequestInit = { method, headers: { 'Content-Type': 'application/json' } };
  if (body) init.body = JSON.stringify(body);
  const res = await app.request(path, init);
  return { status: res.status, data: await res.json() };
}

describe('HTR API', () => {
  // ═══════════════════════════════════════
  // Health
  // ═══════════════════════════════════════

  it('health check', async () => {
    const { status, data } = await api('GET', '/health');
    expect(status).toBe(200);
    expect(data.status).toBe('ok');
  });

  // ═══════════════════════════════════════
  // Foods CRUD
  // ═══════════════════════════════════════

  let foodId: string;

  it('create food item', async () => {
    const { status, data } = await api('POST', '/api/v1/foods', {
      name: 'Тест продукт',
      caloriesPer100g: 200,
      proteinPer100g: 100,
      fatPer100g: 80,
      carbsPer100g: 150,
    });
    expect(status).toBe(201);
    expect(data.food.name).toBe('Тест продукт');
    foodId = data.food.id;
  });

  it('list foods', async () => {
    const { data } = await api('GET', '/api/v1/foods');
    expect(data.foods.length).toBeGreaterThan(0);
  });

  it('search foods', async () => {
    const { data } = await api('GET', '/api/v1/foods?q=Тест');
    expect(data.foods.some((f: any) => f.name === 'Тест продукт')).toBe(true);
  });

  // ═══════════════════════════════════════
  // Food Logs
  // ═══════════════════════════════════════

  it('log food', async () => {
    const { status, data } = await api('POST', '/api/v1/food-logs', {
      date: '2026-03-09',
      mealId: 'meal-breakfast',
      foodItemId: foodId,
      servingGrams: 200,
    });
    expect(status).toBe(201);
    expect(data.entry.calories).toBe(400); // 200 * 200/100
  });

  it('quick log', async () => {
    const { status, data } = await api('POST', '/api/v1/food-logs/quick', {
      date: '2026-03-09',
      mealId: 'meal-lunch',
      name: 'Шаурма',
      calories: 450,
      protein: 200,
      fat: 250,
      carbs: 350,
    });
    expect(status).toBe(201);
    expect(data.entry.foodName).toBe('Шаурма');
  });

  it('get food logs for date', async () => {
    const { data } = await api('GET', '/api/v1/food-logs?date=2026-03-09');
    expect(data.meals.length).toBeGreaterThan(0);
    expect(data.totals.calories).toBeGreaterThan(0);
  });

  // ═══════════════════════════════════════
  // Weight
  // ═══════════════════════════════════════

  it('log weight', async () => {
    const { status, data } = await api('POST', '/api/v1/weight', {
      date: '2026-03-09',
      weightGrams: 75500,
      bodyFat: 152,
    });
    expect(status).toBe(201);
    expect(data.entry.weightFormatted).toBe('75.5 kg');
  });

  it('get latest weight', async () => {
    const { data } = await api('GET', '/api/v1/weight/latest');
    expect(data.latest.weightGrams).toBe(75500);
  });

  // ═══════════════════════════════════════
  // Water
  // ═══════════════════════════════════════

  it('log water', async () => {
    const { status } = await api('POST', '/api/v1/water', {
      date: '2026-03-09',
      amountMl: 250,
    });
    expect(status).toBe(201);
  });

  it('get daily water', async () => {
    const { data } = await api('GET', '/api/v1/water?date=2026-03-09');
    expect(data.totalMl).toBe(250);
  });

  // ═══════════════════════════════════════
  // Sleep
  // ═══════════════════════════════════════

  it('log sleep', async () => {
    const { status, data } = await api('POST', '/api/v1/sleep', {
      startTime: '2026-03-08T23:00:00.000Z',
      endTime: '2026-03-09T07:00:00.000Z',
      quality: 4,
    });
    expect(status).toBe(201);
    expect(data.entry.durationMinutes).toBe(480);
  });

  // ═══════════════════════════════════════
  // Daily Summary
  // ═══════════════════════════════════════

  it('get daily summary', async () => {
    const { data } = await api('GET', '/api/v1/daily/2026-03-09');
    expect(data.date).toBe('2026-03-09');
    expect(data.nutrition).toBeDefined();
    expect(data.water).toBeDefined();
    expect(data.sleep).toBeDefined();
  });

  // ═══════════════════════════════════════
  // Targets
  // ═══════════════════════════════════════

  it('set target', async () => {
    const { status } = await api('POST', '/api/v1/targets', {
      effectiveDate: '2026-01-01',
      calories: 2150,
      protein: 1200,
      fat: 700,
      carbs: 2500,
    });
    expect(status).toBe(201);
  });

  it('get active target', async () => {
    const { data } = await api('GET', '/api/v1/targets/active');
    expect(data.target.calories).toBe(2150);
  });

  // ═══════════════════════════════════════
  // Stats
  // ═══════════════════════════════════════

  it('get streaks', async () => {
    const { data } = await api('GET', '/api/v1/stats/streaks');
    expect(data.foodLogging).toBeDefined();
    expect(data.waterGoal).toBeDefined();
  });

  // ═══════════════════════════════════════
  // Error handling
  // ═══════════════════════════════════════

  it('404 for missing food item', async () => {
    const { status, data } = await api('GET', '/api/v1/foods/nonexistent');
    expect(status).toBe(404);
    expect(data.error.code).toBe('NOT_FOUND');
  });

  it('validation error for invalid body', async () => {
    const { status, data } = await api('POST', '/api/v1/foods', {});
    expect(status).toBe(400);
    expect(data.error.code).toBe('VALIDATION_ERROR');
  });
});
```
