import { defineConfig } from '@playwright/test';

export default defineConfig({
  reporter: [
    ['dot'],
    ['junit', { outputFile: 'playwright-report.xml' }]
  ],
  outputDir: 'test-results'
});
