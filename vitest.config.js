import { fileURLToPath } from "node:url";
import { defineConfig } from "vitest/config";

export default defineConfig({
  // Controllers import shared modules the way the importmap pins them ("lib/progress_store").
  // Vite has no importmap, so teach it the same prefix.
  resolve: {
    alias: [
      { find: /^lib\//, replacement: fileURLToPath(new URL("./app/javascript/lib/", import.meta.url)) },
    ],
  },
  test: {
    environment: "jsdom",
    include: ["test/javascript/**/*.test.js"],
    setupFiles: ["test/javascript/setup.js"],
    coverage: {
      provider: "v8",
      reporter: ["text", "json-summary", "html"],
      reportsDirectory: "tmp/js-coverage",
      // Gate: the Stimulus controllers and the plain modules they build on must stay fully
      // covered. Boilerplate that only boots Stimulus via the importmap (application.js,
      // controllers/index.js, controllers/application.js) is excluded — it can't run under Node.
      include: ["app/javascript/controllers/*_controller.js", "app/javascript/lib/*.js"],
      thresholds: { lines: 100, functions: 100, branches: 100, statements: 100 },
    },
  },
});
