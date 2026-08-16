import fs from "node:fs";
import path from "node:path";
import { defineConfig, type Plugin, type ViteDevServer } from "vite";

const PROJECT_ROOT = import.meta.dirname;

function vitePluginGodotStatic(): Plugin {
  const gameRoot = path.resolve(PROJECT_ROOT, "client", "public", "game");
  const contentTypes: Record<string, string> = {
    ".js": "text/javascript; charset=utf-8",
    ".pck": "application/octet-stream",
    ".png": "image/png",
    ".wasm": "application/wasm",
  };

  return {
    name: "proto-scroller-godot-static",
    configureServer(server: ViteDevServer) {
      server.middlewares.use("/game", (req, res, next) => {
        const requestPath = decodeURIComponent(req.url?.split("?")[0] ?? "")
          .replace(/^\/+/, "");
        const filePath = path.resolve(gameRoot, requestPath);
        if (
          !requestPath ||
          !filePath.startsWith(`${gameRoot}${path.sep}`) ||
          !fs.existsSync(filePath) ||
          !fs.statSync(filePath).isFile()
        ) {
          next();
          return;
        }

        res.setHeader(
          "Content-Type",
          contentTypes[path.extname(filePath)] ?? "application/octet-stream",
        );
        res.setHeader("Cache-Control", "no-cache");
        fs.createReadStream(filePath).pipe(res);
      });
    },
  };
}

export default defineConfig({
  plugins: [vitePluginGodotStatic()],
  root: path.resolve(PROJECT_ROOT, "client"),
  build: {
    outDir: path.resolve(PROJECT_ROOT, "dist/public"),
    emptyOutDir: true,
  },
  server: {
    port: 3000,
    strictPort: false,
    host: true,
    allowedHosts: [
      ".manuspre.computer",
      ".manus.computer",
      ".manus-asia.computer",
      ".manuscomputer.ai",
      ".manusvm.computer",
      "localhost",
      "127.0.0.1",
    ],
    fs: {
      strict: true,
      deny: ["**/.*"],
    },
  },
});
