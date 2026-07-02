import { Hono } from "hono";
import type { Context } from "hono";
import {
  getCorrelation,
  getCorrelationMatrix,
  getGroupComparison,
  getAutoInsights,
  listCorrelationSources,
  MatrixInput,
  GroupCompareInput,
  InsightsInput,
  type DB,
} from "@htr/engine";

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

export function correlationsRoutes(db: DB) {
  const app = new Hono();

  // GET /?seriesA=&seriesB=&from=&to=&lag= — pairwise correlation
  app.get("/", (c) => {
    const seriesA = c.req.query("seriesA");
    const seriesB = c.req.query("seriesB");
    const from = c.req.query("from");
    const to = c.req.query("to");
    if (!seriesA || !seriesB || !from || !to) {
      return validationError(c, [
        { message: "seriesA, seriesB, from, and to query params are required" },
      ]);
    }
    const lagRaw = c.req.query("lag");
    const lag = lagRaw !== undefined ? parseInt(lagRaw, 10) : undefined;
    const correlation = getCorrelation(db, seriesA, seriesB, from, to, { lag });
    return c.json({ correlation });
  });

  // GET /sources — available correlation data sources
  app.get("/sources", (c) => {
    return c.json({ sources: listCorrelationSources(db) });
  });

  // GET /insights?from=&to= — auto-detected insights
  app.get("/insights", (c) => {
    const parsed = InsightsInput.safeParse({
      from: c.req.query("from"),
      to: c.req.query("to"),
    });
    if (!parsed.success) return validationError(c, parsed.error.issues);
    return c.json({ insights: getAutoInsights(db, parsed.data.from, parsed.data.to) });
  });

  // POST /matrix — correlation matrix across sources
  app.post("/matrix", async (c) => {
    const body = await c.req.json();
    const parsed = MatrixInput.safeParse(body);
    if (!parsed.success) return validationError(c, parsed.error.issues);
    const { sources, from, to, lag } = parsed.data;
    return c.json(getCorrelationMatrix(db, sources, from, to, { lag }));
  });

  // POST /group — group comparison (high vs low factor days)
  app.post("/group", async (c) => {
    const body = await c.req.json();
    const parsed = GroupCompareInput.safeParse(body);
    if (!parsed.success) return validationError(c, parsed.error.issues);
    const { factorSource, metricSource, from, to, lag, threshold } = parsed.data;
    const comparison = getGroupComparison(db, factorSource, metricSource, from, to, {
      lag,
      threshold,
    });
    return c.json({ comparison });
  });

  return app;
}
