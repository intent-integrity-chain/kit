const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  testDir: './visual',
  outputDir: './visual/test-results',
  snapshotDir: './visual/snapshots',
  snapshotPathTemplate: '{snapshotDir}/{testFilePath}/{platform}/{arg}{ext}',
  timeout: 30000,
  expect: {
    toHaveScreenshot: {
      maxDiffPixelRatio: 0.01,
    },
  },
  use: {
    viewport: { width: 1440, height: 900 },
    colorScheme: 'dark',
  },
  projects: [
    {
      name: 'chromium',
      use: { browserName: 'chromium' },
    },
  ],
});
