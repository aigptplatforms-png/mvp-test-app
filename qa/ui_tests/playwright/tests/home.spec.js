const { test, expect } = require('@playwright/test');

test('homepage shows message', async ({ page }) => {
  const base = process.env.BASE_URL || 'http://localhost:8080';
  await page.goto(base);
  await expect(page.locator('h1')).toHaveText(/Hello from MVP Test App/);
});
