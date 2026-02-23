// @ts-check
const { test, expect } = require('@playwright/test');
const path = require('path');
const fs = require('fs');
const { createFixtureProject, startServer } = require('./helpers');

let port;
let cleanup;
let projectPath;

test.beforeAll(async () => {
  projectPath = createFixtureProject();
  const result = await startServer(projectPath);
  port = result.port;
  cleanup = result.cleanup;
});

test.afterAll(async () => {
  if (cleanup) await cleanup();
});

function url() {
  return `http://localhost:${port}`;
}

/**
 * Attach error monitors to the page. Returns an object tracking console.error
 * messages and uncaught page errors.
 */
function attachErrorMonitor(page) {
  const errors = [];
  const pageErrors = [];

  page.on('console', (msg) => {
    if (msg.type() === 'error') {
      errors.push({
        text: msg.text(),
        location: msg.location()
      });
    }
  });

  page.on('pageerror', (err) => {
    pageErrors.push({
      message: err.message,
      stack: err.stack
    });
  });

  return {
    /** Console.error entries */
    consoleErrors() { return [...errors]; },
    /** Uncaught exceptions */
    uncaughtErrors() { return [...pageErrors]; },
    /** All errors combined */
    allErrors() {
      return [
        ...errors.map(e => `console.error: ${e.text}`),
        ...pageErrors.map(e => `pageerror: ${e.message}`)
      ];
    },
    /** Assert no errors occurred */
    assertClean(context) {
      const all = this.allErrors();
      if (all.length > 0) {
        throw new Error(
          `Unexpected errors during "${context}":\n${all.join('\n')}`
        );
      }
    }
  };
}

async function waitForDashboard(page) {
  await page.goto(url());
  await page.waitForSelector('.pipeline-node', { timeout: 10000 });
  await page.waitForSelector('#contentArea:not(:empty)', { timeout: 10000 });
  await page.waitForTimeout(500);
}

async function switchToTab(page, phaseName) {
  const node = page.locator('.pipeline-node', { hasText: phaseName });
  await node.click();
  await page.waitForTimeout(800);
}

test.describe('Console Error Monitoring', () => {

  test('no errors during initial page load', async ({ page }) => {
    const monitor = attachErrorMonitor(page);

    await waitForDashboard(page);

    monitor.assertClean('initial page load');
  });

  test('no errors when navigating through all tabs', async ({ page }) => {
    const monitor = attachErrorMonitor(page);

    await waitForDashboard(page);
    // Select 001-auth which has data for all views
    await page.selectOption('#featureSelect', { index: 1 });
    await page.waitForTimeout(500);

    const tabs = [
      'Constitution', 'Spec', 'Clarify', 'Plan',
      'Checklist', 'Testify', 'Tasks', 'Analyze', 'Implement'
    ];

    for (const tab of tabs) {
      await switchToTab(page, tab);
      await page.waitForTimeout(500);
    }

    monitor.assertClean('navigating through all tabs');
  });

  test('no errors when switching features', async ({ page }) => {
    const monitor = attachErrorMonitor(page);

    await waitForDashboard(page);

    // Switch to 001-auth
    await page.selectOption('#featureSelect', { index: 1 });
    await page.waitForTimeout(1000);

    // Switch back to 002-payments
    await page.selectOption('#featureSelect', { index: 0 });
    await page.waitForTimeout(1000);

    // Switch to 001-auth again
    await page.selectOption('#featureSelect', { index: 1 });
    await page.waitForTimeout(1000);

    monitor.assertClean('switching features');
  });

  test('no errors on WebSocket file change update', async ({ page }) => {
    const monitor = attachErrorMonitor(page);

    await waitForDashboard(page);
    await page.selectOption('#featureSelect', { index: 1 });
    await page.waitForTimeout(500);

    // Modify a file to trigger chokidar -> WebSocket push
    const tasksPath = path.join(projectPath, 'specs', '001-auth', 'tasks.md');
    const content = fs.readFileSync(tasksPath, 'utf-8');
    fs.writeFileSync(tasksPath, content + '\n- [ ] T099 [US1] Console error test task\n');

    // Wait for debounce (300ms) + processing + WebSocket push
    await page.waitForTimeout(2000);

    monitor.assertClean('WebSocket file change update');
  });

  test('no errors when viewing empty-state feature tabs', async ({ page }) => {
    const monitor = attachErrorMonitor(page);

    await waitForDashboard(page);
    // 002-payments (index 0) has minimal data — many views will show empty states
    await page.selectOption('#featureSelect', { index: 0 });
    await page.waitForTimeout(500);

    const tabs = [
      'Constitution', 'Spec', 'Clarify', 'Plan',
      'Checklist', 'Testify', 'Analyze', 'Implement'
    ];

    for (const tab of tabs) {
      await switchToTab(page, tab);
      await page.waitForTimeout(500);
    }

    monitor.assertClean('empty-state feature tabs');
  });

  test('no errors during theme toggle on each view', async ({ page }) => {
    const monitor = attachErrorMonitor(page);

    await waitForDashboard(page);
    await page.selectOption('#featureSelect', { index: 1 });
    await page.waitForTimeout(500);

    // Toggle theme on each tab
    const tabs = ['Implement', 'Constitution', 'Spec', 'Checklist', 'Testify', 'Analyze'];
    for (const tab of tabs) {
      await switchToTab(page, tab);
      await page.waitForTimeout(300);
      await page.click('#themeToggle');
      await page.waitForTimeout(300);
    }

    monitor.assertClean('theme toggle on each view');
  });

  test('no errors on rapid tab switching', async ({ page }) => {
    const monitor = attachErrorMonitor(page);

    await waitForDashboard(page);
    await page.selectOption('#featureSelect', { index: 1 });
    await page.waitForTimeout(500);

    // Rapidly switch through tabs without waiting
    const tabs = [
      'Constitution', 'Spec', 'Clarify', 'Plan',
      'Checklist', 'Testify', 'Analyze', 'Implement'
    ];
    for (const tab of tabs) {
      const node = page.locator('.pipeline-node', { hasText: tab });
      await node.click();
      // Minimal wait — stress rapid switching
      await page.waitForTimeout(100);
    }

    // Final settle
    await page.waitForTimeout(2000);

    monitor.assertClean('rapid tab switching');
  });
});
