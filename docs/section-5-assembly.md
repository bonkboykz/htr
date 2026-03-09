# Секция 5: Сборочный промпт + OpenClaw Skill + Deploy

## Как использовать

### Вариант A: Пошагово (рекомендуется)

```
Сессия 1: Промпт из section-2 → monorepo init, packages/engine (schema, db, seed)
Сессия 2: Промпт из section-3 → packages/engine (engines, formatting, tests)
Сессия 3: Промпт из section-4 → apps/api (routes, tests, manual verify)
```

### Вариант B: Один проход

Используй единый промпт ниже.

---

## Подготовка

```bash
mkdir htr && cd htr
mkdir docs
# Скопируй section-1 через section-5 .md файлы в docs/
# Скопируй CLAUDE.md в корень
```

---

## Единый сборочный промпт

```
Read ALL files in docs/ directory in order: section-1 through section-5.

Build the HTR project — Turborepo monorepo, Node 22, pnpm.

### Phase 1: Monorepo Scaffolding

1. pnpm-workspace.yaml (packages/*, apps/*)
2. Root package.json (name: htr, private, turbo scripts)
3. pnpm add -Dw turbo typescript
4. turbo.json (build, dev, test, db:migrate, db:seed tasks)
5. tsconfig.base.json (ES2022, bundler, strict, declaration)

### Phase 2: packages/engine — Database

6. package.json: @htr/engine, deps: drizzle-orm, better-sqlite3, zod, cuid2
   DevDeps: drizzle-kit, @types/better-sqlite3, tsx, vitest, typescript
7. tsconfig.json extending ../../tsconfig.base.json
8. vitest.config.ts
9. src/db/schema.ts — ALL 7 tables from section-2
10. src/db/index.ts — better-sqlite3, WAL, FK, createDb() with :memory: support
11. src/db/migrate.ts
12. src/db/seed.ts — system meals + kazakh foods + sample target
13. pnpm install && pnpm db:migrate && pnpm db:seed

### Phase 3: packages/engine — Engines

14. src/format/index.ts — all formatting functions (formatCalories, formatMacro, formatWeight, formatWater, formatSleep, formatBodyFat, formatProgress)
15. src/nutrition/engine.ts — logFood, getDailyNutrition, quickLog
16. src/weight/engine.ts — logWeight, getLatestWeight, getWeightTrend (EMA)
17. src/water/engine.ts — logWater, getDailyWater
18. src/sleep/engine.ts — logSleep, getSleepForDate, getSleepTrend
19. src/stats/engine.ts — getWeekSummary, getStreaks, getRangeStats
20. src/targets/engine.ts — getActiveTarget, setTarget
21. src/index.ts — re-export everything
22. tests/format.test.ts
23. tests/nutrition.test.ts (createDb(':memory:'))
24. tests/weight.test.ts
25. tests/water.test.ts
26. tests/sleep.test.ts
27. tests/stats.test.ts
28. cd packages/engine && pnpm test — fix all failures

### Phase 4: apps/api

29. package.json: @htr/api, deps: @htr/engine workspace:*, hono, @hono/node-server
    DevDeps: tsx, vitest, typescript
30. tsconfig.json, vitest.config.ts
31. src/db.ts — createDb with env var
32. src/errors.ts — AppError
33. src/app.ts — Hono + CORS + logger + error handler + all 8 route files
34. src/routes/foods.ts — CRUD + search
35. src/routes/food-logs.ts — log, quick-log, delete
36. src/routes/weight.ts — log, latest, trend, delete
37. src/routes/water.ts — log, daily summary, delete
38. src/routes/sleep.ts — log, trend, delete
39. src/routes/daily.ts — full daily summary (assembles all engines)
40. src/routes/targets.ts — list, active, create
41. src/routes/stats.ts — week, streaks, range, weight-trend
42. src/index.ts — serve() from @hono/node-server
43. tests/api.test.ts
44. pnpm test — fix all failures

### Phase 5: Verify

45. pnpm db:migrate && pnpm db:seed
46. pnpm test (all packages)
47. pnpm dev
48. curl http://localhost:3000/health
49. curl http://localhost:3000/api/v1/foods
50. curl http://localhost:3000/api/v1/targets/active
51. Fix ANY errors.

### Rules
- Node 22 + tsx (NOT Bun)
- better-sqlite3 (NOT bun:sqlite)
- Vitest (NOT bun test / jest)
- @hono/node-server serve() (NOT export default)
- Every engine function takes db: DB as first param
- Integer math for all nutritional values
- System meals: "meal-breakfast", "meal-lunch", "meal-dinner", "meal-snack"
- Food log macros are pre-computed at write time
- Soft delete everywhere (is_deleted = true)
- Weight in grams, macros in tenths of grams, body fat in permille
```

