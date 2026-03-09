# Секция 1: Спецификация и архитектура

## Что строим

**HTR** (Health Tracker) — Turborepo монорепо с трекером питания, веса, воды, сна. Engine библиотека + REST API + OpenClaw skill.

### Основная идея

Трекер здоровья с фокусом на нутриенты. Логируешь еду → видишь КБЖУ за день. Следишь за весом, водой, сном. Всё через API — подходит для AI-агентов, ботов, мобильных клиентов.

```
Завтрак:
  Овсянка 200г        → 156 kcal, 5.4g P, 2.8g F, 27.2g C
  Банан 120г           → 107 kcal, 1.3g P, 0.4g F, 27.0g C
Обед:
  Бешбармак 350г       → 525 kcal, 28.0g P, 31.5g F, 35.0g C
Перекус:
  Баурсак 100г         → 360 kcal, 7.0g P, 15.0g F, 50.0g C
                        ─────────
  Итого:                 1 148 kcal | 41.7g P | 49.7g F | 139.2g C
  Цель:                 2 150 kcal | 120.0g P | 70.0g F | 250.0g C
  Осталось:             1 002 kcal | 78.3g P | 20.3g F | 110.8g C
```

### Ключевые сущности

```
food_items       — база продуктов (КБЖУ на 100г), переиспользуемые
  ↓ referenced by
food_logs        — запись: дата + приём пищи + продукт + граммы (pre-computed КБЖУ)
  ↓ grouped by
meals            — приём пищи (Breakfast, Lunch, Dinner, Snack)

weight_logs      — вес по дням (граммы) + body fat
water_logs       — каждый стакан/бутылка отдельно
sleep_logs       — период сна (start/end timestamps, кроссует полночь)

daily_targets    — цели (калории, БЖУ, вода, сон) с effective_date
```

### Что вычисляется, а не хранится

| Поле | Откуда |
|------|--------|
| Daily nutrition totals | `SUM(food_logs)` за дату, группируя по meal |
| Weight trend | Exponential Moving Average по weight_logs |
| Water total | `SUM(water_logs.amount_ml)` за дату |
| Sleep duration | `end_time - start_time` для каждого sleep_log |
| Target lookup | Последний `daily_targets` где `effective_date <= date` |
| Streaks | Последовательные дни с выполненной целью |
| Week averages | `AVG` по всем метрикам за ISO-неделю |

### Pre-computation в food_logs

При логировании еды, КБЖУ вычисляются из `food_item × (serving_grams / 100)` и сохраняются в `food_logs`. Это позволяет быстро агрегировать дневные итоги без JOIN на food_items:

```typescript
calories = Math.round(foodItem.caloriesPer100g * servingGrams / 100);
protein  = Math.round(foodItem.proteinPer100g  * servingGrams / 100);
fat      = Math.round(foodItem.fatPer100g      * servingGrams / 100);
carbs    = Math.round(foodItem.carbsPer100g    * servingGrams / 100);
fiber    = Math.round(foodItem.fiberPer100g    * servingGrams / 100);
```

---

## Tech Stack

| Компонент | Технология | Обоснование |
|-----------|-----------|-------------|
| Monorepo | **Turborepo + pnpm workspaces** | Кэширование, параллельные билды |
| Runtime | **Node.js 22** | LTS, стабильный |
| Package manager | **pnpm** | Быстрый, strict, workspace protocol |
| TS execution | **tsx** | Запуск TypeScript без компиляции |
| Framework | **Hono + @hono/node-server** | Минималистичный, type-safe |
| ORM | **Drizzle + better-sqlite3** | Type-safe SQL, zero-ops SQLite |
| Database | **SQLite (better-sqlite3)** | Zero ops, проверенная native библиотека |
| Validation | **Zod** | Единая схема для API + types |
| IDs | **cuid2** | URL-safe, sortable |
| Testing | **Vitest** | Быстрый, Jest-совместимый |

