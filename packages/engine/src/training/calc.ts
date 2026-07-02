// Pure computation helpers for the training domain.
// Everything works in integer grams — no floating point stored anywhere.

/**
 * Estimated 1-rep max (Epley), in grams.
 * e1RM = weight * (1 + reps / 30)
 */
export function epley1RM(weightG: number, reps: number): number {
  if (weightG <= 0 || reps <= 0) return 0;
  return Math.round(weightG * (1 + reps / 30));
}

/** Volume of a single set in gram-reps: weight_g * reps. */
export function setVolumeG(weightG: number, reps: number): number {
  return weightG * reps;
}

/** Round a weight to the nearest loading increment (e.g. 2500 g plates). */
export function roundToIncrement(weightG: number, incrementG: number): number {
  if (incrementG <= 0) return Math.round(weightG);
  return Math.round(weightG / incrementG) * incrementG;
}
