import { Hono } from "hono";
import { z } from "zod";
import {
  setTarget,
  getActiveTarget,
  listTargets,
  formatCalories,
  formatMacro,
  formatWater,
  formatSleep,
  type DB,
} from "@htr/engine";

const setTargetSchema = z.object({
  effectiveDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  calories: z.number().int().min(0),
  protein: z.number().int().min(0),
  fat: z.number().int().min(0),
  carbs: z.number().int().min(0),
  waterMl: z.number().int().min(0).optional(),
  sleepMinutes: z.number().int().min(0).optional(),
});

function formatTarget(target: {
  calories: number;
  protein: number;
  fat: number;
  carbs: number;
  waterMl: number;
  sleepMinutes: number;
}) {
  return {
    caloriesFormatted: formatCalories(target.calories),
    proteinFormatted: formatMacro(target.protein),
    fatFormatted: formatMacro(target.fat),
    carbsFormatted: formatMacro(target.carbs),
    waterMlFormatted: formatWater(target.waterMl),
    sleepFormatted: formatSleep(target.sleepMinutes),
  };
}

export function targetsRoutes(db: DB) {
  const app = new Hono();

  // GET / — list all targets
  app.get("/", (c) => {
    const targets = listTargets(db);
    return c.json(
      targets.map((t) => ({
        ...t,
        ...formatTarget(t),
      }))
    );
  });

  // GET /active — active target for today
  app.get("/active", (c) => {
    const today = new Date().toISOString().split("T")[0];
    const target = getActiveTarget(db, today);
    if (!target) {
      return c.json(
        {
          error: {
            code: "NOT_FOUND",
            message: "No active target found",
            suggestion: "Set a target first using POST /api/v1/targets",
          },
        },
        404
      );
    }
    return c.json({
      ...target,
      ...formatTarget(target),
    });
  });

  // POST / — set new target
  app.post("/", async (c) => {
    const body = await c.req.json();
    const parsed = setTargetSchema.safeParse(body);
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

    const target = setTarget(db, parsed.data);
    return c.json(
      {
        ...target,
        ...formatTarget(target),
      },
      201
    );
  });

  return app;
}
