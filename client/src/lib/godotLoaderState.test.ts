import { describe, expect, it } from "vitest";
import {
  calculateLoadingPercent,
  createGodotFileSizes,
  DownloadTelemetryTracker,
  formatDownloadSpeed,
  formatEta,
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

describe("DownloadTelemetryTracker", () => {
  it("calculates throughput and ETA from aggregate byte samples", () => {
    const tracker = new DownloadTelemetryTracker(0.25, 0);

    expect(tracker.sample(0, 10_000_000, 0)).toEqual({
      bytesPerSecond: null,
      etaSeconds: null,
    });
    expect(tracker.sample(2_000_000, 10_000_000, 1_000)).toEqual({
      bytesPerSecond: 2_000_000,
      etaSeconds: 4,
    });
    expect(tracker.sample(4_000_000, 10_000_000, 2_000)).toEqual({
      bytesPerSecond: 2_000_000,
      etaSeconds: 3,
    });
  });

  it("smooths speed changes and resets safely when a retry lowers loaded bytes", () => {
    const tracker = new DownloadTelemetryTracker(0.25, 0);
    tracker.sample(0, 10_000_000, 0);
    tracker.sample(1_000_000, 10_000_000, 1_000);

    expect(tracker.sample(4_000_000, 10_000_000, 2_000).bytesPerSecond).toBe(
      1_500_000
    );
    expect(tracker.sample(500_000, 10_000_000, 3_000)).toEqual({
      bytesPerSecond: null,
      etaSeconds: null,
    });
  });

  it("reports a zero-second ETA when all bytes are present", () => {
    const tracker = new DownloadTelemetryTracker(0.25, 0);
    expect(tracker.sample(10_000_000, 10_000_000, 0).etaSeconds).toBe(0);
  });
});

describe("telemetry formatting", () => {
  it("formats speed across byte, KiB, and MiB ranges", () => {
    expect(formatDownloadSpeed(null)).toBe("MEASURING");
    expect(formatDownloadSpeed(900)).toBe("900 B/s");
    expect(formatDownloadSpeed(32_768)).toBe("32.0 KiB/s");
    expect(formatDownloadSpeed(2_097_152)).toBe("2.0 MiB/s");
  });

  it("formats short and long ETAs compactly", () => {
    expect(formatEta(null)).toBe("CALCULATING");
    expect(formatEta(0)).toBe("READY");
    expect(formatEta(8.2)).toBe("9s");
    expect(formatEta(62)).toBe("1m 2s");
    expect(formatEta(3_660)).toBe("1h 1m");
  });
});
