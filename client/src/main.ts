import "./index.css";
import {
  calculateLoadingPercent,
  createGodotFileSizes,
  DownloadTelemetryTracker,
  formatDownloadSpeed,
  formatEta,
  loadingStage,
} from "./lib/godotLoaderState";
import {
  calculateWebRenderResolution,
  selectWebRenderTier,
  type WebRenderResolution,
} from "./lib/webRenderResolution";

type GodotConfig = {
  args: string[];
  audioWorkletBase?: string;
  canvas: HTMLCanvasElement;
  canvasResizePolicy: number;
  emscriptenPoolSize: number;
  ensureCrossOriginIsolationHeaders: boolean;
  executable: string;
  experimentalVK: boolean;
  fileSizes: Record<string, number>;
  focusCanvas: boolean;
  gdextensionLibs: string[];
  godotPoolSize: number;
  mainPack: string;
};

type GodotEngine = {
  startGame: (options: {
    onProgress: (current: number, total: number) => void;
  }) => Promise<void>;
};

type GodotEngineConstructor = {
  new (config: GodotConfig): GodotEngine;
  getMissingFeatures: (options: { threads: boolean }) => string[];
};

declare global {
  interface Window {
    Engine?: GodotEngineConstructor;
    protoScrollerResolution?: WebRenderResolution;
  }
}

const ENGINE_SCRIPT_ID = "proto-scroller-godot-engine";
const GAME_PACK_VERSION = "5a37cd64-voice-priority";
const REMOTE_ENGINE_PATH = "/manus-storage/game_e2f01e77";
const REMOTE_PACK_PATH = `/manus-storage/game_ffe4d3c1.pck?v=${GAME_PACK_VERSION}`;
const ENGINE_WASM_BYTES = 39_513_091;
const GAME_PACK_BYTES = 7_763_444;
const SLOW_LOAD_NOTICE_MS = 15_000;
const RETRY_NOTICE_MS = 45_000;
const searchParameters = new URLSearchParams(window.location.search);
const root = document.getElementById("root");

if (!root) {
  throw new Error("Missing game root element.");
}

root.innerHTML = `
  <main class="game-host">
    <canvas id="canvas" class="game-canvas" tabindex="0" aria-label="Proto Scroller">
      Your browser does not support the canvas element.
    </canvas>
    <section id="runtime-state" class="runtime-state" role="status" aria-live="polite">
      <div class="loader-console">
        <p class="loader-kicker">PROTO SCROLLER // WEB RUNTIME</p>
        <p id="loader-stage" class="loader-stage">PREPARING ENGINE</p>
        <div class="loader-progress-row">
          <progress id="loader-progress" class="loader-progress" max="100"></progress>
          <span id="loader-percent" class="loader-percent">CONNECTING</span>
        </div>
        <dl class="loader-telemetry" aria-label="Download telemetry">
          <div class="loader-telemetry-item">
            <dt>SPEED</dt>
            <dd id="loader-speed">MEASURING</dd>
          </div>
          <div class="loader-telemetry-item">
            <dt>ETA</dt>
            <dd id="loader-eta">CALCULATING</dd>
          </div>
        </dl>
        <p id="loader-detail" class="loader-detail">Loading the Web runtime…</p>
        <button id="loader-retry" class="loader-retry" type="button" hidden>RETRY DOWNLOAD</button>
      </div>
    </section>
  </main>
`;

function requireElement<T extends HTMLElement>(id: string): T {
  const element = document.getElementById(id);
  if (!element) throw new Error(`Missing loader element: ${id}`);
  return element as T;
}

const canvas = requireElement<HTMLCanvasElement>("canvas");
const runtimeState = requireElement<HTMLElement>("runtime-state");
const loaderStage = requireElement<HTMLElement>("loader-stage");
const loaderProgress = requireElement<HTMLProgressElement>("loader-progress");
const loaderPercent = requireElement<HTMLElement>("loader-percent");
const loaderSpeed = requireElement<HTMLElement>("loader-speed");
const loaderEta = requireElement<HTMLElement>("loader-eta");
const loaderDetail = requireElement<HTMLElement>("loader-detail");
const loaderRetry = requireElement<HTMLButtonElement>("loader-retry");
const renderTier = selectWebRenderTier(
  searchParameters.get("renderTier"),
  navigator.maxTouchPoints
);
let resizeFrame = 0;
let loadingComplete = false;
let latestPercent: number | null = null;
const downloadTelemetry = new DownloadTelemetryTracker();

loaderRetry.addEventListener("click", () => window.location.reload());

function updateCanvasResolution(): void {
  const bounds = canvas.getBoundingClientRect();
  const resolution = calculateWebRenderResolution(
    bounds.width || window.innerWidth,
    bounds.height || window.innerHeight,
    window.devicePixelRatio,
    renderTier
  );

  if (canvas.width !== resolution.width) canvas.width = resolution.width;
  if (canvas.height !== resolution.height) canvas.height = resolution.height;
  canvas.dataset.renderTier = resolution.tier;
  canvas.dataset.renderResolution = `${resolution.width}x${resolution.height}`;
  window.protoScrollerResolution = resolution;
}

