---
name: htr-health
description: >
  Health tracking via REST API. Track calories, macros, weight, water intake,
  sleep, daily targets, streaks, TDEE calculation and weight goals. Use when
  user asks about food logging, калории, макросы, "сколько съел", weight
  tracking, вес, water intake, вода, sleep tracking, сон, nutrition goals,
  КБЖУ, TDEE, "сколько калорий нужно", цель по весу.
version: 0.3.0
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
