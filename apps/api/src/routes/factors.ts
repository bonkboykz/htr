import { Hono } from "hono";
import type { Context } from "hono";
import {
  createFactor,
  listFactors,
  deleteFactor,
  CreateFactorInput,
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

export function factorsRoutes(db: DB) {
  const app = new Hono();

  // GET / — list factors, optional ?categoryId=
  app.get("/", (c) => {
    return c.json(listFactors(db, c.req.query("categoryId")));
  });

  // POST / — create a factor
  app.post("/", async (c) => {
    const body = await c.req.json();
    const parsed = CreateFactorInput.safeParse(body);
    if (!parsed.success) return validationError(c, parsed.error.issues);
    try {
      return c.json(createFactor(db, parsed.data), 201);
    } catch (err: any) {
      throw new AppError("VALIDATION_ERROR", err.message, 400);
    }
  });

  // DELETE /:id — soft delete a factor
  app.delete("/:id", (c) => {
    deleteFactor(db, c.req.param("id"));
    return c.json({ success: true });
  });

  return app;
}
