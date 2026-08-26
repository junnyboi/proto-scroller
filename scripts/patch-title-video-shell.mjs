import { readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import process from "node:process";

const targetPath = path.resolve(
  process.cwd(),
  process.argv[2] ?? "client/public/game/game.html"
);
let source = await readFile(targetPath, "utf8");

function replaceOnce(label, needle, replacement) {
  const first = source.indexOf(needle);
  if (first < 0) throw new Error(`[TITLE-VIDEO-PATCH-MISSING] ${label}`);
  if (source.indexOf(needle, first + needle.length) >= 0) {
    throw new Error(`[TITLE-VIDEO-PATCH-AMBIGUOUS] ${label}`);
  }
  source = source.replace(needle, replacement);
}

if (source.includes('id="title-video-backdrop"')) {
  throw new Error("[TITLE-VIDEO-PATCH-ALREADY-APPLIED]");
}

replaceOnce(
  "fullscreen canvas resize policy",
  '"canvasResizePolicy":0',
  '"canvasResizePolicy":2'
);

replaceOnce(
  "title backdrop styles",
  "body {\n\tcolor: white;",
  `body {\n\tcolor: white;\n}\n\n#title-poster-backdrop, #title-video-backdrop {\n\tposition: fixed;\n\tinset: 0;\n\twidth: 100%;\n\theight: 100%;\n\tborder: 0;\n\tobject-fit: cover;\n\topacity: 0;\n\tpointer-events: none;\n\ttransition: opacity 180ms ease-out;\n}\n\n#title-poster-backdrop {\n\tz-index: 0;\n}\n\n#title-poster-backdrop img {\n\tdisplay: block;\n\twidth: 100%;\n\theight: 100%;\n\tobject-fit: cover;\n}\n\n#title-video-backdrop {\n\tz-index: 1;\n}\n\nbody.title-backdrop-active #title-poster-backdrop,\nbody.title-backdrop-active #title-video-backdrop.is-ready {\n\topacity: 1;\n}\n\n#canvas {\n\tposition: relative;\n\tz-index: 2;\n}\n\n#status {\n\tz-index: 3;\n}\n\nbody {\n\tcolor: white;`
);

replaceOnce(
  "title backdrop markup",
  '\t<body>\n\t\t<canvas id="canvas">',
  `\t<body>\n\t\t<picture id="title-poster-backdrop" aria-hidden="true">\n\t\t\t<source media="(orientation: portrait)" srcset="/title-video/title-poster-portrait.jpg">\n\t\t\t<img src="/title-video/title-poster-landscape.jpg" alt="">\n\t\t</picture>\n\t\t<video id="title-video-backdrop" muted loop autoplay playsinline preload="auto" aria-hidden="true">\n\t\t\t<source media="(orientation: portrait)" src="/title-video/title-loop-portrait.mp4" type="video/mp4">\n\t\t\t<source src="/title-video/title-loop-landscape.mp4" type="video/mp4">\n\t\t</video>\n\t\t<canvas id="canvas">`
);

replaceOnce(
  "title backdrop bridge",
  "const GODOT_CONFIG = ",
  `const titleVideoBackdrop = document.getElementById('title-video-backdrop');
		const TITLE_SOURCES = { landscape: '/title-video/title-loop-landscape.mp4', portrait: '/title-video/title-loop-portrait.mp4' };
		const TITLE_IMPACTS = { landscape: 88 / 24, portrait: 66 / 24 };
		const TITLE_AUDIO_SCHEDULE_AHEAD_SECONDS = 1.0;
		const TITLE_SOURCE_CAPTURE_TIMEOUT_MS = 1500;
		const forceTitleVideoReject = new URLSearchParams(location.search).get('forceTitleVideoReject') === '1';
	const titleAudioContexts = new Set();
let titleSourceLocked = false, titleLockedOrientation = null, titleGeneration = 0, titleFrame = 0, titleTimer = 0, titleTargetOutputPerformanceTime = 0, titleCapture = null;
const titleOrientation = () => titleSourceLocked && titleLockedOrientation ? titleLockedOrientation : matchMedia('(orientation: portrait)').matches ? 'portrait' : 'landscape';
function selectTitleSource(force = false) {
	if (!titleVideoBackdrop || (titleSourceLocked && !force)) return;
	const source = TITLE_SOURCES[titleOrientation()];
	if (new URL(titleVideoBackdrop.currentSrc || titleVideoBackdrop.src || source, location.href).pathname === source && !force) return;
	const play = !titleVideoBackdrop.paused || document.body.classList.contains('title-backdrop-active');
	titleVideoBackdrop.src = source; titleVideoBackdrop.load();
	if (play) titleVideoBackdrop.play().catch(() => {});
}
const boundedOutputLatency = context => Math.min(Math.max(context.outputLatency || context.baseLatency || 0, 0), 0.2);
function outputPerformanceTime(context, when) {
	const stamp = context.getOutputTimestamp?.();
	return stamp && Number.isFinite(stamp.contextTime) ? stamp.performanceTime + (when - stamp.contextTime) * 1000 : performance.now() + Math.max(0, when - context.currentTime + boundedOutputLatency(context)) * 1000;
}
function nonSilent(buffer) {
	if (!buffer || !buffer.length) return false;
	for (let c = 0; c < buffer.numberOfChannels; c += 1) { const samples = buffer.getChannelData(c), stride = Math.max(1, Math.floor(samples.length / 4096)); for (let s = 0; s < samples.length; s += stride) if (Math.abs(samples[s]) > 0.000001) return true; }
	return false;
}
(function installTitleAudioProbe() {
	const NativeAudioContext = window.AudioContext || window.webkitAudioContext;
	if (NativeAudioContext && !NativeAudioContext.__protoScrollerWrapped) {
		class WrappedAudioContext extends NativeAudioContext { constructor(options) { super(options); titleAudioContexts.add(this); } }
		WrappedAudioContext.__protoScrollerWrapped = true; window.AudioContext = WrappedAudioContext; if (window.webkitAudioContext) window.webkitAudioContext = WrappedAudioContext;
	}
	const prototype = window.AudioBufferSourceNode?.prototype;
	if (!prototype || prototype.__protoScrollerStartWrapped) return;
		const nativeStart = prototype.start;
		prototype.start = function (when = 0, offset = 0, duration) {
			let effectiveWhen = when;
			const telemetry = window.__PROTO_SCROLLER_TITLE_MUSIC_SYNC__;
			if (titleCapture && telemetry?.commitStatus === 'callback-invoked' && nonSilent(this.buffer)) {
				const immediateSchedule = when > 0 ? when : this.context.currentTime;
					const immediateOutputPerformanceTime = outputPerformanceTime(this.context, immediateSchedule);
					const schedule = titleCapture.scheduleToImpact ? this.context.currentTime + Math.max(0, (titleCapture.targetOutputPerformanceTime - immediateOutputPerformanceTime) / 1000) : immediateSchedule;
				effectiveWhen = schedule;
				const secondsUntilRendered = Math.max(0, (outputPerformanceTime(this.context, schedule) - performance.now()) / 1000);
				const renderedVideoTime = (titleVideoBackdrop.currentTime + secondsUntilRendered) % 8;
				Object.assign(telemetry, { sourceKind: 'AudioBufferSourceNode/non-silent', actualOutputSchedule: schedule, renderedVideoTime, renderedSyncError: renderedVideoTime - telemetry.impactSeconds, videoTime: titleVideoBackdrop.currentTime, committed: true, commitStatus: 'captured' });
				const scheduled = titleCapture.scheduled, done = titleCapture.done; titleCapture = null; scheduled(secondsUntilRendered); done();
		}
			if (duration === undefined) nativeStart.call(this, effectiveWhen, offset); else nativeStart.call(this, effectiveWhen, offset, duration);
	};
	prototype.__protoScrollerStartWrapped = true;
})();
window.protoScrollerResumeTitleAudio = function () {
	const contexts = [...titleAudioContexts];
	const telemetry = window.__PROTO_SCROLLER_TITLE_MUSIC_SYNC__ = window.__PROTO_SCROLLER_TITLE_MUSIC_SYNC__ || { sourceKind: 'title-lifecycle-queued', committed: false, commitStatus: 'queued-at-title' };
	Promise.all(contexts.map(context => context.resume())).then(() => {
		Object.assign(telemetry, { audioContextState: contexts.find(context => context.state === 'running')?.state || 'unavailable', committed: true, commitStatus: 'title-interaction-resumed' });
	}).catch(() => Object.assign(telemetry, { fallback: true, fallbackReason: 'title-interaction-resume-rejected', commitStatus: 'resume-rejected' }));
	return contexts.length > 0;
};
function commitTitleBeat(generation, commitCallback, calibrationCallback, fallbackReason) {
	if (generation !== titleGeneration) return;
	if (titleFrame) cancelAnimationFrame(titleFrame); if (titleTimer) clearTimeout(titleTimer); titleFrame = 0; titleTimer = 0;
	const telemetry = window.__PROTO_SCROLLER_TITLE_MUSIC_SYNC__;
	if (!telemetry || telemetry.committed || telemetry.commitStatus === 'callback-invoked') return;
	if (fallbackReason) Object.assign(telemetry, { fallback: true, fallbackReason });
	Object.assign(telemetry, { videoTime: titleVideoBackdrop.currentTime, commitStatus: 'callback-invoked' });
	titleCapture = { impactSeconds: telemetry.impactSeconds, scheduleToImpact: !fallbackReason, targetOutputPerformanceTime: titleTargetOutputPerformanceTime, scheduled: delay => calibrationCallback?.('scheduled', delay), done: () => calibrationCallback?.('complete') }; commitCallback();
	setTimeout(() => { if (generation !== titleGeneration || telemetry.committed) return; Object.assign(telemetry, { fallback: true, fallbackReason: telemetry.fallbackReason || 'non-silent-source-capture-timeout', sourceKind: 'commit-callback-fallback', committed: true, commitStatus: 'fallback-complete' }); titleCapture = null; calibrationCallback?.('complete'); }, TITLE_SOURCE_CAPTURE_TIMEOUT_MS);
}
window.protoScrollerMarkTitleMusicPrewarm = status => { if (window.__PROTO_SCROLLER_TITLE_MUSIC_SYNC__) window.__PROTO_SCROLLER_TITLE_MUSIC_SYNC__.prewarmStatus = status; };
window.protoScrollerCancelTitleBeatCommit = function (reason = 'host-cancelled') {
	titleGeneration += 1; if (titleFrame) cancelAnimationFrame(titleFrame); if (titleTimer) clearTimeout(titleTimer); titleFrame = 0; titleTimer = 0; titleTargetOutputPerformanceTime = 0; titleCapture = null;
	const telemetry = window.__PROTO_SCROLLER_TITLE_MUSIC_SYNC__; if (telemetry && !telemetry.committed) Object.assign(telemetry, { cancelled: true, cancelReason: reason, commitStatus: 'cancelled' });
	titleSourceLocked = false; titleLockedOrientation = null;
};
window.protoScrollerScheduleTitleBeatCommit = function (commitCallback, calibrationCallback) {
	window.protoScrollerCancelTitleBeatCommit('rescheduled'); const generation = titleGeneration;
	titleLockedOrientation = titleOrientation(); titleSourceLocked = true; selectTitleSource(true);
	const impactSeconds = TITLE_IMPACTS[titleLockedOrientation], trusted = navigator.userActivation?.isActive === true;
	const telemetry = window.__PROTO_SCROLLER_TITLE_MUSIC_SYNC__ = { orientation: titleLockedOrientation, source: TITLE_SOURCES[titleLockedOrientation], sourceKind: 'pending', impactSeconds, videoTime: null, outputLatency: 0, actualOutputSchedule: null, renderedVideoTime: null, renderedSyncError: null, trusted, audioContextState: 'unavailable', fallback: false, fallbackReason: null, cancelled: false, cancelReason: null, committed: false, commitStatus: 'scheduled', prewarmStatus: 'waiting' };
	(async () => {
		const contexts = [...titleAudioContexts]; try { await Promise.all(contexts.map(context => context.resume())); } catch { commitTitleBeat(generation, commitCallback, calibrationCallback, 'audio-context-resume-rejected'); return; }
		if (generation !== titleGeneration) return; const context = contexts.find(candidate => candidate.state === 'running'); telemetry.audioContextState = context?.state || 'unavailable'; telemetry.outputLatency = context ? boundedOutputLatency(context) : 0;
		if (!context || !trusted) { commitTitleBeat(generation, commitCallback, calibrationCallback, 'trusted-running-audio-context-unavailable'); return; }
		calibrationCallback?.('prewarm'); const prewarmDeadline = performance.now() + 1250; while (telemetry.prewarmStatus !== 'restored' && performance.now() < prewarmDeadline) await new Promise(resolve => requestAnimationFrame(resolve)); if (telemetry.prewarmStatus !== 'restored') telemetry.prewarmStatus = 'timed-out';
		try { if (forceTitleVideoReject) throw new Error('forced title video rejection'); await titleVideoBackdrop.play(); } catch { commitTitleBeat(generation, commitCallback, calibrationCallback, 'video-playback-rejected'); return; }
			const currentVideoTime = ((titleVideoBackdrop.currentTime % 8) + 8) % 8; let secondsUntilImpact = impactSeconds - currentVideoTime; if (secondsUntilImpact <= TITLE_AUDIO_SCHEDULE_AHEAD_SECONDS) secondsUntilImpact += 8; titleTargetOutputPerformanceTime = performance.now() + secondsUntilImpact * 1000; const secondsUntilCommit = secondsUntilImpact - TITLE_AUDIO_SCHEDULE_AHEAD_SECONDS, targetPerformanceTime = titleTargetOutputPerformanceTime - TITLE_AUDIO_SCHEDULE_AHEAD_SECONDS * 1000;
			titleTimer = setTimeout(() => commitTitleBeat(generation, commitCallback, calibrationCallback), secondsUntilCommit * 1000);
			const deadline = performance.now() + 9500; const sample = () => { if (generation !== titleGeneration) return; telemetry.videoTime = titleVideoBackdrop.currentTime; if (performance.now() >= targetPerformanceTime) { commitTitleBeat(generation, commitCallback, calibrationCallback); return; } if (performance.now() >= deadline || titleVideoBackdrop.error) { commitTitleBeat(generation, commitCallback, calibrationCallback, 'video-scheduler-timeout'); return; } titleFrame = requestAnimationFrame(sample); }; titleFrame = requestAnimationFrame(sample);
	})(); return true;
};
window.addEventListener('resize', () => selectTitleSource(), { passive: true }); selectTitleSource();
window.protoScrollerSetTitleBackdropActive = function (active) { document.body.classList.toggle('title-backdrop-active', Boolean(active)); if (!titleVideoBackdrop) return; if (active) titleVideoBackdrop.play().catch(() => {}); else titleVideoBackdrop.pause(); };
if (titleVideoBackdrop) { titleVideoBackdrop.addEventListener('playing', () => titleVideoBackdrop.classList.add('is-ready'), { once: true }); titleVideoBackdrop.requestVideoFrameCallback?.(() => {}); }
window.protoScrollerSetTitleBackdropActive(true);

const GODOT_CONFIG =
`
);

await writeFile(targetPath, source, "utf8");
console.log(`[TITLE-VIDEO-SHELL-PATCHED] ${targetPath}`);
