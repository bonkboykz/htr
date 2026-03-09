# Section 6 — Факторы и Корреляции (Спецификация)

> **Статус**: Только спецификация. Реализация в будущей версии.

---

## Обзор

Система факторов позволяет трекать произвольные параметры (настроение, симптомы, привычки, лекарства) и находить корреляции между ними и данными HTR (калории, макросы, вода, сон, вес).

---

## 1. Схема БД — 3 новые таблицы

### `factor_categories`

Категории для группировки факторов.

```sql
CREATE TABLE factor_categories (
  id         TEXT PRIMARY KEY,              -- cuid2
  name       TEXT NOT NULL,                 -- "Настроение", "Симптомы", etc.
  emoji      TEXT,                          -- optional emoji icon
  sort_order INTEGER NOT NULL DEFAULT 0,
  is_system  INTEGER NOT NULL DEFAULT 0,    -- 1 for pre-seeded categories
  is_deleted INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
```

**Seed data (system categories):**
```
("cat-mood",     "Настроение",  "😊", 1, 1)
("cat-symptoms", "Симптомы",    "🤒", 2, 1)
("cat-habits",   "Привычки",    "✅", 3, 1)
("cat-meds",     "Лекарства",   "💊", 4, 1)
("cat-other",    "Другое",      "📝", 5, 1)
```

### `factors`

Трекаемые элементы с настраиваемой шкалой.

```sql
CREATE TABLE factors (
  id          TEXT PRIMARY KEY,              -- cuid2
  category_id TEXT NOT NULL REFERENCES factor_categories(id),
  name        TEXT NOT NULL,                 -- "Энергия", "Головная боль", etc.
  scale_min   INTEGER NOT NULL DEFAULT 0,    -- min value (usually 0 or 1)
  scale_max   INTEGER NOT NULL DEFAULT 5,    -- max value
  labels      TEXT,                          -- JSON: {"1": "Ужасно", "5": "Отлично"} nullable
  unit        TEXT,                          -- nullable, e.g. "mg", "минут"
  is_deleted  INTEGER NOT NULL DEFAULT 0,
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);
```

### `factor_logs`

Ежедневные записи значений факторов.

```sql
CREATE TABLE factor_logs (
  id         TEXT PRIMARY KEY,              -- cuid2
  date       TEXT NOT NULL,                 -- YYYY-MM-DD
  factor_id  TEXT NOT NULL REFERENCES factors(id),
  value      INTEGER NOT NULL,              -- значение в рамках шкалы
  note       TEXT,                          -- optional note
  is_deleted INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
```

**Constraint**: один лог на `(date, factor_id)` — UNIQUE.

---

## 2. Типы

```typescript
interface FactorCategory {
  id: string;
  name: string;
  emoji: string | null;
  sortOrder: number;
  isSystem: number;
  isDeleted: number;
  createdAt: string;
}

interface Factor {
  id: string;
  categoryId: string;
  name: string;
  scaleMin: number;
  scaleMax: number;
  labels: Record<string, string> | null;
  unit: string | null;
  isDeleted: number;
  createdAt: string;
}

interface FactorLog {
  id: string;
  date: string;
  factorId: string;
  value: number;
  note: string | null;
  isDeleted: number;
  createdAt: string;
}

interface DataSeries {
  source: string;   // "factor:{id}" | "htr:calories" | "htr:protein" | etc.
  points: { date: string; value: number }[];
}

interface Correlation {
  seriesA: string;
  seriesB: string;
  coefficient: number;    // Spearman rho, -1 to 1
  pValue: number;
  significance: "high" | "medium" | "low" | "none";
  dataPoints: number;
}

interface CorrelationMatrix {
  series: string[];
  correlations: Correlation[];
}
```

---

## 3. Factor Engine

Файл: `packages/engine/src/factors/engine.ts`

