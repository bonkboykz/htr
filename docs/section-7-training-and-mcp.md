# Секция 7 — Домен Training + MCP-сервер

> **Статус:** реализовано. Расширяет HTR доменом силовых тренировок и добавляет
> MCP-слой для AI-клиентов (Claude Desktop и любой MCP-клиент).
>
> Наследует принципы HTR: целочисленное хранение (вес снаряда в граммах),
> вычисляемое не храним (объём, e1RM, длительность), soft delete, DI через
> `db: DB`, форматирование только на слое ответа API.

---

## 1. Единицы

| Величина        | Хранение              | Пример   | Формат в ответе |
|-----------------|-----------------------|----------|-----------------|
| Вес снаряда     | **граммы (int)**      | `52500`  | `52.5 kg`       |
| Повторы         | int                   | `10`     | `10`            |
| RIR             | int (0–5)             | `2`      | —               |
| Время сессии    | ISO start/end         | —        | `duration_s`    |
| Объём (вычисл.) | не храним `SUM(weight_g*reps)` | — | `1.45 t` / `1450 kg` |
| e1RM (вычисл.)  | не храним (Epley)     | —        | `kg`            |

Шаги прогрессии (`min_increment_g`): верх тела `2500`, низ тела `5000`.

---

## 2. Схема БД (5 таблиц, миграция `0003`)

- `exercises` — каталог упражнений (`muscle_group`, `pattern`, `equipment` (JSON),
  `is_safe_lower_back`, `min_increment_g`, `video_query`, `cues_ru`, …).
- `routines` — шаблоны A / B (`name`, `name_ru`, `notes`, `sort_order`).
- `routine_exercises` — состав шаблона (`section` warmup|main|reab, `sort_order`,
  `target_sets`, `rep_min`, `rep_max`, `target_rir`, `is_rampup_scaled`).
- `workout_sessions` — фактические тренировки (`session_index` 1..10, `started_at`,
  `ended_at`).
- `set_logs` — подходы (`weight_g`, `reps`, `rir`, `is_warmup`).

Индексы: `set_logs(exercise_id, created_at)`, `workout_sessions(routine_id, started_at)`,
`routine_exercises(routine_id, section, sort_order)`.

**Seed** (`seedTraining`, идемпотентный): программа A/B — 18 упражнений, 2 рутины,
24 позиции. ID стабильные: `ex-<key>` (напр. `ex-bench_press`), `routine-a`, `routine-b`.

---

## 3. Прогрессия (детерминированное ядро)

`suggestProgression(db, exerciseId, sessionIndex?)` — double progression, **в БД не пишет**,
считает по последним рабочим (не разминочным) подходам:

```
ramp-up (session_index ≤ 3):     action="rampup",  вес ≈ 65% рабочего, rir_target 4  (веса НЕ растим)
все сеты reps ≥ rep_max И rir ≤ target:  action="increase", вес +min_increment_g, reps→rep_min
есть сет reps < rep_min (провал): action="deload_or_hold", вес прежний
иначе:                           action="hold", вес прежний, +повторы к rep_max
нет истории:                     action="hold", вес 0 (начни с комфортного)
```

- **e1RM (Epley):** `round(weight_g * (1 + reps / 30))`.
- **Ротация A/B:** `getToday` берёт следующую рутину по последней сессии; `session_index`
  = `(последний % 10) + 1` (сброс блока каждые 10). `is_rampup = session_index ≤ 3`.
- **AI-override:** ручка/инструмент override — *advisory* в v1 (не персистится): движок
  возвращает своё предложение + предложение AI с `reason`; реализуется, когда подход
  логируется с этим весом.

---

## 4. REST API — `/api/v1/training/*`

Авторизация — общий `Authorization: Bearer $HTR_API_KEY` (как у всех `/api/v1/*`).
Вход валидируется Zod (snake_case), вес на выходе форматируется (`*Formatted`).

### Горячий путь
| Метод  | Путь | Назначение |
|--------|------|------------|
| `GET`  | `/today` | `{ routine_id, session_index, is_rampup }` |
| `GET`  | `/routines/:id/plan?sessionIndex=` | весь экран: план + `lastPerformance` + `suggestion` по каждому упражнению |
| `POST` | `/sessions` | старт → `{ session_id, session_index }` |
| `POST` | `/sessions/:id/sets` | записать подход → `{ set_id }` |
| `POST` | `/sessions/:id/sets/quick` | повторить прошлый подход (`{ exercise_id }`) |
| `PATCH`| `/sessions/:id` | закрыть (`{ ended_at?, notes? }`) → `{ duration_s }` |

### Аналитика
| Метод | Путь | Назначение |
|-------|------|------------|
| `GET` | `/progression/:exerciseId?range=week\|month` (или `?from=&to=`) | история + тренд e1RM |
| `GET` | `/stats/volume?range=week` | объём `SUM(weight_g*reps)` по `muscle_group` |
| `GET` | `/sessions?range=` | список сессий (частота, объём, длительность) |

