import { Hono } from "hono";
import { z } from "zod";
import {
  logWater,
  deleteWaterLog,
  getDailyWater,
  formatWater,
  formatProgress,
  type DB,
} from "@htr/engine";

const logWaterSchema = z.object({
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  amountMl: z.number().int().min(1),
});

export function waterRoutes(db: DB) {
  const app = new Hono();

  // GET /?date= — daily water summary
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

    const water = getDailyWater(db, date);
    return c.json({
      date,
      totalMl: water.totalMl,
      totalFormatted: formatWater(water.totalMl),
      targetMl: water.targetMl,
      targetFormatted: formatWater(water.targetMl),
      progress: formatProgress(water.totalMl, water.targetMl),
      entries: water.entries.map((e) => ({
        ...e,
        amountFormatted: formatWater(e.amountMl),
      })),
    });
  });

  // POST / — log water intake
  app.post("/", async (c) => {
    const body = await c.req.json();
    const parsed = logWaterSchema.safeParse(body);
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

    const entry = logWater(db, parsed.data);
    return c.json(
      {
        ...entry,
        amountFormatted: formatWater(entry.amountMl),
      },
      201
    );
  });

  // DELETE /:id — soft delete water log
  app.delete("/:id", (c) => {
    deleteWaterLog(db, c.req.param("id"));
    return c.json({ success: true });
  });

  return app;
}
