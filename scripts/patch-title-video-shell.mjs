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
  `const titleVideoBackdrop = document.getElementById('title-video-backdrop');\nwindow.protoScrollerSetTitleBackdropActive = function (active) {\n\tdocument.body.classList.toggle('title-backdrop-active', Boolean(active));\n\tif (!titleVideoBackdrop) return;\n\tif (active) {\n\t\tconst playPromise = titleVideoBackdrop.play();\n\t\tif (playPromise) playPromise.catch(() => {});\n\t} else {\n\t\ttitleVideoBackdrop.pause();\n\t}\n};\nif (titleVideoBackdrop) {\n\ttitleVideoBackdrop.addEventListener('playing', () => {\n\t\ttitleVideoBackdrop.classList.add('is-ready');\n\t}, { once: true });\n}\nwindow.protoScrollerSetTitleBackdropActive(true);\n\nconst GODOT_CONFIG = `
);

await writeFile(targetPath, source, "utf8");
console.log(`[TITLE-VIDEO-SHELL-PATCHED] ${targetPath}`);
