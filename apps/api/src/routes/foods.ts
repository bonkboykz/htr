import { Hono } from "hono";
import { z } from "zod";
import {
  createFoodItem,
  updateFoodItem,
  deleteFoodItem,
  getFoodItem,
  listFoodItems,
  formatCalories,
  formatMacro,
  type DB,
} from "@htr/engine";

const createFoodSchema = z.object({
  name: z.string().min(1),
  brand: z.string().optional(),
  caloriesPer100g: z.number().int().min(0),
  proteinPer100g: z.number().int().min(0),
  fatPer100g: z.number().int().min(0),
  carbsPer100g: z.number().int().min(0),
  fiberPer100g: z.number().int().min(0).optional(),
  servingSizeG: z.number().int().min(1).optional(),
  barcode: z.string().optional(),
});

const updateFoodSchema = z.object({
  name: z.string().min(1).optional(),
  brand: z.string().nullable().optional(),
  caloriesPer100g: z.number().int().min(0).optional(),
  proteinPer100g: z.number().int().min(0).optional(),
  fatPer100g: z.number().int().min(0).optional(),
  carbsPer100g: z.number().int().min(0).optional(),
  fiberPer100g: z.number().int().min(0).optional(),
  servingSizeG: z.number().int().min(1).optional(),
  barcode: z.string().nullable().optional(),
});

function formatFoodItem(item: ReturnType<typeof getFoodItem>) {
  if (!item) return null;
  return {
    ...item,
    caloriesPer100gFormatted: formatCalories(item.caloriesPer100g),
    proteinPer100gFormatted: formatMacro(item.proteinPer100g),
    fatPer100gFormatted: formatMacro(item.fatPer100g),
    carbsPer100gFormatted: formatMacro(item.carbsPer100g),
    fiberPer100gFormatted: formatMacro(item.fiberPer100g),
  };
}

export function foodsRoutes(db: DB) {
  const app = new Hono();

  // GET / — list food items, optional ?q= search
  app.get("/", (c) => {
    const q = c.req.query("q");
    const items = listFoodItems(db, q || undefined);
    return c.json(items.map(formatFoodItem));
  });

  // GET /:id — get food item by ID
  app.get("/:id", (c) => {
    const item = getFoodItem(db, c.req.param("id"));
    if (!item) {
      return c.json(
        {
          error: {
            code: "NOT_FOUND",
            message: "Food item not found",
            suggestion: "Check the food item ID and try again",
          },
        },
        404
      );
    }
    return c.json(formatFoodItem(item));
  });

  // POST / — create food item
  app.post("/", async (c) => {
    const body = await c.req.json();
    const parsed = createFoodSchema.safeParse(body);
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
    const item = createFoodItem(db, parsed.data);
    return c.json(formatFoodItem(item), 201);
  });

  // PATCH /:id — update food item
  app.patch("/:id", async (c) => {
    const id = c.req.param("id");
    const existing = getFoodItem(db, id);
    if (!existing) {
      return c.json(
        {
          error: {
            code: "NOT_FOUND",
            message: "Food item not found",
            suggestion: "Check the food item ID and try again",
          },
        },
        404
      );
    }

    const body = await c.req.json();
    const parsed = updateFoodSchema.safeParse(body);
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

    const updated = updateFoodItem(db, id, parsed.data);
    return c.json(formatFoodItem(updated));
  });

  // DELETE /:id — soft delete food item
  app.delete("/:id", (c) => {
    const id = c.req.param("id");
    const existing = getFoodItem(db, id);
    if (!existing) {
      return c.json(
        {
          error: {
            code: "NOT_FOUND",
            message: "Food item not found",
            suggestion: "Check the food item ID and try again",
          },
        },
        404
      );
    }
    deleteFoodItem(db, id);
    return c.json({ success: true });
  });

  return app;
}