function queueCanvasResolutionUpdate(): void {
  window.cancelAnimationFrame(resizeFrame);
  resizeFrame = window.requestAnimationFrame(updateCanvasResolution);
}

function formatMebibytes(bytes: number): string {
  return `${(bytes / 1_048_576).toFixed(1)} MiB`;
}

function showDownloadProgress(current: number, total: number): void {
  const percent = calculateLoadingPercent(current, total);
  const telemetry = downloadTelemetry.sample(current, total, performance.now());
  latestPercent = percent;
  if (percent === null) {
    loaderProgress.removeAttribute("value");
    loaderPercent.textContent = "CONNECTING";
    loaderSpeed.textContent = "MEASURING";
    loaderEta.textContent = "CALCULATING";
    return;
  }

  loaderProgress.value = percent;
  loaderPercent.textContent = `${percent}%`;
  loaderSpeed.textContent = formatDownloadSpeed(telemetry.bytesPerSecond);
  loaderEta.textContent = formatEta(telemetry.etaSeconds);
  loaderStage.textContent = loadingStage(percent);
  loaderDetail.textContent = `${formatMebibytes(current)} / ${formatMebibytes(total)}`;
}

function showError(message: string): void {
  console.error(message);
  runtimeState.classList.add("is-error");
  loaderStage.textContent = "LOAD FAILED";
  loaderPercent.textContent = "OFFLINE";
  loaderSpeed.textContent = "—";
  loaderEta.textContent = "RETRY";
  loaderDetail.textContent = message;
  loaderProgress.hidden = true;
  loaderRetry.hidden = false;
}

function nextPaint(): Promise<void> {
  return new Promise((resolve) => window.requestAnimationFrame(() => resolve()));
}

updateCanvasResolution();
window.addEventListener("resize", queueCanvasResolutionUpdate, { passive: true });

const slowLoadTimer = window.setTimeout(() => {
  if (loadingComplete) return;
  loaderDetail.textContent = latestPercent === null
    ? "Connecting to game storage. This can take longer on a cold deployment…"
    : `${loaderPercent.textContent} received. Initializing the ${formatMebibytes(ENGINE_WASM_BYTES + GAME_PACK_BYTES)} runtime…`;
}, SLOW_LOAD_NOTICE_MS);

const retryTimer = window.setTimeout(() => {
  if (loadingComplete) return;
  loaderDetail.textContent = "Loading is taking longer than expected. You can retry safely.";
  loaderRetry.hidden = false;
}, RETRY_NOTICE_MS);

async function startEngine(): Promise<void> {
  const Engine = window.Engine;
  if (!Engine) return;

  const missing = Engine.getMissingFeatures({ threads: false });
  if (missing.length > 0) {
    showError(`Missing browser features: ${missing.join(", ")}`);
    return;
  }

  const useLocalGameFiles =
    import.meta.env.DEV && searchParameters.has("localGame");
  const useSplitWorkletSmoke =
    useLocalGameFiles && searchParameters.has("splitWorklets");
  const executable = useSplitWorkletSmoke
    ? "/remote-engine/smoke-engine"
    : useLocalGameFiles
      ? "/game/game"
      : REMOTE_ENGINE_PATH;
  const mainPack = useLocalGameFiles ? "/game/game.pck" : REMOTE_PACK_PATH;
  const engine = new Engine({
    args: [],
    audioWorkletBase: "/game/game",
    canvas,
    canvasResizePolicy: 0,
    emscriptenPoolSize: 8,
    ensureCrossOriginIsolationHeaders: true,
    executable,
    experimentalVK: false,
    fileSizes: createGodotFileSizes(
      executable,
      mainPack,
      ENGINE_WASM_BYTES,
      GAME_PACK_BYTES
    ),
    focusCanvas: true,
    gdextensionLibs: [],
    godotPoolSize: 4,
    mainPack,
  });

  loaderStage.textContent = "DOWNLOADING GAME DATA";
  loaderDetail.textContent = "Downloading engine and game pack…";

  try {
    await engine.startGame({ onProgress: showDownloadProgress });
    loadingComplete = true;
    window.clearTimeout(slowLoadTimer);
    window.clearTimeout(retryTimer);
    loaderStage.textContent = "STARTING GAME";
    loaderPercent.textContent = "100%";
    loaderSpeed.textContent = "COMPLETE";
    loaderEta.textContent = "READY";
    loaderProgress.value = 100;
    loaderDetail.textContent = "Runtime ready.";
    canvas.classList.add("is-ready");
    await nextPaint();
    await nextPaint();
    runtimeState.remove();
    canvas.focus();
  } catch (runtimeError) {
    showError(
      runtimeError instanceof Error
        ? runtimeError.message
        : "The Godot runtime failed to initialize."
    );
  }
}

if (window.Engine) {
  void startEngine();
} else {
  const script = document.createElement("script");
  script.id = ENGINE_SCRIPT_ID;
  script.src = "/game/game.js";
  script.async = true;
  script.addEventListener("load", () => void startEngine(), { once: true });
  script.addEventListener(
    "error",
    () => showError("The Godot engine loader could not be downloaded."),
    { once: true }
  );
  document.head.appendChild(script);
}
