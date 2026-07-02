---
name: htr-health
description: >
  Health tracking via REST API. Track calories, macros, weight, water intake,
  sleep, daily targets, streaks, TDEE calculation, weight goals and strength
  training (workouts, sets, progression). Use when user asks about food logging,
  калории, макросы, "сколько съел", weight tracking, вес, water intake, вода,
  sleep tracking, сон, nutrition goals, КБЖУ, TDEE, "сколько калорий нужно",
  цель по весу, тренировки, workout, подходы, прогрессия, жим, объём, e1RM,
  "начни тренировку", "запиши подход", факторы, привычки, настроение, симптомы,
  корреляции, зависимости, insights, "связь пиво и сон", habit tracking.
version: 0.6.0
metadata:
  openclaw:
    emoji: "🏋️"
    requires:
      bins: [curl, jq]
      env: [HTR_API_URL, HTR_API_KEY]
    primaryEnv: HTR_API_URL
---

# HTR Health Tracker

Calorie/macro/weight/water/sleep tracking via REST API.

**API Base**: `$HTR_API_URL` (e.g. `http://localhost:3000`)

**Auth Header** (required when `HTR_API_KEY` is set):
```bash
AUTH="Authorization: Bearer $HTR_API_KEY"
```

---

## Health Check

```bash
curl -s "$HTR_API_URL/health" | jq
```

---

## Food Items

### List / search food items

```bash
# All items
curl -s -H "$AUTH" "$HTR_API_URL/api/v1/foods" | jq

# Search by name
curl -s -H "$AUTH" "$HTR_API_URL/api/v1/foods?q=chicken" | jq
```

### Get single food item

```bash
curl -s -H "$AUTH" "$HTR_API_URL/api/v1/foods/{id}" | jq
```

### Create food item

```bash
curl -s -X POST "$HTR_API_URL/api/v1/foods" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{
    "name": "Chicken Breast",
    "caloriesPer100g": 165,
    "proteinPer100g": 310,
    "fatPer100g": 36,
    "carbsPer100g": 0,
    "fiberPer100g": 0,
    "servingSizeG": 150
  }' | jq
```

Macros are in **tenths of grams** (31.0g protein = `310`).

### Update food item

```bash
curl -s -X PATCH "$HTR_API_URL/api/v1/foods/{id}" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"brand": "Local Farm"}' | jq
```

### Delete food item

```bash
curl -s -X DELETE -H "$AUTH" "$HTR_API_URL/api/v1/foods/{id}" | jq
```

---

## Food Logs

### Get food logs for a date

```bash
curl -s -H "$AUTH" "$HTR_API_URL/api/v1/food-logs?date=2026-03-09" | jq
```

Returns food logs grouped by meal with totals.

### Log food (from food item)

```bash
curl -s -X POST "$HTR_API_URL/api/v1/food-logs" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{
    "date": "2026-03-09",
    "mealId": "meal-lunch",
    "foodItemId": "FOOD_ITEM_ID",
    "servingGrams": 200
  }' | jq
```

Meal IDs: `meal-breakfast`, `meal-lunch`, `meal-dinner`, `meal-snack`

### Quick log (inline, auto-creates food item)

```bash
curl -s -X POST "$HTR_API_URL/api/v1/food-logs/quick" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{
    "date": "2026-03-09",
    "mealId": "meal-snack",
    "name": "Protein Bar",
    "calories": 220,
    "protein": 200,
    "fat": 80,
    "carbs": 250
  }' | jq
```

Macros are optional, in **tenths of grams**.

### Delete food log

```bash
curl -s -X DELETE -H "$AUTH" "$HTR_API_URL/api/v1/food-logs/{id}" | jq
```

---

## Weight

### List weight entries

```bash
# Default last 30 days
curl -s -H "$AUTH" "$HTR_API_URL/api/v1/weight" | jq

# Custom range
curl -s -H "$AUTH" "$HTR_API_URL/api/v1/weight?days=60" | jq
```