---

## Monorepo Structure

```
htr/
├── apps/
│   └── api/                        # Hono REST server
│       ├── src/
│       │   ├── routes/
│       │   │   ├── foods.ts
│       │   │   ├── food-logs.ts
│       │   │   ├── weight.ts
│       │   │   ├── water.ts
│       │   │   ├── sleep.ts
│       │   │   ├── daily.ts
│       │   │   ├── targets.ts
│       │   │   └── stats.ts
│       │   ├── errors.ts
│       │   ├── app.ts
│       │   ├── db.ts
│       │   └── index.ts
│       ├── tests/
│       │   └── api.test.ts
│       ├── package.json
│       └── tsconfig.json
│
├── packages/
│   ├── engine/                     # @htr/engine — core library
│   │   ├── src/
│   │   │   ├── db/
│   │   │   │   ├── schema.ts
│   │   │   │   ├── index.ts
│   │   │   │   ├── migrate.ts
│   │   │   │   └── seed.ts
│   │   │   ├── nutrition/
│   │   │   │   └── engine.ts
│   │   │   ├── weight/
│   │   │   │   └── engine.ts
│   │   │   ├── water/
│   │   │   │   └── engine.ts
│   │   │   ├── sleep/
│   │   │   │   └── engine.ts
│   │   │   ├── stats/
│   │   │   │   └── engine.ts
│   │   │   ├── targets/
│   │   │   │   └── engine.ts
│   │   │   ├── format/
│   │   │   │   └── index.ts
│   │   │   └── index.ts
│   │   ├── tests/
│   │   │   ├── nutrition.test.ts
│   │   │   ├── weight.test.ts
│   │   │   ├── water.test.ts
│   │   │   ├── sleep.test.ts
│   │   │   ├── stats.test.ts
│   │   │   └── format.test.ts
│   │   ├── vitest.config.ts
│   │   ├── package.json
│   │   └── tsconfig.json
│   │
│   └── skill/                      # OpenClaw skill (curl-based)
│       ├── SKILL.md
│       └── _meta.json
│
├── docs/                           # These spec files
├── turbo.json
├── pnpm-workspace.yaml
├── package.json
├── tsconfig.json
├── CLAUDE.md
├── Dockerfile
└── .gitignore
```

### Зависимости

```
@htr/engine (packages/engine)
  ├── drizzle-orm + better-sqlite3
  ├── zod, @paralleldrive/cuid2

@htr/api (apps/api)
  ├── @htr/engine (workspace:*)
  ├── hono + @hono/node-server
```

---

## Единицы хранения

| Домен | Единица хранения | Пример |
|-------|-----------------|--------|
| Weight | граммы (int) | 75.5 kg → `75500` |
| Calories | kcal (int) | 2150 kcal → `2150` |
| Macros | десятые грамма (int) | 25.3 g → `253` |
| Water | мл (int) | 250 мл → `250` |
| Body fat | промилле (int) | 15.2% → `152` |
| Sleep | ISO timestamps | длительность вычисляется |

Правила:
- Форматирование: `formatWeight()`, `formatMacro()`, `formatWater()` и др. — **только** на уровне API response
- Никогда не используй `float` для нутриентов — только integer math
- Soft delete: `is_deleted = true` (никогда физическое удаление)

---

## System IDs

Фиксированные, никогда не меняются:

| ID | Назначение |
|----|-----------|
| `"meal-breakfast"` | Завтрак |
| `"meal-lunch"` | Обед |
| `"meal-dinner"` | Ужин |
| `"meal-snack"` | Перекус |

---

## CLAUDE.md

Полный CLAUDE.md уже существует в корне проекта. Он содержит:
- Структуру проекта и tech stack
- Все таблицы БД (7 штук) с SQL
- Engine pattern (db injection)
- API routes таблицу
- Response format
- Formatting functions
- OpenClaw skill команды
- Build order и Docker
