export type GodotFileSizes = Record<string, number>;

export function createGodotFileSizes(
  executable: string,
  mainPack: string,
  wasmBytes: number,
  packBytes: number
): GodotFileSizes {
  return {
    [`${executable}.wasm`]: wasmBytes,
    [mainPack]: packBytes,
  };
}

export function calculateLoadingPercent(
  currentBytes: number,
  totalBytes: number
): number | null {
  if (!Number.isFinite(currentBytes) || !Number.isFinite(totalBytes)) {
    return null;
  }
  if (currentBytes < 0 || totalBytes <= 0) return null;
  return Math.min(100, Math.max(0, Math.round((currentBytes / totalBytes) * 100)));
}

export function loadingStage(percent: number): string {
  if (percent >= 100) return "STARTING GAME";
  if (percent >= 80) return "ASSEMBLING RUNTIME";
  return "DOWNLOADING GAME DATA";
}
