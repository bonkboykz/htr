// Pure statistics for correlations — no external libraries.
import type { Significance } from "../types.js";

function mean(xs: number[]): number {
  return xs.reduce((a, b) => a + b, 0) / xs.length;
}

// Sample variance (divide by n-1).
function variance(xs: number[], m: number): number {
  if (xs.length < 2) return 0;
  return xs.reduce((s, x) => s + (x - m) * (x - m), 0) / (xs.length - 1);
}

// Average ranks for ties (1-based).
export function rankWithTies(values: number[]): number[] {
  const n = values.length;
  const order = values
    .map((v, i) => [v, i] as [number, number])
    .sort((a, b) => a[0] - b[0]);
  const ranks = new Array<number>(n).fill(0);
  let i = 0;
  while (i < n) {
    let j = i;
    while (j < n - 1 && order[j + 1][0] === order[i][0]) j++;
    const avgRank = (i + j) / 2 + 1; // positions i..j → average 1-based rank
    for (let k = i; k <= j; k++) ranks[order[k][1]] = avgRank;
    i = j + 1;
  }
  return ranks;
}

function pearson(a: number[], b: number[]): number {
  const ma = mean(a);
  const mb = mean(b);
  let num = 0;
  let da = 0;
  let db = 0;
  for (let i = 0; i < a.length; i++) {
    const x = a[i] - ma;
    const y = b[i] - mb;
    num += x * y;
    da += x * x;
    db += y * y;
  }
  const denom = Math.sqrt(da * db);
  return denom === 0 ? 0 : num / denom;
}

// Tie-corrected Spearman rho = Pearson correlation of ranks.
export function spearman(a: number[], b: number[]): number {
  return pearson(rankWithTies(a), rankWithTies(b));
}

// ---- Student's t two-tailed p-value via the regularized incomplete beta ----

function gammaln(x: number): number {
  const cof = [
    76.18009172947146, -86.50532032941677, 24.01409824083091,
    -1.231739572450155, 0.1208650973866179e-2, -0.5395239384953e-5,
  ];
  let y = x;
  let tmp = x + 5.5;
  tmp -= (x + 0.5) * Math.log(tmp);
  let ser = 1.000000000190015;
  for (let j = 0; j < 6; j++) {
    y++;
    ser += cof[j] / y;
  }
  return -tmp + Math.log((2.5066282746310005 * ser) / x);
}

function betacf(a: number, b: number, x: number): number {
  const MAXIT = 200;
  const EPS = 3e-12;
  const FPMIN = 1e-300;
  const qab = a + b;
  const qap = a + 1;
  const qam = a - 1;
  let c = 1;
  let d = 1 - (qab * x) / qap;
  if (Math.abs(d) < FPMIN) d = FPMIN;
  d = 1 / d;
  let h = d;
  for (let m = 1; m <= MAXIT; m++) {
    const m2 = 2 * m;
    let aa = (m * (b - m) * x) / ((qam + m2) * (a + m2));
    d = 1 + aa * d;
    if (Math.abs(d) < FPMIN) d = FPMIN;
    c = 1 + aa / c;
    if (Math.abs(c) < FPMIN) c = FPMIN;
    d = 1 / d;
    h *= d * c;
    aa = (-(a + m) * (qab + m) * x) / ((a + m2) * (qap + m2));
    d = 1 + aa * d;
    if (Math.abs(d) < FPMIN) d = FPMIN;
    c = 1 + aa / c;
    if (Math.abs(c) < FPMIN) c = FPMIN;
    d = 1 / d;
    const del = d * c;
    h *= del;
    if (Math.abs(del - 1) < EPS) break;
  }
  return h;
}

// Regularized incomplete beta I_x(a,b).
function betai(a: number, b: number, x: number): number {
  if (x <= 0) return 0;
  if (x >= 1) return 1;
  const bt = Math.exp(
    gammaln(a + b) -
      gammaln(a) -
      gammaln(b) +
      a * Math.log(x) +
      b * Math.log(1 - x),
  );
  if (x < (a + 1) / (a + b + 2)) return (bt * betacf(a, b, x)) / a;
  return 1 - (bt * betacf(b, a, 1 - x)) / b;
}

// Two-tailed p-value P(|T| > |t|) for Student's t with df degrees of freedom.
export function studentTwoTailP(t: number, df: number): number {
  if (df <= 0) return 1;
  const x = df / (df + t * t);
  return betai(df / 2, 0.5, x);
}

// p-value for a Spearman/Pearson correlation coefficient over n paired points.
export function corrPValue(rho: number, n: number): number {
  if (n < 3) return 1;
  if (Math.abs(rho) >= 1) return 0;
  const df = n - 2;
  const t = rho * Math.sqrt(df / (1 - rho * rho));
  return studentTwoTailP(t, df);
}

// Welch's unequal-variance t-test → { t, df, p }.
export function welchT(
  a: number[],
  b: number[],
): { t: number; df: number; p: number } {
  if (a.length < 2 || b.length < 2) return { t: 0, df: 0, p: 1 };
  const ma = mean(a);
  const mb = mean(b);
  const sa = variance(a, ma) / a.length;
  const sb = variance(b, mb) / b.length;
  const denom = Math.sqrt(sa + sb);
  if (denom === 0) return { t: 0, df: 0, p: 1 };
  const t = (ma - mb) / denom;
  const df =
    (sa + sb) ** 2 /
    (sa ** 2 / (a.length - 1) + sb ** 2 / (b.length - 1));
  return { t, df, p: studentTwoTailP(t, df) };
}

export function significanceFromP(p: number): Significance {
  if (p < 0.01) return "high";
  if (p < 0.05) return "medium";
  if (p < 0.1) return "low";
  return "none";
}
