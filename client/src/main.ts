import "./index.css";
import {
  calculateWebRenderResolution,
  selectWebRenderTier,
  type WebRenderResolution,
} from "./lib/webRenderResolution";

type GodotConfig = {
  args: string[];
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
const GAME_PACK_VERSION = "47b5b908";
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
    <div id="runtime-state" class="runtime-state" role="status">0%</div>
  </main>
`;

const canvas = document.getElementById("canvas") as HTMLCanvasElement;
const runtimeState = document.getElementById("runtime-state") as HTMLDivElement;
const renderTier = selectWebRenderTier(
  searchParameters.get("renderTier"),
  navigator.maxTouchPoints
);
let resizeFrame = 0;

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

updateCanvasResolution();
window.addEventListener("resize", queueCanvasResolutionUpdate, {
  passive: true,
});

function showError(message: string): void {
  runtimeState.classList.add("is-error");
  runtimeState.textContent = message;
}

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
  const engine = new Engine({
    args: [],
    canvas,
    canvasResizePolicy: 0,
    emscriptenPoolSize: 8,
    ensureCrossOriginIsolationHeaders: true,
    executable: useLocalGameFiles
      ? "/game/game"
      : "/manus-storage/game_896746b1",
    experimentalVK: false,
    fileSizes: {},
    focusCanvas: true,
    gdextensionLibs: [],
    godotPoolSize: 4,
    mainPack: useLocalGameFiles
      ? "/game/game.pck"
      : `/manus-storage/game_3c7986ee.pck?v=${GAME_PACK_VERSION}`,
  });

  try {
    await engine.startGame({
      onProgress: (current, total) => {
        if (total > 0) {
          runtimeState.textContent = `${Math.round((current / total) * 100)}%`;
        }
      },
    });
    runtimeState.remove();
    canvas.classList.add("is-ready");
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
