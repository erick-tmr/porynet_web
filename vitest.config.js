import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    environment: "jsdom",
    include: ["test/javascript/**/*.test.js"],
    setupFiles: ["test/javascript/setup.js"],
    coverage: {
      provider: "v8",
      reporter: ["text", "json-summary", "html"],
      reportsDirectory: "tmp/js-coverage",
      // Gate: the Stimulus controllers must stay fully covered. Boilerplate that
      // only boots Stimulus via the importmap (application.js, controllers/index.js,
      // controllers/application.js) is excluded — it can't run under Node.
      include: ["app/javascript/controllers/*_controller.js"],
      thresholds: { lines: 100, functions: 100, branches: 100, statements: 100 },
    },
  },
});
