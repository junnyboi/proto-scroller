export type WebRenderTier = "desktop" | "performance";

export type WebRenderResolution = {
  cssWidth: number;
  cssHeight: number;
  devicePixelRatio: number;
  width: number;
  height: number;
  tier: WebRenderTier;
};

const DESKTOP_MAX_WIDTH = 1600;
const DESKTOP_MAX_HEIGHT = 900;
const PERFORMANCE_MAX_WIDTH = 1280;
const PERFORMANCE_MAX_HEIGHT = 720;

function positiveDimension(value: number): number {
  if (!Number.isFinite(value)) return 1;
  return Math.max(1, value);
}

export function calculateWebRenderResolution(
  cssWidth: number,
  cssHeight: number,
  devicePixelRatio: number,
  tier: WebRenderTier
): WebRenderResolution {
  const safeCssWidth = positiveDimension(cssWidth);
  const safeCssHeight = positiveDimension(cssHeight);
  const safeDevicePixelRatio = positiveDimension(devicePixelRatio);
  const desiredWidth = safeCssWidth * safeDevicePixelRatio;
  const desiredHeight = safeCssHeight * safeDevicePixelRatio;
  const landscapeMaxWidth =
    tier === "performance" ? PERFORMANCE_MAX_WIDTH : DESKTOP_MAX_WIDTH;
  const landscapeMaxHeight =
    tier === "performance" ? PERFORMANCE_MAX_HEIGHT : DESKTOP_MAX_HEIGHT;
  const portrait = safeCssHeight > safeCssWidth;
  const maxWidth = portrait ? landscapeMaxHeight : landscapeMaxWidth;
  const maxHeight = portrait ? landscapeMaxWidth : landscapeMaxHeight;
  const scale = Math.min(1, maxWidth / desiredWidth, maxHeight / desiredHeight);

  return {
    cssWidth: safeCssWidth,
    cssHeight: safeCssHeight,
    devicePixelRatio: safeDevicePixelRatio,
    width: Math.max(1, Math.round(desiredWidth * scale)),
    height: Math.max(1, Math.round(desiredHeight * scale)),
    tier,
  };
}

export function selectWebRenderTier(
  requestedTier: string | null,
  touchPoints: number
): WebRenderTier {
  if (requestedTier === "performance") return "performance";
  if (requestedTier === "desktop") return "desktop";
  return touchPoints > 0 ? "performance" : "desktop";
}