### Правки плана
| Метод | Путь | Назначение |
|-------|------|------------|
| `PATCH` | `/routines/:id/exercises/:reId` | сменить упражнение / сеты / диапазон / RIR (постоянно) |
| `POST`  | `/progression/:exerciseId/override` | AI-override (advisory): возвращает `engineSuggestion` + `override` |

### Примеры

```bash
# Что сегодня
curl -s -H "$AUTH" "$HTR_API_URL/api/v1/training/today" | jq

# Экран тренировки (с подсказками прогрессии)
curl -s -H "$AUTH" "$HTR_API_URL/api/v1/training/routines/routine-a/plan?sessionIndex=6" | jq

# Старт → лог подхода → закрытие
SID=$(curl -s -X POST "$HTR_API_URL/api/v1/training/sessions" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"routine_id":"routine-a"}' | jq -r .session_id)

curl -s -X POST "$HTR_API_URL/api/v1/training/sessions/$SID/sets" \
  -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"exercise_id":"ex-bench_press","set_number":1,"weight_g":52500,"reps":10,"rir":2}' | jq

curl -s -X PATCH "$HTR_API_URL/api/v1/training/sessions/$SID" \
  -H "$AUTH" -H "Content-Type: application/json" -d '{}' | jq

# Прогрессия жима за месяц
curl -s -H "$AUTH" "$HTR_API_URL/api/v1/training/progression/ex-bench_press?range=month" | jq
```

Вес снаряда — в **граммах** (`52500` = 52.5 кг). `is_warmup` по умолчанию `false`,
`rir` опционален (может быть `null` для разминочных).

---

## 5. MCP-сервер (`@htr/mcp`)

Оборачивает `@htr/engine` в типизированные MCP-инструменты. Работает с той же БД
напрямую (свой инстанс `db`), а не через REST.

### Транспорты
- **stdio** (по умолчанию): `MCP_TRANSPORT` не задан → `apps/mcp/src/index.ts`.
- **streamable-http**: `MCP_TRANSPORT=http` → слушает `PORT` (по умолч. 3001), путь `/mcp`.
- **Remote-эндпоинт в проде:** встроен в сервис `api` — `POST /mcp/:token`
  (`token = HTR_API_KEY`), делит ту же БД на volume `/data`. Используется Claude Desktop.

### Инструменты (17) по уровням доступа

**READ (свободно):**
`get_daily_summary {date}`, `get_weight_trend {days?}`, `get_progression {exercise_id, from?, to?}`,
`get_volume_stats {from?, to?, range?}`, `list_sessions {from?, to?, range?}`,
`get_routine_plan {routine_id, session_index?}`, `get_today {}`, `get_tdee {date?}`.

**WRITE (питание/тело):**
`log_food {date, mealId, foodItemId, servingGrams}`,
`log_weight {date, weightGrams, bodyFat?, note?}`,
`log_sleep {startTime, endTime, quality?, note?}`, `log_water {date, amountMl}`.

**WRITE (тренировки):**
`start_session {routine_id, session_index?}`,
`log_set {session_id, exercise_id, set_number, weight_g, reps, rir?, is_warmup?}`,
`end_session {session_id, ended_at?, notes?}`.

**SENSITIVE (постоянные правки плана):**
`patch_routine_exercise {routine_exercise_id, exercise_id?, target_sets?, rep_min?, rep_max?, target_rir?, notes?}`,
`override_progression {exercise_id, weight_g, reason}` (advisory).

### Подключение Claude Desktop (remote)

Ничего локально запускать не нужно — MCP развёрнут в сервисе `api` на Railway.

1. Claude Desktop → **Settings → Connectors → Add custom connector**.
2. URL: `https://<railway-host>/mcp/<HTR_API_KEY>`
3. Save → сервер `htr` с 17 инструментами.

> 🔐 Токен = `HTR_API_KEY` в URL: доступ к данным как у REST API. Для более строгой
> схемы позже — OAuth или отдельный ротируемый MCP-токен.

### Пример сценария (планирование на месяц)
> «Собери программу на месяц: возьми мою прогрессию (`get_progression`), объём по
> группам (`get_volume_stats`), частоту/сессии (`list_sessions`), тренд веса
> (`get_weight_trend`), TDEE (`get_tdee`) — и предложи прогрессию по доказательной
> методике.» Точечные правки шаблона — `patch_routine_exercise`.

---

## 6. Переменные окружения

| Переменная      | Где            | Назначение |
|-----------------|----------------|------------|
| `HTR_API_KEY`   | api, MCP       | Bearer для `/api/v1/*` и токен для `/mcp/:token` |
| `DATABASE_PATH` | api, MCP       | путь к SQLite (`/data/htr.db` в проде) |
| `MCP_TRANSPORT` | `@htr/mcp`     | `http` для streamable-http; иначе stdio |
| `PORT`          | api / MCP http | порт |
