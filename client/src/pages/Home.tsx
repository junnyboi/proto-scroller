import { useEffect, useRef, useState } from "react";

type RuntimePhase = "loading" | "ready" | "error";

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
const GAME_PACK_VERSION = "34766798";

export default function Home() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const [phase, setPhase] = useState<RuntimePhase>("loading");
  const [progress, setProgress] = useState(0);
  const [error, setError] = useState("");

  useEffect(() => {
    let cancelled = false;

    const startEngine = async () => {
      const Engine = window.Engine;
      const canvas = canvasRef.current;
      if (!Engine || !canvas || cancelled) return;

      canvas.width = 1280;
      canvas.height = 720;

      const missing = Engine.getMissingFeatures({ threads: false });
      if (missing.length > 0) {
        setError(`Missing browser features: ${missing.join(", ")}`);
        setPhase("error");
        return;
      }

      const executable = "/game/game";
      const engine = new Engine({
        args: [],
        canvas,
        canvasResizePolicy: 0,
        emscriptenPoolSize: 8,
        ensureCrossOriginIsolationHeaders: true,
        executable,
        experimentalVK: false,
        fileSizes: {},
        focusCanvas: true,
        gdextensionLibs: [],
        godotPoolSize: 4,
        mainPack: `/game/game.pck?v=${GAME_PACK_VERSION}`,
      });

      try {
        await engine.startGame({
          onProgress: (current, total) => {
            if (cancelled || total <= 0) return;
            setProgress(Math.round((current / total) * 100));
          },
        });
        if (!cancelled) {
          setPhase("ready");
          canvas.focus();
        }
      } catch (runtimeError) {
        if (cancelled) return;
        const message =
          runtimeError instanceof Error
            ? runtimeError.message
            : "The Godot runtime failed to initialize.";
        setError(message);
        setPhase("error");
      }
    };

    if (window.Engine) {
      void startEngine();
    } else {
      const existingScript = document.getElementById(
        ENGINE_SCRIPT_ID,
      ) as HTMLScriptElement | null;
      const script = existingScript ?? document.createElement("script");
      if (!existingScript) {
        script.id = ENGINE_SCRIPT_ID;
        script.src = "/game/game.js";
        script.async = true;
        document.head.appendChild(script);
      }
      script.addEventListener("load", startEngine, { once: true });
      script.addEventListener(
        "error",
        () => {
          if (!cancelled) {
            setError("The Godot engine loader could not be downloaded.");
            setPhase("error");
          }
        },
        { once: true },
      );
    }

    return () => {
      cancelled = true;
    };
  }, []);

  return (
    <main className="game-host">
      <div className="ambient-grid" aria-hidden="true" />

      <header className="host-rail" aria-label="Proto Scroller deployment status">
        <div className="host-identity">
          <span className="signal-mark" aria-hidden="true" />
          <span>PROTO SCROLLER</span>
          <span className="rail-divider">/</span>
          <span className="rail-muted">AGENT 1 BUILD</span>
        </div>
        <div className="host-status">
          <span className="status-dot" aria-hidden="true" />
          {phase === "ready" ? "WEB RUNTIME ONLINE" : "LINKING WEB RUNTIME"}
        </div>
      </header>

      <section className="viewport-stage" aria-label="Playable Proto Scroller game">
        <div className="viewport-frame">
          <canvas
            id="canvas"
            ref={canvasRef}
            className={phase === "ready" ? "game-canvas is-loaded" : "game-canvas"}
            tabIndex={0}
            aria-label="Proto Scroller Godot game canvas"
          >
            Your browser does not support the canvas element.
          </canvas>

          {phase !== "ready" && (
            <div className={`loading-state ${phase === "error" ? "is-error" : ""}`} role="status">
              <span className="loading-line" aria-hidden="true" />
              <span>{phase === "error" ? "RUNTIME LINK FAILED" : "ESTABLISHING SIGNAL"}</span>
              {phase === "loading" && <span className="loading-progress">{progress}%</span>}
              {phase === "error" && <span className="error-detail">{error}</span>}
            </div>
          )}
        </div>
      </section>

      <footer className="host-footer">
        <span>GODOT 4.7.1 / WEBASSEMBLY</span>
        <span>1280 × 720 / COMPATIBILITY</span>
      </footer>
    </main>
  );
}
