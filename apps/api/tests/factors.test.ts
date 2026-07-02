import { describe, it, expect, beforeAll } from "vitest";
import { createApp } from "../src/app.js";
import {
  createAndMigrateDb,
  seedMeals,
  seedTraining,
  seedFactors,
} from "@htr/engine";

function json(body: unknown) {
  return {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  };
}

// Deterministic UTC day helper: day(0) = 2026-05-01
function day(i: number): string {
  const d = new Date(Date.UTC(2026, 4, 1) + i * 86400000);
  return d.toISOString().slice(0, 10);
}

describe("Factors + Correlations API", () => {
  let app: ReturnType<typeof createApp>;

  beforeAll(() => {
    const db = createAndMigrateDb(":memory:");
    seedMeals(db);
    seedTraining(db);
    seedFactors(db);
    app = createApp(db);
  });

  describe("Factor CRUD", () => {
    it("GET /api/v1/factors includes seeded factor-alcohol", async () => {
      const res = await app.request("/api/v1/factors");
      expect(res.status).toBe(200);
      const body = await res.json();
      expect(body.some((f: any) => f.id === "factor-alcohol")).toBe(true);
    });

    it("POST /api/v1/factors creates a factor", async () => {
      const res = await app.request(
        "/api/v1/factors",
        json({
          categoryId: "cat-habits",
          name: "Water intake feeling",
          scaleMin: 1,
          scaleMax: 5,
        }),
      );
      expect(res.status).toBe(201);
      const body = await res.json();
      expect(body.name).toBe("Water intake feeling");
      expect(body.id).toBeDefined();
    });

    it("POST /api/v1/factors rejects a bad scale (min >= max)", async () => {
      const res = await app.request(
        "/api/v1/factors",
        json({
          categoryId: "cat-habits",
          name: "Broken scale",
          scaleMin: 5,
          scaleMax: 5,
        }),
      );
      expect(res.status).toBe(400);
      const body = await res.json();
      expect(body.error.code).toBe("VALIDATION_ERROR");
    });
  });

  describe("Factor logs", () => {
    it("POST then re-POST same date/factor upserts (history length 1)", async () => {
      const d = day(100);
      const first = await app.request(
        "/api/v1/factor-logs",
        json({ date: d, factorId: "factor-energy", value: 2 }),
      );
      expect(first.status).toBe(201);

      const second = await app.request(
        "/api/v1/factor-logs",
        json({ date: d, factorId: "factor-energy", value: 4 }),
      );
      expect(second.status).toBe(201);

      const histRes = await app.request(
        "/api/v1/factor-logs/history?factorId=factor-energy",
      );
      expect(histRes.status).toBe(200);
      const hist = await histRes.json();
      const forDay = hist.filter((h: any) => h.date === d);
      expect(forDay.length).toBe(1);
      expect(forDay[0].value).toBe(4);
    });

    it("POST out-of-scale value returns 400", async () => {
      const res = await app.request(
        "/api/v1/factor-logs",
        json({ date: day(101), factorId: "factor-energy", value: 99 }),
      );
      expect(res.status).toBe(400);
      const body = await res.json();
      expect(body.error.code).toBe("VALIDATION_ERROR");
    });

    it("GET /api/v1/factor-logs requires a valid date", async () => {
      const res = await app.request("/api/v1/factor-logs");
      expect(res.status).toBe(400);
    });
  });

  describe("Correlations", () => {
    beforeAll(async () => {
      // Plant ~24 days: alcohol up -> sleep down (strong negative correlation).
      for (let i = 0; i < 24; i++) {
        const d = day(i);
        const alcohol = i % 4; // 0..3
        await app.request(
          "/api/v1/factor-logs",
          json({ date: d, factorId: "factor-alcohol", value: alcohol }),
        );

        const startMs = Date.parse(`${d}T23:00:00.000Z`);
        const minutes = 480 - alcohol * 45;
        const end = new Date(startMs + minutes * 60000).toISOString();
        await app.request(
          "/api/v1/sleep",
          json({ startTime: `${d}T23:00:00.000Z`, endTime: end }),
        );
      }
    });

    it("alcohol strongly negatively correlates with sleep-minutes", async () => {
      const from = day(0);
      const to = day(23);
      const res = await app.request(
        `/api/v1/correlations?seriesA=factor:factor-alcohol&seriesB=htr:sleep-minutes&from=${from}&to=${to}&lag=1`,
      );
      expect(res.status).toBe(200);
      const body = await res.json();
      expect(body.correlation).not.toBeNull();
      expect(body.correlation.coefficient).toBeLessThan(-0.9);
      expect(body.correlation.significance).toBe("high");
    });

    it("GET /api/v1/correlations requires the four params", async () => {
      const res = await app.request("/api/v1/correlations?seriesA=factor:factor-alcohol");
      expect(res.status).toBe(400);
    });

    it("GET /api/v1/correlations/sources is non-empty", async () => {
      const res = await app.request("/api/v1/correlations/sources");
      expect(res.status).toBe(200);
      const body = await res.json();
      expect(Array.isArray(body.sources)).toBe(true);
      expect(body.sources.length).toBeGreaterThan(0);
    });

    it("GET /api/v1/correlations/insights surfaces alcohol x sleep", async () => {
      const from = day(0);
      const to = day(23);
      const res = await app.request(
        `/api/v1/correlations/insights?from=${from}&to=${to}`,
      );
      expect(res.status).toBe(200);
      const body = await res.json();
      expect(Array.isArray(body.insights)).toBe(true);
      const hit = body.insights.some((ins: any) => {
        const blob = JSON.stringify(ins);
        return blob.includes("factor-alcohol") && blob.includes("sleep-minutes");
      });
      expect(hit).toBe(true);
    });
  });

  describe("Daily summary includes factors", () => {
    it("GET /api/v1/daily/<date> includes a factors array", async () => {
      const res = await app.request(`/api/v1/daily/${day(0)}`);
      expect(res.status).toBe(200);
      const body = await res.json();
      expect(Array.isArray(body.factors)).toBe(true);
    });
  });
});
