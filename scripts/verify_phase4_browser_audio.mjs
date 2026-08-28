import { spawn } from "node:child_process";
import { mkdir, rm, symlink, writeFile } from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright-core";

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(SCRIPT_DIR, "..");
const ENGINE_DIR = path.join(ROOT, "client", "public", "remote-engine");
const REPORT_PATH = process.env.PHASE4_AUDIO_REPORT ?? "/tmp/proto-scroller-phase4-browser-audio.json";
const PORT = Number(process.env.PHASE4_AUDIO_PORT ?? 4184);
const BASE_URL = `http://127.0.0.1:${PORT}`;
const URL = `${BASE_URL}/?localGame=1&splitWorklets=1`;

let browser;
let server;
const browserErrors = [];
const requestFailures = [];
const report = { status: "FAIL", url: URL, browserErrors, requestFailures };

try {
  await rm(ENGINE_DIR, { recursive: true, force: true });
  await mkdir(ENGINE_DIR, { recursive: true });
  await symlink(
    path.join(ROOT, "client", "public", "game", "game.wasm"),
    path.join(ENGINE_DIR, "smoke-engine.wasm")
  );
  server = spawn(
    "pnpm",
    ["exec", "vite", "--host", "127.0.0.1", "--port", String(PORT), "--strictPort"],
    { cwd: ROOT, env: { ...process.env, BROWSER: "none" }, detached: true, stdio: "ignore" }
  );
  await waitForHttp(`${BASE_URL}/`, 30_000);
  browser = await chromium.launch({
    executablePath: process.env.CHROMIUM_PATH ?? "/usr/bin/chromium",
    headless: true,
    args: [
      "--no-sandbox",
      "--disable-dev-shm-usage",
      "--disable-gpu-compositing",
      "--use-angle=swiftshader-webgl",
    ],
  });
  const context = await browser.newContext({ viewport: { width: 1280, height: 720 } });
  await context.addInitScript(() => {
    const NativeAudioContext = window.AudioContext ?? window.webkitAudioContext;
    window.__PHASE4_AUDIO_CONTEXTS__ = [];
    window.__PHASE4_WORKLETS__ = [];
    window.__PHASE4_BUFFER_STARTS__ = [];
    const sourcePrototype = window.AudioBufferSourceNode?.prototype;
    if (sourcePrototype) {
      const nativeStart = sourcePrototype.start;
      sourcePrototype.start = function (when = 0, offset = 0, duration) {
        window.__PHASE4_BUFFER_STARTS__.push({
          hasBuffer: this.buffer instanceof AudioBuffer,
          length: this.buffer?.length ?? 0,
          sampleRate: this.buffer?.sampleRate ?? 0,
          channels: this.buffer?.numberOfChannels ?? 0,
          when,
        });
        if (duration === undefined) nativeStart.call(this, when, offset);
        else nativeStart.call(this, when, offset, duration);
      };
    }
    if (!NativeAudioContext) return;
    const TrackingAudioContext = new Proxy(NativeAudioContext, {
      construct(Target, args) {
        const audioContext = Reflect.construct(Target, args);
        window.__PHASE4_AUDIO_CONTEXTS__.push(audioContext);
        const nativeAddModule = audioContext.audioWorklet?.addModule?.bind(audioContext.audioWorklet);
        if (nativeAddModule) {
          audioContext.audioWorklet.addModule = async (url, options) => {
            const entry = { url: new URL(String(url), location.href).href, state: "pending" };
            window.__PHASE4_WORKLETS__.push(entry);
            try {
              await nativeAddModule(url, options);
              entry.state = "fulfilled";
            } catch (error) {
              entry.state = "rejected";
              entry.error = error instanceof Error ? error.message : String(error);
              throw error;
            }
          };
        }
        return audioContext;
      },
    });
    window.AudioContext = TrackingAudioContext;
    if (window.webkitAudioContext) window.webkitAudioContext = TrackingAudioContext;
  });
  const page = await context.newPage();
  page.on("console", message => {
    if (message.type() === "error") browserErrors.push(message.text());
  });
  page.on("pageerror", error => browserErrors.push(error.message));
  page.on("requestfailed", request => {
    requestFailures.push(`${request.method()} ${request.url()} ${request.failure()?.errorText ?? "failed"}`);
  });
  await page.goto(URL, { waitUntil: "domcontentloaded", timeout: 30_000 });
  await page.waitForFunction(
    () => document.querySelector("canvas.is-ready") && !document.getElementById("runtime-state"),
    undefined,
    { timeout: 120_000 }
  );
  await page.locator("canvas").click({ position: { x: 640, y: 360 } });
  await page.waitForFunction(
    () => window.__PROTO_SCROLLER_PHASE4_AUDIO__?.status === "PASS",
    undefined,
    { timeout: 120_000 }
  );
  const evidence = await page.evaluate(() => ({
    probe: window.__PROTO_SCROLLER_PHASE4_AUDIO__,
    audioContextStates: (window.__PHASE4_AUDIO_CONTEXTS__ ?? []).map(context => context.state),
    worklets: (window.__PHASE4_WORKLETS__ ?? []).map(entry => ({ ...entry })),
    bufferStarts: window.__PHASE4_BUFFER_STARTS__ ?? [],
  }));
  if (evidence.probe.stream_count !== 49 || evidence.probe.voice_count !== 12 || evidence.probe.sfx_count !== 37) {
    throw new Error(`stream census failed: ${JSON.stringify(evidence.probe)}`);
  }
  if (evidence.probe.errors.length > 0 || evidence.probe.results.some(item => !item.player_started || item.bus_muted || item.mix_rate_hz !== 24000)) {
    throw new Error(`Godot Web playback failed: ${JSON.stringify(evidence.probe)}`);
  }
  if (!evidence.audioContextStates.includes("running")) {
    throw new Error(`Web Audio context is not running: ${JSON.stringify(evidence.audioContextStates)}`);
  }
  const expectedWorklets = [
    `${BASE_URL}/game/game.audio.position.worklet.js`,
    `${BASE_URL}/game/game.audio.worklet.js`,
  ].sort();
  const fulfilled = evidence.worklets
    .filter(entry => entry.state === "fulfilled")
    .map(entry => entry.url)
    .sort();
  if (JSON.stringify(fulfilled) !== JSON.stringify(expectedWorklets)) {
    throw new Error(`worklet contract failed: ${JSON.stringify(evidence.worklets)}`);
  }
  const nonemptyStarts = evidence.bufferStarts.filter(entry => entry.hasBuffer && entry.length > 0);
  if (nonemptyStarts.length < 49) {
    throw new Error(`only ${nonemptyStarts.length} nonempty Web Audio buffers started for 49 streams`);
  }
  const materialErrors = browserErrors.filter(
    message => !message.includes("Failed to load resource: the server responded with a status of 404")
  );
  if (materialErrors.length > 0) throw new Error(`browser errors: ${materialErrors.join(" | ")}`);
  if (requestFailures.length > 0) throw new Error(`request failures: ${requestFailures.join(" | ")}`);
  Object.assign(report, {
    status: "PASS",
    ...evidence,
    nonemptyBufferStartCount: nonemptyStarts.length,
    materialBrowserErrors: materialErrors,
  });
} catch (error) {
  report.error = error instanceof Error ? error.stack ?? error.message : String(error);
  throw error;
} finally {
  await writeFile(REPORT_PATH, `${JSON.stringify(report, null, 2)}\n`);
  if (browser) await browser.close();
  if (server?.pid) {
    try {
      process.kill(-server.pid, "SIGTERM");
    } catch {}
  }
  await rm(ENGINE_DIR, { recursive: true, force: true });
}

console.log(
  `[PHASE4-BROWSER-AUDIO-PASS] streams=${report.probe.stream_count} buffers=${report.nonemptyBufferStartCount} report=${REPORT_PATH}`
);

async function waitForHttp(url, timeoutMs) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    try {
      const response = await fetch(url);
      if (response.ok) return;
    } catch {}
    await new Promise(resolve => setTimeout(resolve, 150));
  }
  throw new Error(`HTTP server did not become ready: ${url}`);
}
