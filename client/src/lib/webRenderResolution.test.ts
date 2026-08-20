import { describe, expect, it } from "vitest";
import {
  calculateWebRenderResolution,
  selectWebRenderTier,
} from "./webRenderResolution";

describe("calculateWebRenderResolution", () => {
  it("keeps a DPR 1 landscape canvas at CSS resolution", () => {
    expect(calculateWebRenderResolution(1280, 720, 1, "desktop")).toMatchObject(
      {
        width: 1280,
        height: 720,
      }
    );
  });

  it("caps DPR 2 and DPR 3 landscape canvases at 1600x900", () => {
    for (const devicePixelRatio of [2, 3]) {
      expect(
        calculateWebRenderResolution(1280, 720, devicePixelRatio, "desktop")
      ).toMatchObject({ width: 1600, height: 900 });
    }
  });

  it("caps the performance tier at 1280x720", () => {
    expect(
      calculateWebRenderResolution(1600, 900, 3, "performance")
    ).toMatchObject({ width: 1280, height: 720 });
  });

  it("preserves portrait aspect while respecting the performance pixel budget", () => {
    const resolution = calculateWebRenderResolution(390, 844, 3, "performance");

    expect(resolution.width).toBeLessThanOrEqual(720);
    expect(resolution.height).toBeLessThanOrEqual(1280);
    expect(resolution.width / resolution.height).toBeCloseTo(390 / 844, 2);
  });

  it("does not upscale a small canvas past its physical pixel size", () => {
    expect(
      calculateWebRenderResolution(640, 360, 2, "performance")
    ).toMatchObject({ width: 1280, height: 720 });
  });
});

describe("selectWebRenderTier", () => {
  it("uses the performance tier for touch-capable browsers by default", () => {
    expect(selectWebRenderTier(null, 5)).toBe("performance");
  });

  it("honors explicit desktop and performance overrides", () => {
    expect(selectWebRenderTier("desktop", 5)).toBe("desktop");
    expect(selectWebRenderTier("performance", 0)).toBe("performance");
  });
});
