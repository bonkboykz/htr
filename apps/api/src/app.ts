import { Hono } from "hono";
import { cors } from "hono/cors";
import { logger } from "hono/logger";
import type { DB } from "@htr/engine";
import { AppError } from "./errors.js";
import { apiKeyAuth } from "./middleware/auth.js";
import { foodsRoutes } from "./routes/foods.js";
import { foodLogsRoutes } from "./routes/food-logs.js";
import { weightRoutes } from "./routes/weight.js";
import { waterRoutes } from "./routes/water.js";
import { sleepRoutes } from "./routes/sleep.js";
import { dailyRoutes } from "./routes/daily.js";
import { targetsRoutes } from "./routes/targets.js";
import { statsRoutes } from "./routes/stats.js";

export function createApp(db: DB) {
  const app = new Hono();

  // Global middleware
  app.use("*", cors());
  app.use("*", logger());

  // Health check (before auth)
  app.get("/health", (c) => c.json({ status: "ok" }));

  // API key auth for all API routes
  app.use("/api/v1/*", apiKeyAuth());

  // Mount API routes
  app.route("/api/v1/foods", foodsRoutes(db));
  app.route("/api/v1/food-logs", foodLogsRoutes(db));
  app.route("/api/v1/weight", weightRoutes(db));
  app.route("/api/v1/water", waterRoutes(db));
  app.route("/api/v1/sleep", sleepRoutes(db));
  app.route("/api/v1/daily", dailyRoutes(db));
  app.route("/api/v1/targets", targetsRoutes(db));
  app.route("/api/v1/stats", statsRoutes(db));

  // Global error handler
  app.onError((err, c) => {
    if (err instanceof AppError) {
      return c.json(
        {
          error: {
            code: err.code,
            message: err.message,
            suggestion: err.suggestion || undefined,
          },
        },
        err.status as any,
      );
    }

    console.error("Unhandled error:", err);
    return c.json(
      {
        error: {
          code: "INTERNAL_ERROR",
          message: "An unexpected error occurred",
        },
      },
      500,
    );
  });

  // 404 handler
  app.notFound((c) => {
    return c.json(
      {
        error: {
          code: "NOT_FOUND",
          message: `Route not found: ${c.req.method} ${c.req.path}`,
          suggestion: "Check the API documentation for available endpoints",
        },
      },
      404
    );
  });

  return app;
}
