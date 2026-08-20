export type GodotFileSizes = Record<string, number>;

export type DownloadTelemetry = {
  bytesPerSecond: number | null;
  etaSeconds: number | null;
};

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

export function formatDownloadSpeed(bytesPerSecond: number | null): string {
  if (bytesPerSecond === null || !Number.isFinite(bytesPerSecond) || bytesPerSecond <= 0) {
    return "MEASURING";
  }
  if (bytesPerSecond >= 1_048_576) {
    return `${(bytesPerSecond / 1_048_576).toFixed(1)} MiB/s`;
  }
  if (bytesPerSecond >= 1_024) {
    return `${(bytesPerSecond / 1_024).toFixed(1)} KiB/s`;
  }
  return `${Math.round(bytesPerSecond)} B/s`;
}

export function formatEta(etaSeconds: number | null): string {
  if (etaSeconds === null || !Number.isFinite(etaSeconds) || etaSeconds < 0) {
    return "CALCULATING";
  }
  if (etaSeconds === 0) return "READY";
  const totalSeconds = Math.max(1, Math.ceil(etaSeconds));
  if (totalSeconds < 60) return `${totalSeconds}s`;
  if (totalSeconds < 3_600) {
    const minutes = Math.floor(totalSeconds / 60);
    const seconds = totalSeconds % 60;
    return seconds === 0 ? `${minutes}m` : `${minutes}m ${seconds}s`;
  }
  const hours = Math.floor(totalSeconds / 3_600);
  const minutes = Math.ceil((totalSeconds % 3_600) / 60);
  return minutes === 0 ? `${hours}h` : `${hours}h ${minutes}m`;
}

export class DownloadTelemetryTracker {
  private readonly smoothingFactor: number;
  private readonly minimumSampleMs: number;
  private lastBytes: number | null = null;
  private lastTimestampMs: number | null = null;
  private smoothedBytesPerSecond: number | null = null;

  constructor(smoothingFactor = 0.25, minimumSampleMs = 250) {
    this.smoothingFactor = Math.min(1, Math.max(0.01, smoothingFactor));
    this.minimumSampleMs = Math.max(0, minimumSampleMs);
  }

  sample(currentBytes: number, totalBytes: number, timestampMs: number): DownloadTelemetry {
    if (
      !Number.isFinite(currentBytes) ||
      !Number.isFinite(totalBytes) ||
      !Number.isFinite(timestampMs) ||
      currentBytes < 0 ||
      totalBytes <= 0
    ) {
      return { bytesPerSecond: null, etaSeconds: null };
    }

    if (
      this.lastBytes === null ||
      this.lastTimestampMs === null ||
      currentBytes < this.lastBytes ||
      timestampMs < this.lastTimestampMs
    ) {
      this.lastBytes = currentBytes;
      this.lastTimestampMs = timestampMs;
      this.smoothedBytesPerSecond = null;
      return this.currentEstimate(currentBytes, totalBytes);
    }

    const elapsedMs = timestampMs - this.lastTimestampMs;
    const downloadedBytes = currentBytes - this.lastBytes;
    if (elapsedMs >= this.minimumSampleMs && downloadedBytes > 0) {
      const instantaneousBytesPerSecond = downloadedBytes / (elapsedMs / 1_000);
      this.smoothedBytesPerSecond = this.smoothedBytesPerSecond === null
        ? instantaneousBytesPerSecond
        : this.smoothingFactor * instantaneousBytesPerSecond +
          (1 - this.smoothingFactor) * this.smoothedBytesPerSecond;
      this.lastBytes = currentBytes;
      this.lastTimestampMs = timestampMs;
    }

    return this.currentEstimate(currentBytes, totalBytes);
  }

  private currentEstimate(currentBytes: number, totalBytes: number): DownloadTelemetry {
    const remainingBytes = Math.max(0, totalBytes - currentBytes);
    const etaSeconds = remainingBytes === 0
      ? 0
      : this.smoothedBytesPerSecond === null || this.smoothedBytesPerSecond <= 0
        ? null
        : remainingBytes / this.smoothedBytesPerSecond;
    return {
      bytesPerSecond: this.smoothedBytesPerSecond,
      etaSeconds,
    };
  }
}
