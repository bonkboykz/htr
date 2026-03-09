import { describe, it, expect, beforeAll } from "vitest";
import { createApp } from "../src/app.js";
import { setupTestDb } from "@htr/engine";

function setupTestApp() {
  const db = setupTestDb();
  const app = createApp(db);
  return { app, db };
}

describe("API", () => {
  let app: ReturnType<typeof createApp>;

  beforeAll(() => {
    const result = setupTestApp();
    app = result.app;
  });

  describe("Health", () => {
    it("GET /health returns ok", async () => {
      const res = await app.request("/health");
      expect(res.status).toBe(200);
      const body = await res.json();
      expect(body).toEqual({ status: "ok" });
    });
  });

  describe("404", () => {
    it("returns error for unknown route", async () => {
      const res = await app.request("/api/v1/nonexistent");
      expect(res.status).toBe(404);
      const body = await res.json();
      expect(body.error.code).toBe("NOT_FOUND");
    });
  });

  describe("Foods", () => {
    let foodId: string;

    it("POST /api/v1/foods creates a food item", async () => {
      const res = await app.request("/api/v1/foods", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          name: "Chicken Breast",
          caloriesPer100g: 165,
          proteinPer100g: 310,
          fatPer100g: 36,
          carbsPer100g: 0,
        }),
      });
      expect(res.status).toBe(201);
      const body = await res.json();
      expect(body.name).toBe("Chicken Breast");
      expect(body.caloriesPer100gFormatted).toBeDefined();
      foodId = body.id;
    });

    it("GET /api/v1/foods lists food items", async () => {
      const res = await app.request("/api/v1/foods");
      expect(res.status).toBe(200);
      const body = await res.json();
      expect(body.length).toBeGreaterThan(0);
    });

    it("GET /api/v1/foods?q=chicken searches", async () => {
      const res = await app.request("/api/v1/foods?q=Chicken");
      expect(res.status).toBe(200);
      const body = await res.json();
      expect(body.length).toBe(1);
      expect(body[0].name).toBe("Chicken Breast");
    });

    it("GET /api/v1/foods/:id returns food item", async () => {
      const res = await app.request(`/api/v1/foods/${foodId}`);
      expect(res.status).toBe(200);
      const body = await res.json();
      expect(body.id).toBe(foodId);
    });

    it("PATCH /api/v1/foods/:id updates food item", async () => {
      const res = await app.request(`/api/v1/foods/${foodId}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name: "Grilled Chicken" }),
      });
      expect(res.status).toBe(200);
      const body = await res.json();
      expect(body.name).toBe("Grilled Chicken");
    });

    it("DELETE /api/v1/foods/:id soft deletes", async () => {
      const res = await app.request(`/api/v1/foods/${foodId}`, {
        method: "DELETE",
      });
      expect(res.status).toBe(200);
      // Should not be found after delete
      const getRes = await app.request(`/api/v1/foods/${foodId}`);
      expect(getRes.status).toBe(404);
    });
  });

  describe("Food Logs", () => {
    let foodId: string;

    beforeAll(async () => {
      // Create a food item for logging
      const res = await app.request("/api/v1/foods", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          name: "Rice",
          caloriesPer100g: 130,
          proteinPer100g: 27,
          fatPer100g: 3,
          carbsPer100g: 284,
        }),
      });
      const body = await res.json();
      foodId = body.id;
    });

    it("POST /api/v1/food-logs logs food", async () => {
      const res = await app.request("/api/v1/food-logs", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          date: "2026-03-09",
          mealId: "meal-lunch",
          foodItemId: foodId,
          servingGrams: 200,
        }),
      });
      expect(res.status).toBe(201);
      const body = await res.json();
      expect(body.calories).toBe(260); // 130 * 200 / 100
    });

    it("POST /api/v1/food-logs/quick quick-logs food", async () => {
      const res = await app.request("/api/v1/food-logs/quick", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          date: "2026-03-09",
          mealId: "meal-snack",
          name: "Protein Bar",
          calories: 220,
          protein: 200,
        }),
      });
      expect(res.status).toBe(201);
      const body = await res.json();
      expect(body.calories).toBe(220);
    });

    it("GET /api/v1/food-logs?date= returns daily nutrition", async () => {
      const res = await app.request("/api/v1/food-logs?date=2026-03-09");
      expect(res.status).toBe(200);
      const body = await res.json();
      expect(body.date).toBe("2026-03-09");
      expect(body.meals).toBeDefined();
      expect(body.totals).toBeDefined();
    });
  });

  describe("Weight", () => {
    let weightId: string;

    it("POST /api/v1/weight logs weight", async () => {
      const res = await app.request("/api/v1/weight", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          date: "2026-03-09",
          weightGrams: 75500,
        }),
      });
      expect(res.status).toBe(201);
      const body = await res.json();
      expect(body.weightGrams).toBe(75500);
      expect(body.weightFormatted).toBeDefined();
      weightId = body.id;
    });

    it("GET /api/v1/weight lists weight entries", async () => {
      const res = await app.request("/api/v1/weight");
      expect(res.status).toBe(200);
      const body = await res.json();
      expect(body.length).toBeGreaterThan(0);
    });

    it("GET /api/v1/weight/latest returns latest weight", async () => {
      const res = await app.request("/api/v1/weight/latest");
      expect(res.status).toBe(200);
      const body = await res.json();
      expect(body.latest).toBeDefined();
    });
  });

  describe("Water", () => {
    it("POST /api/v1/water logs water", async () => {
      const res = await app.request("/api/v1/water", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          date: "2026-03-09",
          amountMl: 250,
        }),
      });
      expect(res.status).toBe(201);
      const body = await res.json();
      expect(body.amountMl).toBe(250);
    });

    it("GET /api/v1/water?date= returns daily water summary", async () => {
      const res = await app.request("/api/v1/water?date=2026-03-09");
      expect(res.status).toBe(200);
      const body = await res.json();
      expect(body.totalMl).toBe(250);
      expect(body.entries).toBeDefined();
    });
  });

  describe("Sleep", () => {
    it("POST /api/v1/sleep logs sleep", async () => {
      const res = await app.request("/api/v1/sleep", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          startTime: "2026-03-08T23:00:00Z",
          endTime: "2026-03-09T07:00:00Z",
          quality: 4,
        }),
      });
      expect(res.status).toBe(201);
      const body = await res.json();
      expect(body.quality).toBe(4);
    });

    it("GET /api/v1/sleep?date= returns sleep entries", async () => {
      const res = await app.request("/api/v1/sleep?date=2026-03-09");
      expect(res.status).toBe(200);
      const body = await res.json();
      expect(body.entries.length).toBeGreaterThan(0);
      expect(body.totalMinutes).toBeGreaterThan(0);
    });
  });

  describe("Targets", () => {
    it("POST /api/v1/targets sets a target", async () => {
      const res = await app.request("/api/v1/targets", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          effectiveDate: "2026-01-01",
          calories: 2000,
          protein: 1500,
          fat: 700,
          carbs: 2500,
        }),
      });
      expect(res.status).toBe(201);
      const body = await res.json();
      expect(body.calories).toBe(2000);
    });

    it("GET /api/v1/targets lists targets", async () => {
      const res = await app.request("/api/v1/targets");
      expect(res.status).toBe(200);
      const body = await res.json();
      expect(body.length).toBeGreaterThan(0);
    });

    it("GET /api/v1/targets/active returns active target", async () => {
      const res = await app.request("/api/v1/targets/active");
      expect(res.status).toBe(200);
      const body = await res.json();
      expect(body.calories).toBe(2000);
    });
  });

  describe("Daily Summary", () => {
    it("GET /api/v1/daily/:date returns full summary", async () => {
      const res = await app.request("/api/v1/daily/2026-03-09");
      expect(res.status).toBe(200);
      const body = await res.json();
      expect(body.date).toBe("2026-03-09");
      expect(body.nutrition).toBeDefined();
      expect(body.water).toBeDefined();
      expect(body.sleep).toBeDefined();
      expect(body).toHaveProperty("tdee");
    });

    it("GET /api/v1/daily/:date returns null caloriesBudget when no profile", async () => {
      const res = await app.request("/api/v1/daily/2026-03-09");
      expect(res.status).toBe(200);
      const body = await res.json();
      expect(body.caloriesBudget).toBeNull();
    });
  });

  describe("Profile", () => {
    it("GET /api/v1/profile returns 404 when no profile", async () => {
      const res = await app.request("/api/v1/profile");
      expect(res.status).toBe(404);
    });

    it("PUT /api/v1/profile creates profile", async () => {
      const res = await app.request("/api/v1/profile", {
        method: "PUT",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          heightCm: 178,
          birthDate: "1998-05-15",
          sex: "male",
          activityLevel: "moderate",
        }),
      });
      expect(res.status).toBe(200);
      const body = await res.json();
      expect(body.heightCm).toBe(178);
      expect(body.sex).toBe("male");
    });

    it("GET /api/v1/profile returns profile", async () => {
      const res = await app.request("/api/v1/profile");
      expect(res.status).toBe(200);
      const body = await res.json();
      expect(body.heightCm).toBe(178);
    });

    it("GET /api/v1/profile/tdee returns TDEE", async () => {
      const res = await app.request("/api/v1/profile/tdee");
      expect(res.status).toBe(200);
      const body = await res.json();
      expect(body.bmr).toBeGreaterThan(0);
      expect(body.tdee).toBeGreaterThan(body.bmr);
      expect(body.tdeeFormatted).toBeDefined();
    });
  });

  describe("Weight Goals", () => {
    it("GET /api/v1/goals/weight returns 404 when no goal", async () => {
      const res = await app.request("/api/v1/goals/weight");
      expect(res.status).toBe(404);
    });

    it("POST /api/v1/goals/weight sets a goal", async () => {
      const res = await app.request("/api/v1/goals/weight", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          targetGrams: 70000,
          pace: "normal",
        }),
      });
      expect(res.status).toBe(201);
      const body = await res.json();
      expect(body.targetGrams).toBe(70000);
      expect(body.targetFormatted).toBeDefined();
    });

    it("GET /api/v1/goals/weight returns progress", async () => {
      const res = await app.request("/api/v1/goals/weight");
      expect(res.status).toBe(200);
      const body = await res.json();
      expect(body.progressPercent).toBeDefined();
      expect(body.direction).toBe("loss");
      expect(body.estimatedDate).toBeDefined();
    });
  });

  describe("Daily Summary with TDEE", () => {
    it("GET /api/v1/daily/:date includes caloriesBudget when profile exists", async () => {
      // Profile + weight set in previous describe blocks
      const res = await app.request("/api/v1/daily/2026-03-09");
      expect(res.status).toBe(200);
      const body = await res.json();
      expect(body.caloriesBudget).not.toBeNull();
      expect(body.caloriesBudget.targetCalories).toBeGreaterThan(0);
      expect(body.caloriesBudget.consumedCalories).toBeGreaterThanOrEqual(0);
      expect(typeof body.caloriesBudget.remainingCalories).toBe("number");
      expect(body.caloriesBudget.remainingCaloriesFormatted).toBeDefined();
      expect(body.caloriesBudget.progress).toBeGreaterThanOrEqual(0);
    });
  });

  describe("Stats", () => {
    it("GET /api/v1/stats/week returns week summary", async () => {
      const res = await app.request("/api/v1/stats/week?date=2026-03-09");
      expect(res.status).toBe(200);
      const body = await res.json();
      expect(body.weekStart).toBeDefined();
    });

    it("GET /api/v1/stats/streaks returns streaks", async () => {
      const res = await app.request("/api/v1/stats/streaks");
      expect(res.status).toBe(200);
      const body = await res.json();
      expect(body.foodLogging).toBeDefined();
    });

    it("GET /api/v1/stats/range returns range stats", async () => {
      const res = await app.request(
        "/api/v1/stats/range?from=2026-03-01&to=2026-03-09"
      );
      expect(res.status).toBe(200);
      const body = await res.json();
      expect(body.from).toBe("2026-03-01");
    });
  });
});
