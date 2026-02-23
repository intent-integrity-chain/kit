// @ts-check
const { test, expect } = require('@playwright/test');
const { createFixtureProject, startServer } = require('./helpers');

let port;
let cleanup;

test.beforeAll(async () => {
  const projectPath = createFixtureProject();
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

/** Wait for the dashboard to finish loading (pipeline rendered, board visible) */
async function waitForDashboard(page) {
  await page.goto(url());
  // Wait for pipeline bar to have phase nodes (data loaded)
  await page.waitForSelector('.pipeline-node', { timeout: 10000 });
  // Wait for board content or any view content to render
  await page.waitForSelector('#contentArea:not(:empty)', { timeout: 10000 });
  // Small settle time for animations/transitions
  await page.waitForTimeout(500);
}

/** Click a pipeline phase tab and wait for content to render */
async function switchToTab(page, phaseName) {
  const node = page.locator('.pipeline-node', { hasText: phaseName });
  await node.click();
  await page.waitForTimeout(800); // allow render + animations
}

// ============================================================
// Full page baseline
// ============================================================

test.describe('Full Page', () => {
  test('default view (Implement board)', async ({ page }) => {
    await waitForDashboard(page);
    await expect(page).toHaveScreenshot('full-page-default.png');
  });
});

// ============================================================
// Header & navigation
// ============================================================

test.describe('Header', () => {
  test('header with project label, feature selector, integrity badge', async ({ page }) => {
    await waitForDashboard(page);
    const header = page.locator('header.header');
    await expect(header).toHaveScreenshot('header.png', { maxDiffPixelRatio: 0.05 });
  });

  test('pipeline bar shows all phases', async ({ page }) => {
    await waitForDashboard(page);
    const pipeline = page.locator('#pipelineBar');
    await expect(pipeline).toHaveScreenshot('pipeline-bar.png');
  });

  test('feature selector dropdown', async ({ page }) => {
    await waitForDashboard(page);
    const selector = page.locator('.feature-selector');
    await expect(selector).toHaveScreenshot('feature-selector.png', { maxDiffPixelRatio: 0.10 });
  });
});

// ============================================================
// Implement (Board) View
// ============================================================

test.describe('Implement View', () => {
  test('kanban board with todo, in-progress, done columns', async ({ page }) => {
    await waitForDashboard(page);
    // Ensure we're on implement tab
    await switchToTab(page, 'Implement');
    const content = page.locator('#contentArea');
    await expect(content).toHaveScreenshot('implement-board.png');
  });
});

// ============================================================
// Constitution View
// ============================================================

test.describe('Constitution View', () => {
  test('constitution principles rendered', async ({ page }) => {
    await waitForDashboard(page);
    await switchToTab(page, 'Constitution');
    const content = page.locator('#contentArea');
    await expect(content).toHaveScreenshot('constitution-view.png');
  });
});

// ============================================================
// Spec (Story Map) View
// ============================================================

test.describe('Story Map View', () => {
  test('story map with stories, requirements, edges', async ({ page }) => {
    await waitForDashboard(page);
    await switchToTab(page, 'Spec');
    await page.waitForTimeout(500);
    const content = page.locator('#contentArea');
    await expect(content).toHaveScreenshot('storymap-view.png');
  });
});

// ============================================================
// Clarify View
// ============================================================

test.describe('Clarify View', () => {
  test('clarifications displayed', async ({ page }) => {
    await waitForDashboard(page);
    await switchToTab(page, 'Clarify');
    await page.waitForTimeout(500);
    const content = page.locator('#contentArea');
    await expect(content).toHaveScreenshot('clarify-view.png');
  });
});

// ============================================================
// Plan View
// ============================================================

test.describe('Plan View', () => {
  test('plan view with tech stack, diagram, file structure', async ({ page }) => {
    await waitForDashboard(page);
    await switchToTab(page, 'Plan');
    // Plan view is async (may call Claude API) — give extra time
    await page.waitForTimeout(2000);
    const content = page.locator('#contentArea');
    await expect(content).toHaveScreenshot('plan-view.png');
  });
});

// ============================================================
// Checklist View
// ============================================================

test.describe('Checklist View', () => {
  test('checklists with progress rings and gate status', async ({ page }) => {
    await waitForDashboard(page);
    await switchToTab(page, 'Checklist');
    await page.waitForTimeout(500);
    const content = page.locator('#contentArea');
    await expect(content).toHaveScreenshot('checklist-view.png');
  });
});

// ============================================================
// Testify View
// ============================================================

test.describe('Testify View', () => {
  test('test traceability graph with pyramid and integrity', async ({ page }) => {
    await waitForDashboard(page);
    await switchToTab(page, 'Testify');
    await page.waitForTimeout(500);
    const content = page.locator('#contentArea');
    await expect(content).toHaveScreenshot('testify-view.png');
  });
});

// ============================================================
// Analyze View
// ============================================================

test.describe('Analyze View', () => {
  test('analysis with health score, heatmap, issues', async ({ page }) => {
    await waitForDashboard(page);
    await switchToTab(page, 'Analyze');
    await page.waitForTimeout(500);
    const content = page.locator('#contentArea');
    await expect(content).toHaveScreenshot('analyze-view.png');
  });
});

// ============================================================
// Theme Toggle
// ============================================================

test.describe('Theme', () => {
  test('light theme full page', async ({ page }) => {
    await waitForDashboard(page);
    // Click theme toggle to switch to light mode
    await page.click('#themeToggle');
    await page.waitForTimeout(300);
    await expect(page).toHaveScreenshot('full-page-light-theme.png');
  });

  test('dark theme board view', async ({ page }) => {
    await waitForDashboard(page);
    // Default is dark, just screenshot
    await expect(page).toHaveScreenshot('board-dark-theme.png');
  });
});

// ============================================================
// Feature Switching
// ============================================================

test.describe('Feature Switching', () => {
  test('switch to second feature shows different board', async ({ page }) => {
    await waitForDashboard(page);
    // Select the second feature (002-payments)
    await page.selectOption('#featureSelect', { index: 1 });
    await page.waitForTimeout(1000); // wait for data reload
    const content = page.locator('#contentArea');
    await expect(content).toHaveScreenshot('feature-2-board.png');
  });
});

// ============================================================
// Empty / Placeholder States
// ============================================================

test.describe('Empty States', () => {
  test('plan view for feature without plan.md', async ({ page }) => {
    await waitForDashboard(page);
    // Switch to feature 2 which has no plan.md
    await page.selectOption('#featureSelect', { index: 1 });
    await page.waitForTimeout(500);
    await switchToTab(page, 'Plan');
    await page.waitForTimeout(500);
    const content = page.locator('#contentArea');
    await expect(content).toHaveScreenshot('plan-empty-state.png');
  });

  test('checklist view for feature without checklists', async ({ page }) => {
    await waitForDashboard(page);
    await page.selectOption('#featureSelect', { index: 1 });
    await page.waitForTimeout(500);
    await switchToTab(page, 'Checklist');
    await page.waitForTimeout(500);
    const content = page.locator('#contentArea');
    await expect(content).toHaveScreenshot('checklist-empty-state.png');
  });

  test('testify view for feature without test-specs', async ({ page }) => {
    await waitForDashboard(page);
    await page.selectOption('#featureSelect', { index: 1 });
    await page.waitForTimeout(500);
    await switchToTab(page, 'Testify');
    await page.waitForTimeout(500);
    const content = page.locator('#contentArea');
    await expect(content).toHaveScreenshot('testify-empty-state.png');
  });

  test('analyze view for feature without analysis.md', async ({ page }) => {
    await waitForDashboard(page);
    await page.selectOption('#featureSelect', { index: 1 });
    await page.waitForTimeout(500);
    await switchToTab(page, 'Analyze');
    await page.waitForTimeout(500);
    const content = page.locator('#contentArea');
    await expect(content).toHaveScreenshot('analyze-empty-state.png');
  });
});

// ============================================================
// Responsive: narrower viewport
// ============================================================

test.describe('Responsive', () => {
  test('narrow viewport (1024px)', async ({ page }) => {
    await page.setViewportSize({ width: 1024, height: 768 });
    await waitForDashboard(page);
    await expect(page).toHaveScreenshot('responsive-1024.png');
  });

  test('tablet viewport (768px)', async ({ page }) => {
    await page.setViewportSize({ width: 768, height: 1024 });
    await waitForDashboard(page);
    await expect(page).toHaveScreenshot('responsive-768.png');
  });
});