### Get latest weight + trend

```bash
curl -s -H "$AUTH" "$HTR_API_URL/api/v1/weight/latest" | jq
```

### Log weight

```bash
curl -s -X POST "$HTR_API_URL/api/v1/weight" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{
    "date": "2026-03-09",
    "weightGrams": 75500,
    "bodyFat": 152,
    "note": "Morning weigh-in"
  }' | jq
```

Weight in **grams** (75.5 kg = `75500`). Body fat in **permille** (15.2% = `152`). Both `bodyFat` and `note` are optional. One entry per date (UNIQUE constraint).

### Delete weight entry

```bash
curl -s -X DELETE -H "$AUTH" "$HTR_API_URL/api/v1/weight/{id}" | jq
```

---

## Water

### Get daily water summary

```bash
curl -s -H "$AUTH" "$HTR_API_URL/api/v1/water?date=2026-03-09" | jq
```

Returns `totalMl`, `targetMl`, and individual entries.

### Log water intake

```bash
curl -s -X POST "$HTR_API_URL/api/v1/water" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{
    "date": "2026-03-09",
    "amountMl": 250
  }' | jq
```

### Delete water entry

```bash
curl -s -X DELETE -H "$AUTH" "$HTR_API_URL/api/v1/water/{id}" | jq
```

---

## Sleep

### Get sleep entries for a date

```bash
curl -s -H "$AUTH" "$HTR_API_URL/api/v1/sleep?date=2026-03-09" | jq
```

### Get sleep trend

```bash
curl -s -H "$AUTH" "$HTR_API_URL/api/v1/sleep/trend?days=7" | jq
```

### Log sleep

```bash
curl -s -X POST "$HTR_API_URL/api/v1/sleep" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{
    "startTime": "2026-03-08T23:30:00",
    "endTime": "2026-03-09T07:15:00",
    "quality": 4,
    "note": "Slept well"
  }' | jq
```

Uses ISO 8601 timestamps (handles cross-midnight). `quality` (1-5) and `note` are optional.

### Delete sleep entry

```bash
curl -s -X DELETE -H "$AUTH" "$HTR_API_URL/api/v1/sleep/{id}" | jq
```

---

## Daily Summary

### Get full daily summary

```bash
curl -s -H "$AUTH" "$HTR_API_URL/api/v1/daily/2026-03-09" | jq
```

Returns combined nutrition + water + sleep + weight + targets for one date.

---

## Targets

### List all targets

```bash
curl -s -H "$AUTH" "$HTR_API_URL/api/v1/targets" | jq
```

### Get active target for today

```bash
curl -s -H "$AUTH" "$HTR_API_URL/api/v1/targets/active" | jq
```

### Set new target

```bash
curl -s -X POST "$HTR_API_URL/api/v1/targets" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{
    "effectiveDate": "2026-03-01",
    "calories": 2150,
    "protein": 1600,
    "fat": 700,
    "carbs": 2200,
    "waterMl": 2500,
    "sleepMinutes": 480
  }' | jq
```

Macros in **tenths of grams**. `waterMl` defaults to 2500, `sleepMinutes` defaults to 480 (8h).

---

## Stats

### Week summary

```bash
curl -s -H "$AUTH" "$HTR_API_URL/api/v1/stats/week?date=2026-03-09" | jq
```

### Current streaks

```bash
curl -s -H "$AUTH" "$HTR_API_URL/api/v1/stats/streaks" | jq
```

### Range stats (averages + daily breakdown + compliance)

```bash
curl -s -H "$AUTH" "$HTR_API_URL/api/v1/stats/range?from=2026-03-01&to=2026-03-09" | jq
```

Returns averages, plus `days` array (per-day calories/protein/fat/carbs/water/sleep) for mini-charts, and `compliance` object (how many days user hit each target, with rates 0-100). `compliance` is `null` if no target is set.

### Weight trend + EMA

