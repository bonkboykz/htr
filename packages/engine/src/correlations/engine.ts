import type { DB } from "../db/index.js";
import type {
  Correlation,
  CorrelationMatrix,
  GroupComparison,
  Insight,
} from "../types.js";
import { getFactor } from "../factors/engine.js";
import { getDataSeries, listCorrelationSources, sourceLabel } from "./series.js";
import {
  spearman,
  corrPValue,
  welchT,
  significanceFromP,
} from "./stats.js";

const MIN_POINTS = 7;

function addDays(date: string, n: number): string {
  const d = new Date(`${date}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
}

function round(x: number, digits: number): number {
  const f = 10 ** digits;
  return Math.round(x * f) / f;
}

function mean(xs: number[]): number {
  return xs.reduce((a, b) => a + b, 0) / xs.length;
}

// Pair seriesA[d] with seriesB[d + lag] over the shared dates.
function alignedPairs(
  db: DB,
  seriesA: string,
  seriesB: string,
  from: string,
  to: string,
  lag: number,
): { xs: number[]; ys: number[] } {
  const a = getDataSeries(db, seriesA, from, to);
  const b = getDataSeries(db, seriesB, addDays(from, lag), addDays(to, lag));
  const bByDate = new Map(b.points.map((p) => [p.date, p.value]));
  const xs: number[] = [];
  const ys: number[] = [];
  for (const p of a.points) {
    const bv = bByDate.get(addDays(p.date, lag));
    if (bv === undefined) continue;
    xs.push(p.value);
    ys.push(bv);
  }
  return { xs, ys };
}

export function getCorrelation(
  db: DB,
  seriesA: string,
  seriesB: string,
  from: string,
  to: string,
  opts?: { lag?: number },
): Correlation | null {
  const lag = opts?.lag ?? 0;
  const { xs, ys } = alignedPairs(db, seriesA, seriesB, from, to, lag);
  if (xs.length < MIN_POINTS) return null;
  const coefficient = spearman(xs, ys);
  const pValue = corrPValue(coefficient, xs.length);
  return {
    seriesA,
    seriesB,
    lag,
    coefficient: round(coefficient, 3),
    pValue: round(pValue, 4),
    significance: significanceFromP(pValue),
    dataPoints: xs.length,
  };
}

export function getCorrelationMatrix(
  db: DB,
  sources: string[],
  from: string,
  to: string,
  opts?: { lag?: number },
): CorrelationMatrix {
  const lag = opts?.lag ?? 0;
  const correlations: Correlation[] = [];
  for (let i = 0; i < sources.length; i++) {
    for (let j = i + 1; j < sources.length; j++) {
      const c = getCorrelation(db, sources[i], sources[j], from, to, { lag });
      if (c) correlations.push(c);
    }
  }
  return { series: sources, lag, correlations };
}

export function getGroupComparison(
  db: DB,
  factorSource: string,
  metricSource: string,
  from: string,
  to: string,
  opts?: { lag?: number; threshold?: number },
): GroupComparison | null {
  const lag = opts?.lag ?? 0;
  let threshold = opts?.threshold;
  if (threshold === undefined) {
    if (factorSource.startsWith("factor:")) {
      const f = getFactor(db, factorSource.slice("factor:".length));
      threshold = f ? f.scaleMin + 1 : 1;
    } else {
      threshold = 1;
    }
  }

  const fSeries = getDataSeries(db, factorSource, from, to);
  const mSeries = getDataSeries(
    db,
    metricSource,
    addDays(from, lag),
    addDays(to, lag),
  );
  const mByDate = new Map(mSeries.points.map((p) => [p.date, p.value]));

  const withArr: number[] = [];
  const withoutArr: number[] = [];
  for (const p of fSeries.points) {
    const mv = mByDate.get(addDays(p.date, lag));
    if (mv === undefined) continue;
    if (p.value >= threshold) withArr.push(mv);
    else withoutArr.push(mv);
  }
  if (withArr.length < 2 || withoutArr.length < 2) return null;

  const withMean = mean(withArr);
  const withoutMean = mean(withoutArr);
  const deltaPct =
    withoutMean !== 0 ? ((withMean - withoutMean) / withoutMean) * 100 : 0;
  const { p } = welchT(withArr, withoutArr);

  return {
    factorSource,
    metricSource,
    lag,
    threshold,
    withMean: round(withMean, 1),
    withoutMean: round(withoutMean, 1),
    deltaPct: round(deltaPct, 1),
    nWith: withArr.length,
    nWithout: withoutArr.length,
    pValue: round(p, 4),
    significance: significanceFromP(p),
  };
}

// ---------- auto insights ----------

function strengthWord(abs: number): string {
  if (abs >= 0.7) return "сильная";
  if (abs >= 0.4) return "умеренная";
  return "слабая";
}

function corrInsight(db: DB, c: Correlation): Insight {
  const la = sourceLabel(db, c.seriesA);
  const lb = sourceLabel(db, c.seriesB);
  const dir = c.coefficient > 0 ? "положительная" : "отрицательная";
  const lagNote = c.lag ? `, лаг ${c.lag}д` : "";
  return {
    kind: "correlation",
    factorSource: c.seriesA,
    metricSource: c.seriesB,
    lag: c.lag,
    coefficient: c.coefficient,
    pValue: c.pValue,
    significance: c.significance,
    dataPoints: c.dataPoints,
    summary: `«${la}» ↔ «${lb}»: ${strengthWord(Math.abs(c.coefficient))} ${dir} связь (ρ=${c.coefficient}, n=${c.dataPoints}${lagNote}) — вероятная, не причинность`,
  };
}

function groupInsight(db: DB, g: GroupComparison): Insight {
  const lf = sourceLabel(db, g.factorSource);
  const lm = sourceLabel(db, g.metricSource);
  const dir = g.deltaPct < 0 ? "ниже" : "выше";
  const lagNote = g.lag ? `, лаг ${g.lag}д` : "";
  return {
    kind: "group",
    factorSource: g.factorSource,
    metricSource: g.metricSource,
    lag: g.lag,
    deltaPct: g.deltaPct,
    pValue: g.pValue,
    significance: g.significance,
    dataPoints: g.nWith + g.nWithout,
    summary: `В дни с «${lf}» показатель «${lm}» ${dir} на ${Math.abs(g.deltaPct)}% (n=${g.nWith} vs ${g.nWithout}${lagNote}) — наблюдение, не причинность`,
  };
}

// Scan factor × (everything) at lag 0 and +1, keep the strongest significant
// signal per pair, sorted by p-value. Powers the "beer → sleep" Insights view.
export function getAutoInsights(
  db: DB,
  from: string,
  to: string,
): Insight[] {
  const sources = listCorrelationSources(db);
  const factorSrcs = sources.filter((s) => s.kind === "factor");
  const insights: Insight[] = [];

  for (const f of factorSrcs) {
    for (const m of sources) {
      if (m.id === f.id) continue;
      // For factor-factor pairs, keep a single direction to avoid duplicates.
      if (m.kind === "factor" && m.id < f.id) continue;

      let best: Insight | null = null;
      for (const lag of [0, 1]) {
        const c = getCorrelation(db, f.id, m.id, from, to, { lag });
        if (c && c.significance !== "none") {
          if (!best || c.pValue < best.pValue) best = corrInsight(db, c);
        }
        const g = getGroupComparison(db, f.id, m.id, from, to, { lag });
        if (g && g.significance !== "none") {
          if (!best || g.pValue < best.pValue) best = groupInsight(db, g);
        }
      }
      if (best) insights.push(best);
    }
  }

  return insights.sort((a, b) => a.pValue - b.pValue).slice(0, 12);
}
