import { readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import process from "node:process";

const targetPath = path.resolve(
  process.cwd(),
  process.argv[2] ?? "client/public/game/game.js"
);
let source = await readFile(targetPath, "utf8");

function replaceOnce(label, before, after) {
  if (source.includes(after)) return;
  const occurrences = source.split(before).length - 1;
  if (occurrences !== 1) {
    throw new Error(
      `${label}: expected one patch target in ${targetPath}, found ${occurrences}`
    );
  }
  source = source.replace(before, after);
}

replaceOnce(
  "config default",
  "\t\texecutable: '',\n",
  "\t\texecutable: '',\n\t\taudioWorkletBase: null,\n"
);
replaceOnce(
  "config parser",
  "\t\tthis.executable = parse('executable', this.executable);\n",
  "\t\tthis.executable = parse('executable', this.executable);\n\t\tthis.audioWorkletBase = parse('audioWorkletBase', this.audioWorkletBase);\n"
);
replaceOnce(
  "module worklet base",
  "\t\tconst gdext = this.gdextensionLibs;\n",
  "\t\tconst gdext = this.gdextensionLibs;\n\t\tconst audioWorkletBase = this.audioWorkletBase || loadPath;\n"
);
replaceOnce(
  "audio worklet path",
  "\t\t\t\t\treturn `${loadPath}.audio.worklet.js`;\n",
  "\t\t\t\t\treturn `${audioWorkletBase}.audio.worklet.js`;\n"
);
replaceOnce(
  "position worklet path",
  "\t\t\t\t\treturn `${loadPath}.audio.position.worklet.js`;\n",
  "\t\t\t\t\treturn `${audioWorkletBase}.audio.position.worklet.js`;\n"
);

await writeFile(targetPath, source, "utf8");
console.log(`[WORKLET-BASE-PATCHED] ${targetPath}`);
