import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// Mini App dev server. At integration, World App loads this over HTTPS via the
// Developer Portal; for local dev a tunnel (e.g. ngrok) into World App's webview is
// the usual path. Keep the prover-key assets (the ProveKit `prepare` output) under
// /public/keys so fetchProverKey() can cache them.
export default defineConfig({
  plugins: [react()],
  server: { port: 5173, host: true },
});
