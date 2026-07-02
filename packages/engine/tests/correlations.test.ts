import { describe, it, expect, beforeEach } from "vitest";
import {
  setupTestDb,
  logFactor,
  logSleep,
  logWater,
  spearman,
  rankWithTies,
  corrPValue,
  welchT,
  significanceFromP,
  getDataSeries,
  listCorrelationSources,
  getCorrelation,
  getCorrelationMatrix,
  getGroupComparison,
  getAutoInsights,
  type DB,
} from "../src/index.js";

function day(i: number): string {
  const d = new Date(Date.UTC(2026, 4, 1));
  d.setUTCDate(d.getUTCDate() + i);
  return d.toISOString().slice(0, 10);
}

// Plant: alcohol on day d ∈ {0..3}; the following night (wakes d+1) is shorter
// the more alcohol. So the signal lives at lag +1, not lag 0.
function plantAlcoholSleep(db: DB, days: number) {
  for (let i = 0; i < days; i++) {
    const alc = i % 4;
    logFactor(db, { date: day(i), factorId: "factor-alcohol", value: alc });
    const start = `${day(i)}T23:00:00.000Z`;
    const durationMin = 480 - alc * 45;
    const end = new Date(new Date(start).getTime() + durationMin * 60000).toISOString();
    logSleep(db, { startTime: start, endTime: end }); // wakes on day(i+1)
  }
}

describe("correlations: pure stats", () => {
  it("spearman handles perfect and tied ranks", () => {
    expect(spearman([1, 2, 3, 4, 5], [2, 4, 6, 8, 10])).toBe(1);
    expect(spearman([1, 2, 3, 4, 5], [10, 8, 6, 4, 2])).toBe(-1);
    expect(spearman([1, 1, 2, 3], [1, 2, 2, 4])).toBeCloseTo(0.833, 2);
  });

  it("rankWithTies averages tied positions", () => {
    expect(rankWithTies([3, 1, 3, 2])).toEqual([3.5, 1, 3.5, 2]);
  });

  it("corrPValue shrinks as correlation/n grow; significanceFromP tiers", () => {
    expect(corrPValue(0.9, 20)).toBeLessThan(0.001);
    expect(corrPValue(0.1, 10)).toBeGreaterThan(0.1);
    expect(significanceFromP(0.005)).toBe("high");
    expect(significanceFromP(0.03)).toBe("medium");
    expect(significanceFromP(0.08)).toBe("low");
    expect(significanceFromP(0.5)).toBe("none");
  });

  it("welchT separates clearly different groups", () => {
    const res = welchT([10, 11, 9, 10, 12], [2, 3, 1, 2, 4]);
    expect(res.p).toBeLessThan(0.01);
  });
});

describe("correlations: series", () => {
  let db: DB;
  beforeEach(() => {
    db = setupTestDb();
  });

  it("getDataSeries reads factor and htr sources; missing days omitted", () => {
    logFactor(db, { date: "2026-05-01", factorId: "factor-energy", value: 4 });
    logFactor(db, { date: "2026-05-03", factorId: "factor-energy", value: 2 });
    const fs = getDataSeries(db, "factor:factor-energy", "2026-05-01", "2026-05-31");
    expect(fs.points).toEqual([
      { date: "2026-05-01", value: 4 },
      { date: "2026-05-03", value: 2 },
    ]); // 05-02 omitted (no log)

    logWater(db, { date: "2026-05-01", amountMl: 500 });
    logWater(db, { date: "2026-05-01", amountMl: 250 });
    const ws = getDataSeries(db, "htr:water-ml", "2026-05-01", "2026-05-31");
    expect(ws.points).toEqual([{ date: "2026-05-01", value: 750 }]); // summed
  });

  it("lists factor + htr correlation sources", () => {
    const sources = listCorrelationSources(db);
    expect(sources.some((s) => s.id === "htr:sleep-minutes" && s.kind === "htr")).toBe(true);
    expect(sources.some((s) => s.id === "factor:factor-alcohol" && s.kind === "factor")).toBe(true);
  });
});

describe("correlations: engine", () => {
  let db: DB;
  beforeEach(() => {
    db = setupTestDb();
  });

  it("returns null below the minimum shared points", () => {
    for (let i = 0; i < 4; i++) {
      logFactor(db, { date: day(i), factorId: "factor-alcohol", value: i });
      logWater(db, { date: day(i), amountMl: 1000 + i * 100 });
    }
    expect(
      getCorrelation(db, "factor:factor-alcohol", "htr:water-ml", day(0), day(10)),
    ).toBeNull();
  });

  it("finds the alcohol→sleep signal at lag +1, not lag 0", () => {
    plantAlcoholSleep(db, 24);
    const from = day(0);
    const to = day(25);

    const lag1 = getCorrelation(db, "factor:factor-alcohol", "htr:sleep-minutes", from, to, { lag: 1 });
    expect(lag1).not.toBeNull();
    expect(lag1!.coefficient).toBeLessThan(-0.9);
    expect(lag1!.significance).toBe("high");
    expect(lag1!.dataPoints).toBeGreaterThanOrEqual(20);

    const lag0 = getCorrelation(db, "factor:factor-alcohol", "htr:sleep-minutes", from, to, { lag: 0 });
    expect(lag0!.significance).toBe("none"); // same-day has no real association
  });

  it("group comparison: drinking days have less sleep (negative delta)", () => {
    plantAlcoholSleep(db, 24);
    const g = getGroupComparison(
      db,
      "factor:factor-alcohol",
      "htr:sleep-minutes",
      day(0),
      day(25),
      { lag: 1 },
    );
    expect(g).not.toBeNull();
    expect(g!.withMean).toBeLessThan(g!.withoutMean);
    expect(g!.deltaPct).toBeLessThan(0);
    expect(g!.significance).not.toBe("none");
  });

  it("matrix only includes pairs with enough data", () => {
    plantAlcoholSleep(db, 24);
    const m = getCorrelationMatrix(
      db,
      ["factor:factor-alcohol", "htr:sleep-minutes", "htr:weight-grams"],
      day(0),
      day(25),
      { lag: 1 },
    );
    // weight has no logs → its pairs drop out; alcohol↔sleep remains
    expect(
      m.correlations.some(
        (c) => c.seriesA === "factor:factor-alcohol" && c.seriesB === "htr:sleep-minutes",
      ),
    ).toBe(true);
    expect(m.correlations.some((c) => c.seriesB === "htr:weight-grams")).toBe(false);
  });

  it("auto insights surface the planted alcohol↔sleep signal", () => {
    plantAlcoholSleep(db, 24);
    const insights = getAutoInsights(db, day(0), day(25));
    expect(insights.length).toBeGreaterThan(0);
    expect(
      insights.some(
        (i) =>
          i.factorSource === "factor:factor-alcohol" &&
          i.metricSource === "htr:sleep-minutes" &&
          i.significance !== "none",
      ),
    ).toBe(true);
  });
});
