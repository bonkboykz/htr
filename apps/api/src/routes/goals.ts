import { Hono } from "hono";
import { z } from "zod";
import {
  setWeightGoal,
  getGoalProgress,
  deleteWeightGoal,
  formatWeight,
  formatCalories,
  type DB,
} from "@htr/engine";

const weightGoalSchema = z.object({
  targetGrams: z.number().int().min(1),
  pace: z.enum(["slow", "normal", "fast"]).optional(),
});

export function goalsRoutes(db: DB) {
  const app = new Hono();

  // POST /weight — set weight goal
  app.post("/weight", async (c) => {
    const body = await c.req.json();
    const parsed = weightGoalSchema.safeParse(body);
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

    try {
      const goal = setWeightGoal(db, parsed.data);
      return c.json(
        {
          ...goal,
          targetFormatted: formatWeight(goal.targetGrams),
          startFormatted: formatWeight(goal.startGrams),
        },
        201
      );
    } catch (err: any) {
      return c.json(
        {
          error: {
            code: "PRECONDITION_FAILED",
            message: err.message,
            suggestion: "Log your weight first using POST /api/v1/weight",
          },
        },
        412
      );
    }
  });

  // GET /weight — active goal + progress
  app.get("/weight", (c) => {
    const progress = getGoalProgress(db);
    if (!progress) {
      return c.json(
        {
          error: {
            code: "NOT_FOUND",
            message: "No active weight goal",
            suggestion: "Set a weight goal using POST /api/v1/goals/weight",
          },
        },
        404
      );
    }

    return c.json({
      ...progress,
      goal: {
        ...progress.goal,
        targetFormatted: formatWeight(progress.goal.targetGrams),
        startFormatted: formatWeight(progress.goal.startGrams),
      },
      currentFormatted: formatWeight(progress.currentGrams),
      remainingFormatted: formatWeight(progress.remainingGrams),
      tdee: progress.tdee
        ? {
            ...progress.tdee,
            bmrFormatted: formatCalories(progress.tdee.bmr),
            tdeeFormatted: formatCalories(progress.tdee.tdee),
            targetCaloriesFormatted: formatCalories(progress.tdee.targetCalories),
          }
        : null,
    });
  });

  // DELETE /weight/:id — soft delete
  app.delete("/weight/:id", (c) => {
    deleteWeightGoal(db, c.req.param("id"));
    return c.json({ success: true });
  });

  return app;
}
