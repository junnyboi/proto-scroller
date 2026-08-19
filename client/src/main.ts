import "./index.css";

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
  }
}

const ENGINE_SCRIPT_ID = "proto-scroller-godot-engine";
const GAME_PACK_VERSION = "3df65b4b";
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

  const engine = new Engine({
    args: [],
    canvas,
    canvasResizePolicy: 2,
    emscriptenPoolSize: 8,
    ensureCrossOriginIsolationHeaders: true,
    executable: "/manus-storage/game_2fedf84c",
    experimentalVK: false,
    fileSizes: {},
    focusCanvas: true,
    gdextensionLibs: [],
    godotPoolSize: 4,
    mainPack: `/manus-storage/game_c869ad93.pck?v=${GAME_PACK_VERSION}`,
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
        : "The Godot runtime failed to initialize.",
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
    { once: true },
  );
  document.head.appendChild(script);
}
