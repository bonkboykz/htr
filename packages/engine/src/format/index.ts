export function formatCalories(kcal: number): string {
  return `${kcal.toLocaleString("en-US").replace(/,/g, " ")} kcal`;
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

export function formatProgress(current: number, target: number): number {
  if (target <= 0) return 0;
  return Math.min(100, Math.round((current / target) * 100));
}
