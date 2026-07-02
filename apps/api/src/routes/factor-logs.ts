import { Hono } from "hono";
import type { Context } from "hono";
import {
  logFactor,
  bulkLogFactors,
  deleteFactorLog,
  getFactorLogsForDate,
  getFactorHistory,
  LogFactorInput,
  BulkLogFactorsInput,
  type DB,
} from "@htr/engine";
import { AppError } from "../errors.js";

function validationError(c: Context, issues: { message: string }[]) {
  return c.json(
    {
      error: {
        code: "VALIDATION_ERROR",
        message: issues.map((i) => i.message).join(", "),
        suggestion: "Check the request body and try again",
      },
    },
    400,
  );
}

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;

export function factorLogsRoutes(db: DB) {
  const app = new Hono();

  // GET /?date= — factor logs for a date (grouped by category)
  app.get("/", (c) => {
    const date = c.req.query("date");
    if (!date || !DATE_RE.test(date)) {
      return validationError(c, [
        { message: "date query param is required (YYYY-MM-DD)" },
      ]);
    }
    return c.json(getFactorLogsForDate(db, date));
  });

  // GET /history?factorId=&days= — history for one factor
  app.get("/history", (c) => {
    const factorId = c.req.query("factorId");
    if (!factorId) {
      return validationError(c, [{ message: "factorId query param is required" }]);
    }
    const daysRaw = c.req.query("days");
    const days = daysRaw !== undefined ? parseInt(daysRaw, 10) : undefined;
    return c.json(getFactorHistory(db, factorId, days));
  });

  // POST / — log a factor value (upsert)
  app.post("/", async (c) => {
    const body = await c.req.json();
    const parsed = LogFactorInput.safeParse(body);
    if (!parsed.success) return validationError(c, parsed.error.issues);
    try {
      return c.json(logFactor(db, parsed.data), 201);
    } catch (err: any) {
      if (/not found/i.test(err.message)) {
        throw new AppError("NOT_FOUND", err.message, 404);
      }
      throw new AppError("VALIDATION_ERROR", err.message, 400);
    }
  });

  // POST /bulk — log multiple factor values
  app.post("/bulk", async (c) => {
    const body = await c.req.json();
    const parsed = BulkLogFactorsInput.safeParse(body);
    if (!parsed.success) return validationError(c, parsed.error.issues);
    try {
      return c.json(bulkLogFactors(db, parsed.data), 201);
    } catch (err: any) {
      if (/not found/i.test(err.message)) {
        throw new AppError("NOT_FOUND", err.message, 404);
      }
      throw new AppError("VALIDATION_ERROR", err.message, 400);
    }
  });

  // DELETE /:id — soft delete a factor log
  app.delete("/:id", (c) => {
    deleteFactorLog(db, c.req.param("id"));
    return c.json({ success: true });
  });

  return app;
}
