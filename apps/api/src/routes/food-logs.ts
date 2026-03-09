import { Hono } from "hono";
import { z } from "zod";
import {
  logFood,
  quickLog,
  deleteFoodLog,
  getDailyNutrition,
  formatCalories,
  formatMacro,
  formatProgress,
  type DB,
} from "@htr/engine";

const logFoodSchema = z.object({
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  mealId: z.string().min(1),
  foodItemId: z.string().min(1),
  servingGrams: z.number().int().min(1),
});

const quickLogSchema = z.object({
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  mealId: z.string().min(1),
  name: z.string().min(1),
  calories: z.number().int().min(0),
  protein: z.number().int().min(0).optional(),
  fat: z.number().int().min(0).optional(),
  carbs: z.number().int().min(0).optional(),
  fiber: z.number().int().min(0).optional(),
});

function formatEntry(entry: {
  calories: number;
  protein: number;
  fat: number;
  carbs: number;
  fiber: number;
}) {
  return {
    caloriesFormatted: formatCalories(entry.calories),
    proteinFormatted: formatMacro(entry.protein),
    fatFormatted: formatMacro(entry.fat),
    carbsFormatted: formatMacro(entry.carbs),
    fiberFormatted: formatMacro(entry.fiber),
  };
}

export function foodLogsRoutes(db: DB) {
  const app = new Hono();

  // GET /?date= — get daily nutrition grouped by meal
  app.get("/", (c) => {
    const date = c.req.query("date");
    if (!date) {
      return c.json(
        {
          error: {
            code: "VALIDATION_ERROR",
            message: "date query parameter is required",
            suggestion: "Provide a date in YYYY-MM-DD format, e.g. ?date=2026-03-09",
          },
        },
        400
      );
    }

    const nutrition = getDailyNutrition(db, date);

    const formattedMeals = nutrition.meals.map((mg) => ({
      meal: mg.meal,
      entries: mg.entries.map((e) => ({
        ...e,
        ...formatEntry(e),
      })),
    }));

    const totalsFormatted = formatEntry(nutrition.totals);

    const response: Record<string, unknown> = {
      date: nutrition.date,
      meals: formattedMeals,
      totals: {
        ...nutrition.totals,
        ...totalsFormatted,
      },
      target: nutrition.target,
    };

    if (nutrition.target) {
      response.progress = {
        calories: formatProgress(nutrition.totals.calories, nutrition.target.calories),
        protein: formatProgress(nutrition.totals.protein, nutrition.target.protein),
        fat: formatProgress(nutrition.totals.fat, nutrition.target.fat),
        carbs: formatProgress(nutrition.totals.carbs, nutrition.target.carbs),
      };
    }

    return c.json(response);
  });

  // POST / — log food
  app.post("/", async (c) => {
    const body = await c.req.json();
    const parsed = logFoodSchema.safeParse(body);
    if (!parsed.success) {
      return c.json(
        {
          error: {
            code: "VALIDATION_ERROR",
            message: parsed.error.issues.map((i) => i.message).join(", "),
            suggestion: "Check the request body and try again",
          },
        },
        400
      );
    }

    try {
      const entry = logFood(db, parsed.data);
      return c.json({ ...entry, ...formatEntry(entry) }, 201);
    } catch (err) {
      const message = err instanceof Error ? err.message : "Unknown error";
      return c.json(
        {
          error: {
            code: "BAD_REQUEST",
            message,
            suggestion: "Check that the food item and meal IDs exist",
          },
        },
        400
      );
    }
  });

  // POST /quick — quick log
  app.post("/quick", async (c) => {
    const body = await c.req.json();
    const parsed = quickLogSchema.safeParse(body);
    if (!parsed.success) {
      return c.json(
        {
          error: {
            code: "VALIDATION_ERROR",
            message: parsed.error.issues.map((i) => i.message).join(", "),
            suggestion: "Check the request body and try again",
          },
        },
        400
      );
    }

    const entry = quickLog(db, parsed.data);
    return c.json({ ...entry, ...formatEntry(entry) }, 201);
  });

  // DELETE /:id — soft delete food log
  app.delete("/:id", (c) => {
    deleteFoodLog(db, c.req.param("id"));
    return c.json({ success: true });
  });

  return app;
}