---

## OpenClaw Skill: packages/skill/SKILL.md

Скилл учит OpenClaw-агента работать с **задеплоенным REST API** через curl.

### packages/skill/_meta.json

```json
{
  "name": "htr-health",
  "version": "0.1.0",
  "description": "Health & nutrition tracker via REST API. Log food, weight, water, sleep. Track calories, macros, streaks."
}
```

### packages/skill/SKILL.md

```yaml
---
name: htr-health
description: >
  Health & nutrition tracker via REST API. Log food (calories, protein, fat, carbs),
  weight, water, sleep. Track daily targets, streaks, trends. Use when user asks
  about calories, nutrition, "сколько я съел", weight tracking, water intake,
  sleep quality, macros, КБЖУ, диета.
version: 0.1.0
metadata:
  openclaw:
    emoji: "🏥"
    requires:
      bins: [curl, jq]
      env: [HTR_API_URL]
    primaryEnv: HTR_API_URL
---

# HTR Health Tracker

Nutrition, weight, water, and sleep tracking via REST API.

**API Base**: `$HTR_API_URL` (e.g. `http://localhost:3000`)

---

## Health Check

```bash
curl -s "$HTR_API_URL/health" | jq
```

---

## Food Items

### Search food database

```bash
curl -s "$HTR_API_URL/api/v1/foods?q=курица" | jq
```

### Create food item

```bash
curl -s -X POST "$HTR_API_URL/api/v1/foods" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Куриная грудка",
    "caloriesPer100g": 165,
    "proteinPer100g": 310,
    "fatPer100g": 36,
    "carbsPer100g": 0
  }' | jq
```

Values: calories in kcal, macros in tenths of grams (31.0g protein = 310).

---

## Food Logging

### Log food (from food database)

```bash
curl -s -X POST "$HTR_API_URL/api/v1/food-logs" \
  -H "Content-Type: application/json" \
  -d '{
    "date": "2026-03-09",
    "mealId": "meal-lunch",
    "foodItemId": "FOOD_ITEM_ID",
    "servingGrams": 200
  }' | jq
```

Meal IDs: `meal-breakfast`, `meal-lunch`, `meal-dinner`, `meal-snack`

### Quick log (no food item needed)

```bash
curl -s -X POST "$HTR_API_URL/api/v1/food-logs/quick" \
  -H "Content-Type: application/json" \
  -d '{
    "date": "2026-03-09",
    "mealId": "meal-lunch",
    "name": "Шаурма",
    "calories": 450,
    "protein": 200,
    "fat": 250,
    "carbs": 350
  }' | jq
```

### Get daily nutrition

```bash
curl -s "$HTR_API_URL/api/v1/food-logs?date=2026-03-09" | jq
```

Returns meals grouped with subtotals, overall totals, and target progress.

---

## Weight

### Log weight

```bash
curl -s -X POST "$HTR_API_URL/api/v1/weight" \
  -H "Content-Type: application/json" \
  -d '{
    "date": "2026-03-09",
    "weightGrams": 75500,
    "bodyFat": 152
  }' | jq
```

Weight in grams (75.5 kg = 75500). Body fat in permille (15.2% = 152), optional.

### Get latest weight + trend

