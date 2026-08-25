import { spawn } from "node:child_process";
import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright-core";

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(SCRIPT_DIR, "..");
const ARTIFACT_DIR = path.join(ROOT, "game", "artifacts", "browser");
const REPORT_PATH = path.join(ARTIFACT_DIR, "upgrade-transition.json");
const SCREENSHOT_PATH = path.join(ARTIFACT_DIR, "upgrade-transition.png");
const FAILURE_SCREENSHOT_PATH = path.join(
  ARTIFACT_DIR,
  "upgrade-transition-failure.png"
);
const PORT = Number(process.env.PROTO_SCROLLER_SMOKE_PORT ?? 4173);
const BASE_URL = `http://127.0.0.1:${PORT}`;
const CHROMIUM_PATH = process.env.CHROMIUM_PATH ?? "/usr/bin/chromium";
const EXPECTED_PHASES = [
  "ready",
  "charge_started",
  "charge_progress",
  "charge_released",
  "attack_started",
  "upgrade_visible",
  "upgrade_resolved",
  "east_walk_ok",
  "pass",
];

await mkdir(ARTIFACT_DIR, { recursive: true });

const serverOutput = [];
const browserErrors = [];
const requestFailures = [];
const httpErrors = [];
let server;
let browser;
let page;
let report = {
  status: "FAIL",
  url: `${BASE_URL}/?localGame=1&webSmoke=upgrade`,
  phases: [],
  browserErrors,
  requestFailures,
  httpErrors,
};

try {
  server = spawn(
    "pnpm",
    [
      "exec",
      "vite",
      "--host",
      "127.0.0.1",
      "--port",
      String(PORT),
      "--strictPort",
    ],
    {
      cwd: ROOT,
      env: { ...process.env, BROWSER: "none" },
      detached: true,
      stdio: ["ignore", "pipe", "pipe"],
    }
  );
  server.stdout.on("data", chunk => serverOutput.push(chunk.toString()));
  server.stderr.on("data", chunk => serverOutput.push(chunk.toString()));
  await waitForHttp(`${BASE_URL}/`, 30_000, server);

  browser = await chromium.launch({
    executablePath: CHROMIUM_PATH,
    headless: true,
    args: [
      "--no-sandbox",
      "--disable-dev-shm-usage",
      "--use-angle=swiftshader",
    ],
  });
  const context = await browser.newContext({
    viewport: { width: 1280, height: 720 },
  });
  page = await context.newPage();
  page.on("pageerror", error =>
    browserErrors.push(`pageerror: ${error.message}`)
  );
  page.on("console", message => {
    if (
      message.type() === "error" &&
      !message.text().startsWith("Failed to load resource:")
    ) {
      browserErrors.push(`console: ${message.text()}`);
    }
  });
  page.on("response", response => {
    if (response.status() >= 400) {
      httpErrors.push(`${response.status()} ${response.url()}`);
    }
  });
  page.on("requestfailed", request => {
    const url = request.url();
    if (url.includes("/game/") || url.includes("/manus-storage/")) {
      requestFailures.push(
        `${url}: ${request.failure()?.errorText ?? "unknown failure"}`
      );
    }
  });

  await page.goto(report.url, {
    waitUntil: "domcontentloaded",
    timeout: 30_000,
  });
  await page.waitForFunction(
    () =>
      document.querySelector("canvas.is-ready") &&
      !document.getElementById("runtime-state"),
    undefined,
    { timeout: 120_000 }
  );
  await page.keyboard.press("Enter");
  await waitForPhase(page, "ready", 30_000);
  await page.keyboard.down("Space");
  try {
    await waitForPhase(page, "charge_started", 30_000);
    await waitForPhase(page, "charge_progress", 30_000);
    await new Promise(resolve => setTimeout(resolve, 250));
  } finally {
    await page.keyboard.up("Space");
  }
  await waitForPhase(page, "charge_released", 30_000);
  await waitForPhase(page, "upgrade_visible", 30_000);
  await page.screenshot({ path: SCREENSHOT_PATH });
  await page.keyboard.press("Enter");
  await waitForPhase(page, "upgrade_resolved", 30_000);

  await page.keyboard.down("d");
  try {
    await waitForPhase(page, "east_walk_ok", 30_000);
  } finally {
    await page.keyboard.up("d");
  }
  await page.keyboard.down("a");
  try {
    await waitForPhase(page, "pass", 30_000);
  } finally {
    await page.keyboard.up("a");
  }

  const phases = await smokeHistory(page);
  assertPhaseContract(phases);
  if (browserErrors.length > 0) {
    throw new Error(`browser console errors: ${browserErrors.join(" | ")}`);
  }
  if (requestFailures.length > 0) {
    throw new Error(`runtime request failures: ${requestFailures.join(" | ")}`);
  }
  report = {
    ...report,
    status: "PASS",
    phases,
    screenshot: path.relative(ROOT, SCREENSHOT_PATH),
  };
  console.log(`[WEB-GAMEPLAY-SMOKE-PASS] phases=${EXPECTED_PHASES.join(",")}`);
} catch (error) {
  if (page) {
    await page.screenshot({ path: FAILURE_SCREENSHOT_PATH }).catch(() => {});
    report.failureScreenshot = path.relative(ROOT, FAILURE_SCREENSHOT_PATH);
    report.phases = await smokeHistory(page).catch(() => []);
  }
  report.error =
    error instanceof Error ? (error.stack ?? error.message) : String(error);
  report.serverOutput = serverOutput.slice(-60);
  console.error(`[WEB-GAMEPLAY-SMOKE-FAIL] ${report.error}`);
  process.exitCode = 1;
} finally {
  await writeFile(REPORT_PATH, `${JSON.stringify(report, null, 2)}\n`, "utf8");
  if (browser) await browser.close();
  if (server?.pid && server.exitCode === null) {
    try {
      process.kill(-server.pid, "SIGTERM");
    } catch {}
    await Promise.race([
      new Promise(resolve => server.once("exit", resolve)),
      new Promise(resolve => setTimeout(resolve, 2_000)),
    ]);
    if (server.exitCode === null) {
      try {
        process.kill(-server.pid, "SIGKILL");
      } catch {}
    }
  }
}

