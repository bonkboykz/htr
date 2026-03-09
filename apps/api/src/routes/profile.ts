import { Hono } from "hono";
import { z } from "zod";
import {
  setProfile,
  getProfile,
  getTargetCalories,
  formatCalories,
  type DB,
} from "@htr/engine";

const profileSchema = z.object({
  heightCm: z.number().int().min(50).max(300),
  birthDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  sex: z.enum(["male", "female"]),
  activityLevel: z
    .enum(["sedentary", "light", "moderate", "active", "very_active"])
    .optional(),
});

export function profileRoutes(db: DB) {
  const app = new Hono();

  // GET / — get profile
  app.get("/", (c) => {
    const profile = getProfile(db);
    if (!profile) {
      return c.json(
        {
          error: {
            code: "NOT_FOUND",
            message: "Profile not set",
            suggestion: "Set your profile using PUT /api/v1/profile",
          },
        },
        404
      );
    }
    return c.json(profile);
  });

  // PUT / — create/update profile (UPSERT)
  app.put("/", async (c) => {
    const body = await c.req.json();
    const parsed = profileSchema.safeParse(body);
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

    const profile = setProfile(db, parsed.data);
    return c.json(profile);
  });

  // GET /tdee — TDEE + target calories
  app.get("/tdee", (c) => {
    const tdee = getTargetCalories(db);
    if (!tdee) {
      return c.json(
        {
          error: {
            code: "NOT_FOUND",
            message: "Cannot calculate TDEE",
            suggestion:
              "Set your profile and log your weight first",
          },
        },
        404
      );
    }

    return c.json({
      ...tdee,
      bmrFormatted: formatCalories(tdee.bmr),
      tdeeFormatted: formatCalories(tdee.tdee),
      targetCaloriesFormatted: formatCalories(tdee.targetCalories),
    });
  });

  return app;
}
