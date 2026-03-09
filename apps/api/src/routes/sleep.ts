import { Hono } from "hono";
import { z } from "zod";
import {
  logSleep,
  deleteSleepLog,
  getSleepForDate,
  getSleepTrend,
  getSleepDurationMinutes,
  formatSleep,
  type DB,
} from "@htr/engine";

const logSleepSchema = z.object({
  startTime: z.string().min(1),
  endTime: z.string().min(1),
  quality: z.number().int().min(1).max(5).optional(),
  note: z.string().optional(),
});

function formatSleepEntry(entry: { startTime: string; endTime: string }) {
  const start = new Date(entry.startTime).getTime();
  const end = new Date(entry.endTime).getTime();
  const durationMinutes = Math.round((end - start) / 60000);
  return {
    durationMinutes,
    durationFormatted: formatSleep(durationMinutes),
  };
}

export function sleepRoutes(db: DB) {
  const app = new Hono();

  // GET /?date= — sleep entries for date
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

    const entries = getSleepForDate(db, date);
    const totalMinutes = entries.reduce(
      (sum, e) => sum + getSleepDurationMinutes(e),
      0
    );

    return c.json({
      date,
      totalMinutes,
      totalFormatted: formatSleep(totalMinutes),
      entries: entries.map((e) => ({
        ...e,
        ...formatSleepEntry(e),
      })),
    });
  });

  // GET /trend?days=7 — sleep trend
  app.get("/trend", (c) => {
    const days = parseInt(c.req.query("days") || "7", 10);
    const trend = getSleepTrend(db, days);
    return c.json(
      trend.map((d) => ({
        ...d,
        totalFormatted: formatSleep(d.totalMinutes),
      }))
    );
  });

  // POST / — log sleep
  app.post("/", async (c) => {
    const body = await c.req.json();
    const parsed = logSleepSchema.safeParse(body);
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

    const entry = logSleep(db, parsed.data);
    return c.json(
      {
        ...entry,
        ...formatSleepEntry(entry),
      },
      201
    );
  });

  // DELETE /:id — soft delete sleep log
  app.delete("/:id", (c) => {
    deleteSleepLog(db, c.req.param("id"));
    return c.json({ success: true });
  });

  return app;
}
