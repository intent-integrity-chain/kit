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

// Generous upper bounds to catch major regressions only
const INITIAL_LOAD_MAX_MS = 3000;
const TAB_SWITCH_MAX_MS = 1000;
const WEBSOCKET_UPDATE_MAX_MS = 2000;

test.describe('Performance Baselines', () => {

  test('initial load: page.goto to pipeline bar visible', async ({ page }) => {
    const start = Date.now();

    await page.goto(url());
    await page.waitForSelector('.pipeline-node', { timeout: 10000 });

    const elapsed = Date.now() - start;

    expect(elapsed).toBeLessThan(INITIAL_LOAD_MAX_MS);
  });

  test('initial load: page.goto to board fully rendered', async ({ page }) => {
    const start = Date.now();

    await page.goto(url());
    await page.waitForSelector('.pipeline-node', { timeout: 10000 });
    await page.waitForSelector('#contentArea:not(:empty)', { timeout: 10000 });
    // Wait for actual board cards to be present
    await page.waitForSelector('.card, .board-container, .empty-state', { timeout: 10000 });

    const elapsed = Date.now() - start;

    expect(elapsed).toBeLessThan(INITIAL_LOAD_MAX_MS);
  });

  test('tab switch: Implement to Constitution', async ({ page }) => {
    await page.goto(url());
    await page.waitForSelector('.pipeline-node', { timeout: 10000 });
    await page.waitForSelector('#contentArea:not(:empty)', { timeout: 10000 });
    await page.waitForTimeout(500);

    const start = Date.now();
    const node = page.locator('.pipeline-node', { hasText: 'Constitution' });
    await node.click();
    await page.waitForSelector('.constitution-view, .placeholder-view', { timeout: 10000 });
    const elapsed = Date.now() - start;

    expect(elapsed).toBeLessThan(TAB_SWITCH_MAX_MS);
  });

  test('tab switch: to Spec (story map) view', async ({ page }) => {
    await page.goto(url());
    await page.waitForSelector('.pipeline-node', { timeout: 10000 });
    await page.waitForSelector('#contentArea:not(:empty)', { timeout: 10000 });
    await page.selectOption('#featureSelect', { index: 1 });
    await page.waitForTimeout(500);

    const start = Date.now();
    const node = page.locator('.pipeline-node', { hasText: 'Spec' });
    await node.click();
    await page.waitForSelector('.storymap-view, .placeholder-view', { timeout: 10000 });
    const elapsed = Date.now() - start;

    expect(elapsed).toBeLessThan(TAB_SWITCH_MAX_MS);
  });

  test('tab switch: to Checklist view', async ({ page }) => {
    await page.goto(url());
    await page.waitForSelector('.pipeline-node', { timeout: 10000 });
    await page.waitForSelector('#contentArea:not(:empty)', { timeout: 10000 });
    await page.selectOption('#featureSelect', { index: 1 });
    await page.waitForTimeout(500);

    const start = Date.now();
    const node = page.locator('.pipeline-node', { hasText: 'Checklist' });
    await node.click();
    await page.waitForSelector('.checklist-view, .checklist-empty', { timeout: 10000 });
    const elapsed = Date.now() - start;

    expect(elapsed).toBeLessThan(TAB_SWITCH_MAX_MS);
  });

  test('tab switch: to Testify view', async ({ page }) => {
    await page.goto(url());
    await page.waitForSelector('.pipeline-node', { timeout: 10000 });
    await page.waitForSelector('#contentArea:not(:empty)', { timeout: 10000 });
    await page.selectOption('#featureSelect', { index: 1 });
    await page.waitForTimeout(500);

    const start = Date.now();
    const node = page.locator('.pipeline-node', { hasText: 'Testify' });
    await node.click();
    await page.waitForSelector('.testify-view, .testify-empty', { timeout: 10000 });
    const elapsed = Date.now() - start;

    expect(elapsed).toBeLessThan(TAB_SWITCH_MAX_MS);
  });

  test('tab switch: to Analyze view', async ({ page }) => {
    await page.goto(url());
    await page.waitForSelector('.pipeline-node', { timeout: 10000 });
    await page.waitForSelector('#contentArea:not(:empty)', { timeout: 10000 });
    await page.selectOption('#featureSelect', { index: 1 });
    await page.waitForTimeout(500);

    const start = Date.now();
    const node = page.locator('.pipeline-node', { hasText: 'Analyze' });
    await node.click();
    await page.waitForSelector('.analyze-view, .analyze-empty', { timeout: 10000 });
    const elapsed = Date.now() - start;

    expect(elapsed).toBeLessThan(TAB_SWITCH_MAX_MS);
  });

  test('tab switch: to Plan view', async ({ page }) => {
    await page.goto(url());
    await page.waitForSelector('.pipeline-node', { timeout: 10000 });
    await page.waitForSelector('#contentArea:not(:empty)', { timeout: 10000 });
    await page.selectOption('#featureSelect', { index: 1 });
    await page.waitForTimeout(500);

    const start = Date.now();
    const node = page.locator('.pipeline-node', { hasText: 'Plan' });
    await node.click();
    await page.waitForSelector('.planview-view, .planview-empty', { timeout: 10000 });
    const elapsed = Date.now() - start;

    // Plan view may involve async computation, allow more time
    expect(elapsed).toBeLessThan(TAB_SWITCH_MAX_MS * 2);
  });

  test('tab switch: to Clarify view', async ({ page }) => {
    await page.goto(url());
    await page.waitForSelector('.pipeline-node', { timeout: 10000 });
    await page.waitForSelector('#contentArea:not(:empty)', { timeout: 10000 });
    await page.selectOption('#featureSelect', { index: 1 });
    await page.waitForTimeout(500);

    const start = Date.now();
    const node = page.locator('.pipeline-node', { hasText: 'Clarify' });
    await node.click();
    // Clarify view may render into the content area
    await page.waitForTimeout(200);
    await page.waitForSelector('#contentArea:not(:empty)', { timeout: 10000 });
    const elapsed = Date.now() - start;

    expect(elapsed).toBeLessThan(TAB_SWITCH_MAX_MS);
  });

  test('tab switch: back to Implement view', async ({ page }) => {
    await page.goto(url());
    await page.waitForSelector('.pipeline-node', { timeout: 10000 });
    await page.waitForSelector('#contentArea:not(:empty)', { timeout: 10000 });
    await page.waitForTimeout(500);

    // Switch away first
    const constitutionNode = page.locator('.pipeline-node', { hasText: 'Constitution' });
    await constitutionNode.click();
    await page.waitForTimeout(500);

    const start = Date.now();
    const implementNode = page.locator('.pipeline-node', { hasText: 'Implement' });
    await implementNode.click();
    await page.waitForSelector('.board-container', { timeout: 10000 });
    const elapsed = Date.now() - start;

    expect(elapsed).toBeLessThan(TAB_SWITCH_MAX_MS);
  });

  test('feature switch: time to re-render board', async ({ page }) => {
    await page.goto(url());
    await page.waitForSelector('.pipeline-node', { timeout: 10000 });
    await page.waitForSelector('#contentArea:not(:empty)', { timeout: 10000 });
    await page.waitForTimeout(500);

    const start = Date.now();
    await page.selectOption('#featureSelect', { index: 1 });
    // Wait for board to re-render with new feature data
    await page.waitForSelector('.card, .board-container, .empty-state', { timeout: 10000 });
    const elapsed = Date.now() - start;

    expect(elapsed).toBeLessThan(INITIAL_LOAD_MAX_MS);
  });

  // WebSocket update test removed — replaced by meta-refresh in static HTML mode

  test('full navigation cycle: all tabs within budget', async ({ page }) => {
    await page.goto(url());
    await page.waitForSelector('.pipeline-node', { timeout: 10000 });
    await page.waitForSelector('#contentArea:not(:empty)', { timeout: 10000 });
    await page.selectOption('#featureSelect', { index: 1 });
    await page.waitForTimeout(500);

    const tabs = [
      { name: 'Constitution', selector: '.constitution-view, .placeholder-view' },
      { name: 'Spec', selector: '.storymap-view, .placeholder-view' },
      { name: 'Clarify', selector: '#contentArea:not(:empty)' },
      { name: 'Checklist', selector: '.checklist-view, .checklist-empty' },
      { name: 'Testify', selector: '.testify-view, .testify-empty' },
      { name: 'Analyze', selector: '.analyze-view, .analyze-empty' },
      { name: 'Implement', selector: '.board-container' },
    ];

    const timings = {};

    for (const tab of tabs) {
      const start = Date.now();
      const node = page.locator('.pipeline-node', { hasText: tab.name });
      await node.click();
      await page.waitForSelector(tab.selector, { timeout: 10000 });
      timings[tab.name] = Date.now() - start;
    }

    // Each tab switch should be within budget
    for (const [tab, ms] of Object.entries(timings)) {
      expect(ms, `Tab "${tab}" took ${ms}ms`).toBeLessThan(TAB_SWITCH_MAX_MS);
    }
  });
});