```bash
curl -s -H "$AUTH" "$HTR_API_URL/api/v1/stats/weight-trend?days=30" | jq
```

---

## Profile

### Set profile

```bash
curl -s -X PUT "$HTR_API_URL/api/v1/profile" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"heightCm": 178, "birthDate": "1998-05-15", "sex": "male", "activityLevel": "moderate"}' | jq
```

Activity levels: `sedentary`, `light`, `moderate`, `active`, `very_active`

### Get profile

```bash
curl -s -H "$AUTH" "$HTR_API_URL/api/v1/profile" | jq
```

### Get TDEE

```bash
curl -s -H "$AUTH" "$HTR_API_URL/api/v1/profile/tdee" | jq
```

Returns BMR (Mifflin-St Jeor), TDEE, target calories (adjusted for weight goal deficit), and deficit.

---

## Weight Goals

### Set weight goal

```bash
curl -s -X POST "$HTR_API_URL/api/v1/goals/weight" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"targetGrams": 70000, "pace": "normal"}' | jq
```

Pace: `slow` (0.25 kg/week), `normal` (0.5 kg/week), `fast` (1.0 kg/week). Requires at least one weight log entry.

### Get goal progress

```bash
curl -s -H "$AUTH" "$HTR_API_URL/api/v1/goals/weight" | jq
```

Returns progress %, estimated days left, estimated completion date, and TDEE calculation.

### Delete weight goal

```bash
curl -s -X DELETE -H "$AUTH" "$HTR_API_URL/api/v1/goals/weight/{id}" | jq
```

---

## Training (Workouts)

Strength training: sessions, sets, and deterministic double-progression.
Seeded program A/B — routines `routine-a` / `routine-b`, exercises `ex-<key>`
(e.g. `ex-bench_press`, `ex-leg_press`). Weight in **grams** (52.5 kg = `52500`).

### What's on today (A/B rotation + ramp-up)

```bash
curl -s -H "$AUTH" "$HTR_API_URL/api/v1/training/today" | jq
```

Returns `{ routine_id, session_index, is_rampup }`. Ramp-up = first 3 sessions of a block.

### Full workout screen (plan + last performance + suggestion)

```bash
curl -s -H "$AUTH" "$HTR_API_URL/api/v1/training/routines/routine-a/plan?sessionIndex=6" | jq
```

Each main exercise carries `lastPerformance` (prior working sets) and a `suggestion`
(`increase` / `hold` / `deload_or_hold` / `rampup`) with target weight & reps.

### Start a session

```bash
curl -s -X POST "$HTR_API_URL/api/v1/training/sessions" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"routine_id": "routine-a"}' | jq
```