async function waitForHttp(url, timeoutMs, child) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    if (child.exitCode !== null) {
      throw new Error(
        `Vite exited before readiness with code ${child.exitCode}`
      );
    }
    try {
      const response = await fetch(url);
      if (response.ok) return;
    } catch {}
    await new Promise(resolve => setTimeout(resolve, 150));
  }
  throw new Error(`Timed out waiting for ${url}`);
}

async function smokeHistory(activePage) {
  return activePage.evaluate(
    () => window.__PROTO_SCROLLER_SMOKE_HISTORY__ ?? []
  );
}

async function waitForPhase(activePage, phase, timeoutMs) {
  await activePage.waitForFunction(
    expected => {
      const history = window.__PROTO_SCROLLER_SMOKE_HISTORY__ ?? [];
      const failure = history.find(entry => entry.status === "fail");
      if (failure)
        throw new Error(failure.details?.message ?? "Godot smoke probe failed");
      return history.some(entry => entry.status === expected);
    },
    phase,
    { timeout: timeoutMs }
  );
}

function assertPhaseContract(phases) {
  const statuses = phases.map(entry => entry.status);
  if (JSON.stringify(statuses) !== JSON.stringify(EXPECTED_PHASES)) {
    throw new Error(`unexpected smoke phases: ${JSON.stringify(statuses)}`);
  }
  phases.forEach((entry, index) => {
    if (entry.phase_index !== index + 1) {
      throw new Error(
        `non-monotonic phase index at ${entry.status}: ${entry.phase_index}`
      );
    }
  });
  const chargeStarted = phases[1];
  const chargeProgress = phases[2];
  const chargeReleased = phases[3];
  const attack = phases[4];
  const visible = phases[5];
  const resolved = phases[6];
  const east = phases[7];
  const west = phases[8];
  if (
    chargeStarted.details.frame !== 0 ||
    chargeStarted.details.particles !== true ||
    !String(chargeStarted.details.animation).startsWith("attack_")
  ) {
    throw new Error(
      `charge did not freeze first frame with particles: ${JSON.stringify(chargeStarted.details)}`
    );
  }
  if (
    chargeProgress.details.progress < 0.35 ||
    chargeProgress.details.multiplier <= 1.0 ||
    chargeProgress.details.multiplier > 2.0 ||
    chargeProgress.details.frame !== 0
  ) {
    throw new Error(
      `charge progress contract failed: ${JSON.stringify(chargeProgress.details)}`
    );
  }
  if (
    chargeReleased.details.damage <= 180 ||
    chargeReleased.details.damage > 360 ||
    chargeReleased.details.playing !== true
  ) {
    throw new Error(
      `charge release contract failed: ${JSON.stringify(chargeReleased.details)}`
    );
  }
  if (!String(attack.details.animation).startsWith("attack_")) {
    throw new Error(`melee animation missing: ${attack.details.animation}`);
  }
  if (visible.details.animation !== "idle_s") {
    throw new Error(
      `cancelled melee did not settle to idle: ${visible.details.animation}`
    );
  }
  if (resolved.details.rank_total < 1) {
    throw new Error(
      `upgrade did not apply: rank_total=${resolved.details.rank_total}`
    );
  }
  if (
    east.details.animation !== "walk_e" ||
    east.details.frame_before === east.details.frame_after
  ) {
    throw new Error(
      `east animation continuity failed: ${JSON.stringify(east.details)}`
    );
  }
  if (
    west.details.animation !== "walk_w" ||
    west.details.frame_before === west.details.frame_after ||
    west.details.rank_total < 1
  ) {
    throw new Error(
      `west animation continuity failed: ${JSON.stringify(west.details)}`
    );
  }
}