```bash
curl -s "$HTR_API_URL/api/v1/weight/latest" | jq
```

### Weight trend (EMA smoothed)

```bash
curl -s "$HTR_API_URL/api/v1/stats/weight-trend?days=30" | jq
```

---

## Water

### Log water

```bash
curl -s -X POST "$HTR_API_URL/api/v1/water" \
  -H "Content-Type: application/json" \
  -d '{
    "date": "2026-03-09",
    "amountMl": 250
  }' | jq
```

### Daily water summary

```bash
curl -s "$HTR_API_URL/api/v1/water?date=2026-03-09" | jq
```

Returns total, target, progress percentage, and individual entries.

---

## Sleep

### Log sleep

```bash
curl -s -X POST "$HTR_API_URL/api/v1/sleep" \
  -H "Content-Type: application/json" \
  -d '{
    "startTime": "2026-03-08T23:30:00.000Z",
    "endTime": "2026-03-09T07:15:00.000Z",
    "quality": 4
  }' | jq
```

Timestamps in ISO 8601. Quality 1-5, optional.

### Sleep trend

```bash
curl -s "$HTR_API_URL/api/v1/sleep/trend?days=7" | jq
```

---

## Daily Summary

### Full day overview

```bash
curl -s "$HTR_API_URL/api/v1/daily/2026-03-09" | jq
```

Returns nutrition + water + sleep + weight + targets — all in one response.

---

## Targets

### Get active target

```bash
curl -s "$HTR_API_URL/api/v1/targets/active" | jq
```

### Set new target

```bash
curl -s -X POST "$HTR_API_URL/api/v1/targets" \
  -H "Content-Type: application/json" \
  -d '{
    "effectiveDate": "2026-03-01",
    "calories": 2000,
    "protein": 1500,
    "fat": 650,
    "carbs": 2000,
    "waterMl": 3000,
    "sleepMinutes": 480
  }' | jq
```

Macros in tenths of grams (150.0g protein = 1500).

---

## Statistics

### Week summary

```bash
curl -s "$HTR_API_URL/api/v1/stats/week?date=2026-03-09" | jq
```

### Streaks

```bash
curl -s "$HTR_API_URL/api/v1/stats/streaks" | jq
```

Returns current and best streaks for food logging, water goal, sleep goal.

### Range statistics

```bash
curl -s "$HTR_API_URL/api/v1/stats/range?from=2026-03-01&to=2026-03-09" | jq
```

---

## Units Convention

- **Calories**: integer kcal (2150 kcal = `2150`)
- **Macros**: tenths of grams (25.3g = `253`)
- **Weight**: grams (75.5 kg = `75500`)
- **Water**: ml (250 ml = `250`)
- **Body fat**: permille (15.2% = `152`)
- **Sleep**: ISO timestamps, duration in minutes

Response fields include both raw and formatted strings:
- `calories: 2150` + `caloriesFormatted: "2 150 kcal"`
- `protein: 253` + `proteinFormatted: "25.3 g"`
- `weightGrams: 75500` + `weightFormatted: "75.5 kg"`

## Error Responses

```json
{
  "error": {
    "code": "NOT_FOUND",
    "message": "Food item 'abc123' not found",
    "suggestion": "Use GET /api/v1/foods to list available IDs"
  }
}
```

## Typical Workflows

### "Сколько я съел сегодня?"
1. `GET /api/v1/food-logs?date=2026-03-09` → show totals and progress

### "Запиши 200г куриной грудки на обед"
1. `GET /api/v1/foods?q=курица` → find food item ID
2. `POST /api/v1/food-logs` → log 200g

### "Запиши стакан воды"
1. `POST /api/v1/water` → 250ml today

### "Как мой вес за последний месяц?"
1. `GET /api/v1/stats/weight-trend?days=30` → trend with EMA