`session_index` is derived if omitted. Returns `{ session_id, session_index }`.
Pass `started_at` (full ISO 8601, user's local timezone) to backdate a past workout, e.g. `{"routine_id": "routine-a", "started_at": "2026-06-03T09:00:00Z"}`.

### Log a set

```bash
curl -s -X POST "$HTR_API_URL/api/v1/training/sessions/{session_id}/sets" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{
    "exercise_id": "ex-bench_press",
    "set_number": 1,
    "weight_g": 52500,
    "reps": 10,
    "rir": 2
  }' | jq
```

`weight_g` in **grams**. `rir` (0-5) optional. `is_warmup` defaults to `false`.

### Quick-repeat the last set

```bash
curl -s -X POST "$HTR_API_URL/api/v1/training/sessions/{session_id}/sets/quick" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"exercise_id": "ex-bench_press"}' | jq
```

### End a session

```bash
curl -s -X PATCH "$HTR_API_URL/api/v1/training/sessions/{session_id}" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"notes": "good session"}' | jq
```

Returns `{ duration_s }`. `ended_at` defaults to now.

### Progression history (e1RM trend)

```bash
curl -s -H "$AUTH" "$HTR_API_URL/api/v1/training/progression/ex-bench_press?range=month" | jq
```

`range=week|month`, or `?from=YYYY-MM-DD&to=YYYY-MM-DD`, or omit for all-time.
Uses Epley e1RM = `weight_g * (1 + reps/30)`.

### Volume by muscle group

```bash
curl -s -H "$AUTH" "$HTR_API_URL/api/v1/training/stats/volume?range=week" | jq
```

### Session history

```bash
curl -s -H "$AUTH" "$HTR_API_URL/api/v1/training/sessions?range=month" | jq
```

### Edit a routine exercise (persistent plan change)

```bash
curl -s -X PATCH "$HTR_API_URL/api/v1/training/routines/routine-a/exercises/{reId}" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"target_sets": 4, "rep_max": 12}' | jq
```

Fields: `exercise_id`, `target_sets`, `rep_min`, `rep_max`, `target_rir`, `notes` (all optional).

### Override the suggested weight (advisory)

```bash
curl -s -X POST "$HTR_API_URL/api/v1/training/progression/ex-bench_press/override" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"exercise_id": "ex-bench_press", "weight_g": 50000, "reason": "недосып + дефицит"}' | jq
```

Advisory in v1 (not persisted): returns the engine's `suggestion` + your `override`.
It is realized when you log the set at that weight.

### Authoring a program (CRUD)

Build/edit the whole program — custom exercises, routines and their composition.

```bash
# Exercises
curl -s -H "$AUTH" "$HTR_API_URL/api/v1/training/exercises?q=press&muscleGroup=chest" | jq
curl -s -X POST "$HTR_API_URL/api/v1/training/exercises" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"name":"Incline DB Press","name_ru":"Жим гантелей в наклоне","muscle_group":"chest","pattern":"h_press","equipment":["db","bench"],"min_increment_g":2500}' | jq
curl -s -X PATCH "$HTR_API_URL/api/v1/training/exercises/{id}" -H "$AUTH" -H "Content-Type: application/json" -d '{"cues_ru":"локти 45°"}' | jq
curl -s -X DELETE -H "$AUTH" "$HTR_API_URL/api/v1/training/exercises/{id}" | jq

# Routines + composition
curl -s -X POST "$HTR_API_URL/api/v1/training/routines" -H "$AUTH" -H "Content-Type: application/json" -d '{"name":"Workout C","name_ru":"Тренировка C","notes":"push"}' | jq
curl -s -H "$AUTH" "$HTR_API_URL/api/v1/training/routines/{routineId}/exercises" | jq
curl -s -X POST "$HTR_API_URL/api/v1/training/routines/{routineId}/exercises" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"exercise_id":"ex-bench_press","section":"main","target_sets":3,"rep_min":8,"rep_max":10,"target_rir":2}' | jq
curl -s -X DELETE -H "$AUTH" "$HTR_API_URL/api/v1/training/routines/{routineId}/exercises/{reId}" | jq
curl -s -X DELETE -H "$AUTH" "$HTR_API_URL/api/v1/training/routines/{routineId}" | jq
```

### Delete logs & record deviations

```bash
# Soft-delete a mislogged set or a whole session
curl -s -X DELETE -H "$AUTH" "$HTR_API_URL/api/v1/training/sessions/{sid}/sets/{setId}" | jq
curl -s -X DELETE -H "$AUTH" "$HTR_API_URL/api/v1/training/sessions/{sid}" | jq

# Record a substitution + read adherence ("how often I deviate")
curl -s -X POST "$HTR_API_URL/api/v1/training/sessions/{sid}/overrides" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"routine_exercise_id":"{reId}","replaced_exercise_id":"ex-pec_deck","reason":"скамья занята"}' | jq
curl -s -H "$AUTH" "$HTR_API_URL/api/v1/training/stats/adherence?range=month" | jq
```

---

## MCP (AI clients / Claude Desktop)

The same engine is exposed as **34 typed MCP tools** (`@htr/mcp`) for AI clients,
including full program authoring (create/edit exercises, routines, composition).
In production the MCP is served by the `api` service at `POST /mcp/<HTR_API_KEY>`
(streamable-http, same database). Connect from Claude Desktop via **Settings →
Connectors → Add custom connector** with URL `$HTR_API_URL/mcp/<HTR_API_KEY>`.

Tiers: **READ** (summaries, trends, progression, volume, sessions, plan, exercise/routine
catalog, overrides, adherence), **WRITE** (`log_food/weight/sleep/water`), **WRITE_TRAINING**
(`start_session`, `log_set`, `end_session`, `delete_set`, `delete_session`, `record_override`),
**SENSITIVE** (`patch_routine_exercise`, `override_progression`, and authoring:
`create/update/delete_exercise`, `create/update/delete_routine`, `add/delete_routine_exercise`).
See `docs/section-7-training-and-mcp.md` for full details.

---

## Factors & Correlations (Bearable-style)

Track arbitrary daily factors (mood, symptoms, habits, meds), then find **associations**
(not causation) with any other HTR series. Each factor has a `kind`: **`rating`** (bounded
scale, e.g. mood 1–5) or **`count`** (unbounded tally, e.g. `factor-alcohol` «порций»,
`factor-caffeine` «чашек» — log 10 beers just fine). Seeded factors: `factor-alcohol`,
`factor-caffeine` (count); `factor-energy`, `factor-mood`, `factor-stress`, `factor-headache`
(rating). Categories `cat-mood/symptoms/habits/meds/other`. Create a count factor with
`{"...","kind":"count","unit":"шт"}`.

### List factors / categories

```bash
curl -s -H "$AUTH" "$HTR_API_URL/api/v1/factor-categories" | jq
curl -s -H "$AUTH" "$HTR_API_URL/api/v1/factors?categoryId=cat-habits" | jq
```

### Log a factor for a date (upsert on date+factor)

```bash
curl -s -X POST "$HTR_API_URL/api/v1/factor-logs" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"date":"2026-05-01","factorId":"factor-alcohol","value":2,"note":"2 пива"}' | jq

# Log several at once
curl -s -X POST "$HTR_API_URL/api/v1/factor-logs/bulk" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"date":"2026-05-01","entries":[{"factorId":"factor-energy","value":4},{"factorId":"factor-stress","value":2}]}' | jq
```

Value must be within the factor's `scaleMin..scaleMax`. `GET /api/v1/factor-logs?date=` returns
the day grouped by category; `GET /api/v1/factor-logs/history?factorId=&days=` returns history.

### Correlations & insights

```bash
# Available series (factor:* + htr:calories/protein/fat/carbs/water-ml/sleep-minutes/weight-grams/training-volume)
curl -s -H "$AUTH" "$HTR_API_URL/api/v1/correlations/sources" | jq

# Pairwise Spearman with a lag (beer today → sleep next night = lag 1)
curl -s -H "$AUTH" "$HTR_API_URL/api/v1/correlations?seriesA=factor:factor-alcohol&seriesB=htr:sleep-minutes&from=2026-05-01&to=2026-05-31&lag=1" | jq

# Matrix over several series
curl -s -X POST "$HTR_API_URL/api/v1/correlations/matrix" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"sources":["factor:factor-alcohol","htr:sleep-minutes","htr:training-volume"],"from":"2026-05-01","to":"2026-05-31","lag":1}' | jq

# Group comparison: "on days with the factor, metric ±%"
curl -s -X POST "$HTR_API_URL/api/v1/correlations/group" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"factorSource":"factor:factor-alcohol","metricSource":"htr:sleep-minutes","from":"2026-05-01","to":"2026-05-31","lag":1}' | jq

# Auto insights (top significant associations, association-framed)
curl -s -H "$AUTH" "$HTR_API_URL/api/v1/correlations/insights?from=2026-05-01&to=2026-05-31" | jq
```

⚠️ Output is **association with a confidence level** (`significance` + `dataPoints`), never causation.
Needs ≥7 shared days. Sleep is attributed to the wake date, so "X today → sleep tonight" = `lag 1`.

---

## Units Convention

All values stored as **integers** to avoid floating-point errors:

| Domain   | Storage unit    | Example                |
|----------|-----------------|------------------------|
| Weight   | grams (int)     | 75.5 kg → `75500`     |
| Calories | kcal (int)      | 2150 kcal → `2150`    |
| Macros   | tenths of grams | 25.3 g → `253`        |
| Water    | ml (int)        | 250 ml → `250`        |
| Body fat | permille (int)  | 15.2% → `152`         |
| Sleep    | ISO timestamps  | duration computed      |

Response fields include both raw and formatted variants:
- `calories: 2150` + `caloriesFormatted: "2 150 kcal"`
- `protein: 253` + `proteinFormatted: "25.3 g"`
- `weightGrams: 75500` + `weightFormatted: "75.5 kg"`
- `waterMl: 2100` + `waterFormatted: "2.1 L"`

## Error Responses

```json
{
  "error": {
    "code": "NOT_FOUND",
    "message": "Food item 'abc123' not found",
    "suggestion": "Use GET /api/v1/foods to list available items"
  }
}
```

---

## Typical Workflows

### "Сколько я съел сегодня?"
1. `GET /api/v1/daily/2026-03-09` → show nutrition totals vs targets

### "Записать завтрак: овсянка 200г"
1. `GET /api/v1/foods?q=овсянка` → find food item ID
2. `POST /api/v1/food-logs` → log with servingGrams=200, mealId=meal-breakfast

### "Быстро записать перекус — протеин бар 220 ккал"
1. `POST /api/v1/food-logs/quick` → quick log with name + calories

### "Сколько воды выпил?"
1. `GET /api/v1/water?date=2026-03-09` → show totalMl vs targetMl

### "Записать стакан воды"
1. `POST /api/v1/water` → log 250ml

### "Сколько я вешу / тренд веса?"
1. `GET /api/v1/weight/latest` → latest + EMA trend

### "Как я спал?"
1. `GET /api/v1/sleep?date=2026-03-09` → sleep entries + duration

### "Покажи итоги за неделю"
1. `GET /api/v1/stats/week?date=2026-03-09` → weekly averages

### "Сколько калорий мне нужно есть?"
1. `GET /api/v1/profile/tdee` → targetCalories

### "Сколько калорий осталось сегодня?" / "How many calories left?"
1. `GET /api/v1/daily/YYYY-MM-DD` → `caloriesBudget.remainingCalories`
   - Shows remaining calories and progress toward daily target
   - If negative, user exceeded their target

### "Как далеко до цели по весу?"
1. `GET /api/v1/goals/weight` → прогресс + estimated date

### "Насколько я дисциплинирован?" / "Compliance за неделю"
1. `GET /api/v1/stats/range?from=2026-03-03&to=2026-03-09` → `compliance` object with rates per metric

### "Начни тренировку A"
1. `GET /api/v1/training/today` → confirm routine + session_index
2. `POST /api/v1/training/sessions` → `{ session_id }`
3. `GET /api/v1/training/routines/routine-a/plan?sessionIndex=` → показать план + подсказки

### "Запиши жим 52.5 на 10, 10, 9"
1. `POST /api/v1/training/sessions/{id}/sets` × N (weight_g=52500, reps 10/10/9)

### "Как идёт жим за месяц?"
1. `GET /api/v1/training/progression/ex-bench_press?range=month` → тренд e1RM

### "Объём за неделю по группам мышц"
1. `GET /api/v1/training/stats/volume?range=week` → `byGroup`

### "Заверши тренировку"
1. `PATCH /api/v1/training/sessions/{id}` → `{ duration_s }`

### "Собери программу на месяц" (через MCP / Claude Desktop)
1. `get_progression`, `get_volume_stats`, `list_sessions`, `get_weight_trend`, `get_tdee` → собрать контекст
2. Предложить прогрессию; точечные правки шаблона — `patch_routine_exercise`
