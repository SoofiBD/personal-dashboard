import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// Single IIFE bundle consumed by the Rails asset pipeline (Sprockets).
// Exposes window.MdEditor. React is bundled inline to avoid version clashes.
export default defineConfig({
  plugins: [react()],
  define: {
    "process.env.NODE_ENV": JSON.stringify("production"),
  },
  build: {
    lib: {
      entry: "src/mount.tsx",
      name: "MdEditor",
      formats: ["iife"],
      fileName: () => "md-editor.bundle.js",
    },
    outDir: "../../vendor/assets/javascripts/md-editor",
    emptyOutDir: true,
    minify: "esbuild",
    sourcemap: false,
    cssCodeSplit: false,
  },
});
