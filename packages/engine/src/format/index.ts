export function formatCalories(kcal: number): string {
  return `${kcal.toLocaleString("en-US").replace(/,/g, " ")} ккал`;
}

export function formatMacro(tenths: number): string {
  const grams = tenths / 10;
  return `${grams.toFixed(1)} g`;
}

export function formatWeight(grams: number): string {
  const kg = grams / 1000;
  return `${kg.toFixed(1)} kg`;
}

export function formatWater(ml: number): string {
  if (ml >= 1000) {
    return `${(ml / 1000).toFixed(1)} L`;
  }
  return `${ml} ml`;
}

export function formatSleep(minutes: number): string {
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  return `${h}h ${m}m`;
}

export function formatBodyFat(permille: number): string {
  return `${(permille / 10).toFixed(1)}%`;
}

export function formatVolume(gramReps: number): string {
  if (gramReps >= 1_000_000) {
    return `${(gramReps / 1_000_000).toFixed(1)} t`;
  }
  return `${Math.round(gramReps / 1000)} kg`;
}

export function formatDuration(seconds: number): string {
  if (seconds < 60) return `${seconds}s`;
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = seconds % 60;
  if (h > 0) return s > 0 ? `${h}h ${m}m ${s}s` : `${h}h ${m}m`;
  return s > 0 ? `${m}m ${s}s` : `${m}m`;
}

export function formatProgress(current: number, target: number): number {
  if (target <= 0) return 0;
  return Math.min(100, Math.round((current / target) * 100));
}
