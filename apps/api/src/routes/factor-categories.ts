import { Hono } from "hono";
import type { Context } from "hono";
import {
  createCategory,
  listCategories,
  deleteCategory,
  CreateCategoryInput,
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

export function factorCategoriesRoutes(db: DB) {
  const app = new Hono();

  // GET / — list factor categories
  app.get("/", (c) => {
    return c.json(listCategories(db));
  });

  // POST / — create a category
  app.post("/", async (c) => {
    const body = await c.req.json();
    const parsed = CreateCategoryInput.safeParse(body);
    if (!parsed.success) return validationError(c, parsed.error.issues);
    return c.json(createCategory(db, parsed.data), 201);
  });

  // DELETE /:id — soft delete a category
  app.delete("/:id", (c) => {
    deleteCategory(db, c.req.param("id"));
    return c.json({ success: true });
  });

  return app;
}