### "Как я сегодня в целом?"
1. `GET /api/v1/daily/2026-03-09` → full summary
```

---

## Deploy (для работы скилла)

API нужно задеплоить, чтобы `HTR_API_URL` был доступен агенту.

### Вариант 1: Локально

```bash
cd htr
pnpm install && pnpm db:migrate && pnpm db:seed
pnpm dev
# HTR_API_URL=http://localhost:3000
```

### Вариант 2: Railway

```bash
railway init
railway up
# HTR_API_URL=https://htr-production-xxx.up.railway.app
```

### Вариант 3: VPS

```bash
git clone ... && cd htr
pnpm install && pnpm db:migrate && pnpm db:seed
PORT=3000 pnpm start
# Reverse proxy через nginx/caddy
```

### Dockerfile

```dockerfile
FROM node:22-slim
WORKDIR /app
COPY . .
RUN corepack enable && pnpm install --frozen-lockfile && pnpm build
ENV PORT=3000 DATABASE_PATH=/data/htr.db
EXPOSE 3000
CMD ["node", "apps/api/dist/index.js"]
```

Volume: `/data` для persistent SQLite database.

### OpenClaw configuration

```json
// ~/.openclaw/openclaw.json
{
  "skills": {
    "entries": {
      "htr-health": {
        "enabled": true,
        "env": {
          "HTR_API_URL": "http://localhost:3000"
        }
      }
    }
  }
}
```

---

## .gitignore

```
node_modules/
dist/
data/
*.db
*.db-wal
*.db-shm
.env
.turbo/
```

---

## Полная структура

```
htr/
├── CLAUDE.md
├── package.json
├── pnpm-workspace.yaml
├── pnpm-lock.yaml
├── turbo.json
├── tsconfig.json
├── Dockerfile
├── .gitignore
│
├── docs/
│   ├── section-1-spec.md
│   ├── section-2-schema.md
│   ├── section-3-engines.md
│   ├── section-4-rest-api.md
│   └── section-5-assembly.md
│
├── packages/
│   ├── engine/                   # @htr/engine
│   │   ├── src/
│   │   │   ├── db/               # schema, index, migrate, seed
│   │   │   ├── nutrition/        # logFood, getDailyNutrition, quickLog
│   │   │   ├── weight/           # logWeight, getLatestWeight, getWeightTrend
│   │   │   ├── water/            # logWater, getDailyWater
│   │   │   ├── sleep/            # logSleep, getSleepForDate, getSleepTrend
│   │   │   ├── stats/            # getWeekSummary, getStreaks, getRangeStats
│   │   │   ├── targets/          # getActiveTarget, setTarget
│   │   │   ├── format/           # formatting functions
│   │   │   └── index.ts
│   │   ├── tests/
│   │   ├── vitest.config.ts
│   │   ├── package.json
│   │   └── tsconfig.json
│   │
│   └── skill/                    # OpenClaw skill
│       ├── SKILL.md              # curl-based instructions
│       └── _meta.json
│
├── apps/
│   └── api/                      # @htr/api
│       ├── src/
│       │   ├── routes/           # foods, food-logs, weight, water, sleep, daily, targets, stats
│       │   ├── errors.ts
│       │   ├── app.ts
│       │   ├── db.ts
│       │   └── index.ts
│       ├── tests/
│       ├── vitest.config.ts
│       ├── package.json
│       └── tsconfig.json
│
└── data/                         # gitignored
    └── htr.db
```

---

## Post-MVP Ideas

### Barcode Scan
```
Add barcode lookup to food_items.
Integrate with Open Food Facts API.
POST /api/v1/foods/barcode/:code → lookup or create food item.
```

### Meal Planning
```
Add meal_plans table.
Plan meals for the week ahead.
Auto-generate shopping list from planned meals.
```

### Recipe Import
```
Parse recipes from URLs (schema.org Recipe format).
Auto-calculate per-serving nutrition.
POST /api/v1/foods/import-recipe → create food item from URL.
```

### Progress Photos
```
Add progress_photos table.
Upload photos with date + weight.
Compare side-by-side over time.
```

### Export / Analytics
```
Export all data as CSV/JSON.
Monthly/quarterly health reports.
Correlation analysis (sleep vs weight, etc.).
```
