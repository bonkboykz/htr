import { Hono } from "hono";
import { z } from "zod";
import {
  logWeight,
  deleteWeightLog,
  getLatestWeight,
  getWeightEntries,
  getWeightTrend,
  formatWeight,
  formatBodyFat,
  type DB,
} from "@htr/engine";

const logWeightSchema = z.object({
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  weightGrams: z.number().int().min(1),
  bodyFat: z.number().int().min(0).optional(),
  note: z.string().optional(),
});

function formatWeightEntry(entry: {
  weightGrams: number;
  bodyFat: number | null;
}) {
  return {
    weightFormatted: formatWeight(entry.weightGrams),
    bodyFatFormatted: entry.bodyFat !== null ? formatBodyFat(entry.bodyFat) : null,
  };
}

export function weightRoutes(db: DB) {
  const app = new Hono();

  // GET / — list weight entries, optional ?days= (default 30)
  app.get("/", (c) => {
    const days = parseInt(c.req.query("days") || "30", 10);
    const entries = getWeightEntries(db, days);
    return c.json(
      entries.map((e) => ({
        ...e,
        ...formatWeightEntry(e),
      }))
    );
  });

  // GET /latest — latest weight entry + trend
  app.get("/latest", (c) => {
    const latest = getLatestWeight(db);
    if (!latest) {
      return c.json(
        {
          error: {
            code: "NOT_FOUND",
            message: "No weight entries found",
            suggestion: "Log your weight first using POST /api/v1/weight",
          },
        },
        404
      );
    }

    const trend = getWeightTrend(db);
    return c.json({
      latest: {
        ...latest,
        ...formatWeightEntry(latest),
      },
      trend: {
        trendGrams: trend.trendGrams,
        trendFormatted: formatWeight(trend.trendGrams),
        changeGrams: trend.changeGrams,
        changeFormatted: formatWeight(Math.abs(trend.changeGrams)),
      },
    });
  });

  // POST / — log weight
  app.post("/", async (c) => {
    const body = await c.req.json();
    const parsed = logWeightSchema.safeParse(body);
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

    const entry = logWeight(db, parsed.data);
    return c.json(
      {
        ...entry,
        ...formatWeightEntry(entry),
      },
      201
    );
  });

  // DELETE /:id — soft delete weight log
  app.delete("/:id", (c) => {
    deleteWeightLog(db, c.req.param("id"));
    return c.json({ success: true });
  });

  return app;
}
