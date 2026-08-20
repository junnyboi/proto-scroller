import { describe, expect, it } from "vitest";
import {
  calculateLoadingPercent,
  createGodotFileSizes,
  loadingStage,
} from "./godotLoaderState";

describe("createGodotFileSizes", () => {
  it("keys byte totals by the exact remote URLs consumed by Godot", () => {
    const executable = "/manus-storage/engine_123";
    const mainPack = "/manus-storage/game_456.pck?v=abcdef12";

    expect(createGodotFileSizes(executable, mainPack, 40_000_000, 8_000_000)).toEqual(
      {
        [`${executable}.wasm`]: 40_000_000,
        [mainPack]: 8_000_000,
      }
    );
  });
});

describe("calculateLoadingPercent", () => {
  it("reports aggregate byte progress and clamps its output", () => {
    expect(calculateLoadingPercent(12, 48)).toBe(25);
    expect(calculateLoadingPercent(60, 48)).toBe(100);
  });

  it("rejects missing or invalid totals instead of displaying false progress", () => {
    expect(calculateLoadingPercent(12, 0)).toBeNull();
    expect(calculateLoadingPercent(-1, 48)).toBeNull();
    expect(calculateLoadingPercent(Number.NaN, 48)).toBeNull();
  });
});

describe("loadingStage", () => {
  it("advances from download through assembly to startup", () => {
    expect(loadingStage(42)).toBe("DOWNLOADING GAME DATA");
    expect(loadingStage(80)).toBe("ASSEMBLING RUNTIME");
    expect(loadingStage(100)).toBe("STARTING GAME");
  });
});