```typescript
// Categories
createCategory(db, { name, emoji? }) → FactorCategory
listCategories(db) → FactorCategory[]
deleteCategory(db, id) → void  // soft delete

// Factors
createFactor(db, { categoryId, name, scaleMin?, scaleMax?, labels?, unit? }) → Factor
listFactors(db, categoryId?) → Factor[]
deleteFactor(db, id) → void  // soft delete

// Logging
logFactor(db, { date, factorId, value, note? }) → FactorLog
  // UPSERT: обновляет если уже есть лог на эту дату + фактор
  // Валидация: value >= scaleMin && value <= scaleMax

bulkLogFactors(db, { date, entries: { factorId, value, note? }[] }) → FactorLog[]
  // Логирует несколько факторов за один раз

getFactorLogsForDate(db, date) → { category: FactorCategory, factors: { factor: Factor, log: FactorLog | null }[] }[]
  // Группировка по категориям, показывает все факторы с логами (или null)

getFactorHistory(db, factorId, days?) → FactorLog[]
  // История значений одного фактора
```

---

## 4. Correlation Engine

Файл: `packages/engine/src/correlations/engine.ts`

### DataSeries источники

| Source ID | Описание | Как получить |
|-----------|----------|-------------|
| `factor:{id}` | Значение фактора | factor_logs WHERE factor_id = id |
| `htr:calories` | Дневные калории | SUM(food_logs.calories) GROUP BY date |
| `htr:protein` | Дневной протеин | SUM(food_logs.protein) GROUP BY date |
| `htr:fat` | Дневной жир | SUM(food_logs.fat) GROUP BY date |
| `htr:carbs` | Дневные углеводы | SUM(food_logs.carbs) GROUP BY date |
| `htr:water-ml` | Дневная вода | SUM(water_logs.amount_ml) GROUP BY date |
| `htr:sleep-minutes` | Длительность сна | computed from sleep_logs |
| `htr:weight-grams` | Вес | weight_logs.weight_grams |

### Алгоритм: Spearman Rank Correlation

```typescript
function getDataSeries(db, source: string, from: string, to: string): DataSeries

function calculateSpearmanCorrelation(seriesA: DataSeries, seriesB: DataSeries): Correlation
  // 1. Найти общие даты (inner join по date)
  // 2. Минимум 7 общих точек, иначе return null
  // 3. Ранжировать значения каждой серии
  // 4. Вычислить rho = 1 - (6 * Σd²) / (n * (n² - 1))
  // 5. Вычислить p-value через t-distribution:
  //    t = rho * sqrt((n-2) / (1 - rho²))
  //    df = n - 2
  // 6. Определить significance:
  //    p < 0.01 → "high"
  //    p < 0.05 → "medium"
  //    p < 0.10 → "low"
  //    else → "none"

function getCorrelationMatrix(
  db,
  sources: string[],
  from: string,
  to: string
): CorrelationMatrix
  // Вычислить корреляции для всех пар серий
```

### Обработка связей (tied ranks)

При одинаковых значениях — средний ранг:
```
values:  [3, 1, 3, 2]
sorted:  [1, 2, 3, 3]
ranks:   [1, 2, 3.5, 3.5]  // 3 и 4 позиции → (3+4)/2 = 3.5
```

### t-distribution приближение

Для df > 3 использовать нормальное приближение или таблицу критических значений. Для точного расчёта можно использовать библиотеку (e.g., `jstat`) или lookup table.

---

## 5. API Routes

### Factor Categories — `/api/v1/factor-categories`

| Method | Path | Описание |
|--------|------|----------|
| GET | `/api/v1/factor-categories` | Список категорий |
| POST | `/api/v1/factor-categories` | Создать категорию |
| DELETE | `/api/v1/factor-categories/:id` | Soft delete |

### Factors — `/api/v1/factors`

| Method | Path | Описание |
|--------|------|----------|
| GET | `/api/v1/factors` | Список факторов (+ `?categoryId=`) |
| POST | `/api/v1/factors` | Создать фактор |
| DELETE | `/api/v1/factors/:id` | Soft delete |

