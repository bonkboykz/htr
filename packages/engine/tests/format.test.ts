import { describe, it, expect } from "vitest";
import {
  formatCalories,
  formatMacro,
  formatWeight,
  formatWater,
  formatSleep,
  formatBodyFat,
  formatProgress,
} from "../src/index.js";

describe("formatCalories", () => {
  it("formats small values without separator", () => {
    expect(formatCalories(500)).toBe("500 kcal");
  });

  it("formats thousands with space separator", () => {
    expect(formatCalories(2150)).toBe("2 150 kcal");
  });

  it("formats zero", () => {
    expect(formatCalories(0)).toBe("0 kcal");
  });

  it("formats large values", () => {
    expect(formatCalories(10500)).toBe("10 500 kcal");
  });
});

describe("formatMacro", () => {
  it("converts tenths of grams to grams with one decimal", () => {
    expect(formatMacro(253)).toBe("25.3 g");
  });

  it("formats zero", () => {
    expect(formatMacro(0)).toBe("0.0 g");
  });

  it("formats whole number tenths", () => {
    expect(formatMacro(100)).toBe("10.0 g");
  });

  it("formats small values", () => {
    expect(formatMacro(5)).toBe("0.5 g");
  });
});

describe("formatWeight", () => {
  it("converts grams to kg with one decimal", () => {
    expect(formatWeight(75500)).toBe("75.5 kg");
  });

  it("formats whole kg", () => {
    expect(formatWeight(80000)).toBe("80.0 kg");
  });

  it("formats zero", () => {
    expect(formatWeight(0)).toBe("0.0 kg");
  });

  it("formats sub-kg values", () => {
    expect(formatWeight(500)).toBe("0.5 kg");
  });
});

describe("formatWater", () => {
  it("formats ml below 1000", () => {
    expect(formatWater(250)).toBe("250 ml");
  });

  it("formats ml at exactly 1000 as liters", () => {
    expect(formatWater(1000)).toBe("1.0 L");
  });

  it("formats ml above 1000 as liters", () => {
    expect(formatWater(2100)).toBe("2.1 L");
  });

  it("formats zero", () => {
    expect(formatWater(0)).toBe("0 ml");
  });

  it("formats 999 as ml", () => {
    expect(formatWater(999)).toBe("999 ml");
  });
});

describe("formatSleep", () => {
  it("formats hours and minutes", () => {
    expect(formatSleep(465)).toBe("7h 45m");
  });

  it("formats exact hours", () => {
    expect(formatSleep(480)).toBe("8h 0m");
  });

  it("formats zero", () => {
    expect(formatSleep(0)).toBe("0h 0m");
  });

  it("formats less than an hour", () => {
    expect(formatSleep(30)).toBe("0h 30m");
  });
});

describe("formatBodyFat", () => {
  it("converts permille to percentage with one decimal", () => {
    expect(formatBodyFat(152)).toBe("15.2%");
  });

  it("formats whole percentage", () => {
    expect(formatBodyFat(200)).toBe("20.0%");
  });

  it("formats zero", () => {
    expect(formatBodyFat(0)).toBe("0.0%");
  });
});

describe("formatProgress", () => {
  it("returns percentage of target", () => {
    expect(formatProgress(50, 100)).toBe(50);
  });

  it("caps at 100", () => {
    expect(formatProgress(150, 100)).toBe(100);
  });

  it("returns 0 when target is 0", () => {
    expect(formatProgress(50, 0)).toBe(0);
  });

  it("returns 0 when target is negative", () => {
    expect(formatProgress(50, -10)).toBe(0);
  });

  it("rounds to nearest integer", () => {
    expect(formatProgress(1, 3)).toBe(33);
  });

  it("handles 0 current", () => {
    expect(formatProgress(0, 100)).toBe(0);
  });

  it("returns 100 when at target", () => {
    expect(formatProgress(2500, 2500)).toBe(100);
  });
});