### Factor Logs — `/api/v1/factor-logs`

| Method | Path | Описание |
|--------|------|----------|
| GET | `/api/v1/factor-logs?date=` | Логи за дату (группировка по категориям) |
| POST | `/api/v1/factor-logs` | Записать значение фактора |
| POST | `/api/v1/factor-logs/bulk` | Записать несколько факторов |
| GET | `/api/v1/factor-logs/history?factorId=&days=` | История одного фактора |
| DELETE | `/api/v1/factor-logs/:id` | Soft delete |

### Correlations — `/api/v1/correlations`

| Method | Path | Описание |
|--------|------|----------|
| GET | `/api/v1/correlations?seriesA=&seriesB=&from=&to=` | Корреляция двух серий |
| POST | `/api/v1/correlations/matrix` | Матрица корреляций для набора серий |

#### Пример запроса матрицы корреляций

```bash
curl -s -X POST "$HTR_API_URL/api/v1/correlations/matrix" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{
    "sources": ["factor:energy-id", "htr:calories", "htr:sleep-minutes"],
    "from": "2026-01-01",
    "to": "2026-03-09"
  }' | jq
```

#### Пример ответа

```json
{
  "series": ["factor:energy-id", "htr:calories", "htr:sleep-minutes"],
  "correlations": [
    {
      "seriesA": "factor:energy-id",
      "seriesB": "htr:sleep-minutes",
      "coefficient": 0.72,
      "pValue": 0.003,
      "significance": "high",
      "dataPoints": 28
    },
    {
      "seriesA": "factor:energy-id",
      "seriesB": "htr:calories",
      "coefficient": 0.31,
      "pValue": 0.12,
      "significance": "none",
      "dataPoints": 28
    },
    {
      "seriesA": "htr:calories",
      "seriesB": "htr:sleep-minutes",
      "coefficient": -0.15,
      "pValue": 0.44,
      "significance": "none",
      "dataPoints": 28
    }
  ]
}
```

---

## 6. Интеграция с DailySummary

Добавить в ответ `GET /api/v1/daily/:date`:

```json
{
  "factors": [
    {
      "category": { "id": "cat-mood", "name": "Настроение", "emoji": "😊" },
      "entries": [
        {
          "factor": { "id": "...", "name": "Энергия", "scaleMax": 5 },
          "value": 4,
          "note": null
        }
      ]
    }
  ]
}
```

---

## 7. Тесты

### Factor Engine
- CRUD категорий
- CRUD факторов
- logFactor: валидация min/max, upsert behavior
- bulkLogFactors
- getFactorLogsForDate: группировка

### Correlation Engine
- Spearman с известными данными (проверка rho)
- Обработка tied ranks
- Минимум 7 точек — возврат null при недостатке данных
- p-value и significance thresholds
- getDataSeries для всех источников

### API Tests
- CRUD factor categories, factors, factor logs
- Bulk logging
- Correlation endpoint с тестовыми данными
- Matrix correlation

---

## 8. Файлы для реализации

| Файл | Действие |
|------|----------|
| `packages/engine/src/db/schema.ts` | Edit — 3 таблицы |
| `packages/engine/src/types.ts` | Edit — 6 типов |
| `packages/engine/src/factors/engine.ts` | Create |
| `packages/engine/src/correlations/engine.ts` | Create |
| `packages/engine/src/index.ts` | Edit — экспорты |
| `apps/api/src/routes/factor-categories.ts` | Create |
| `apps/api/src/routes/factors.ts` | Create |
| `apps/api/src/routes/factor-logs.ts` | Create |
| `apps/api/src/routes/correlations.ts` | Create |
| `apps/api/src/routes/daily.ts` | Edit — добавить factors |
| `apps/api/src/app.ts` | Edit — mount routes |
| `packages/engine/tests/factors.test.ts` | Create |
| `packages/engine/tests/correlations.test.ts` | Create |
| `apps/api/tests/api.test.ts` | Edit — new routes |
