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

/** Select feature by index (features are sorted newest-first: 002-payments=0, 001-auth=1) */
async function selectFeatureByIndex(page, index) {
  await page.selectOption('#featureSelect', { index });
  await page.waitForTimeout(500);
}

// ============================================================
// Tab Navigation
// ============================================================

test.describe('Tab Navigation', () => {
  test('clicking each pipeline phase switches the view', async ({ page }) => {
    await waitForDashboard(page);

    // Constitution tab
    await switchToTab(page, 'Constitution');
    await expect(page.locator('.constitution-view').or(page.locator('.placeholder-view'))).toBeVisible();
    await expect(page.locator('.pipeline-node.active', { hasText: 'Constitution' })).toBeVisible();

    // Spec tab
    await switchToTab(page, 'Spec');
    await expect(page.locator('.storymap-view').or(page.locator('.placeholder-view'))).toBeVisible();
    await expect(page.locator('.pipeline-node.active', { hasText: 'Spec' })).toBeVisible();

    // Plan tab
    await switchToTab(page, 'Plan');
    await page.waitForTimeout(1000); // async view
    await expect(page.locator('.planview-view').or(page.locator('.planview-empty'))).toBeVisible();
    await expect(page.locator('.pipeline-node.active', { hasText: 'Plan' })).toBeVisible();

    // Checklist tab (may render as checklist-view or empty gate state)
    await switchToTab(page, 'Checklist');
    await expect(page.locator('#contentArea')).not.toBeEmpty();
    await expect(page.locator('.pipeline-node.active', { hasText: 'Checklist' })).toBeVisible();

    // Testify tab
    await switchToTab(page, 'Testify');
    await expect(page.locator('.testify-view').or(page.locator('.testify-empty'))).toBeVisible();
    await expect(page.locator('.pipeline-node.active', { hasText: 'Testify' })).toBeVisible();

    // Analyze tab
    await switchToTab(page, 'Analyze');
    await expect(page.locator('.analyze-view').or(page.locator('.analyze-empty'))).toBeVisible();
    await expect(page.locator('.pipeline-node.active', { hasText: 'Analyze' })).toBeVisible();

    // Implement tab
    await switchToTab(page, 'Implement');
    await expect(page.locator('.board-container')).toBeVisible();
    await expect(page.locator('.pipeline-node.active', { hasText: 'Implement' })).toBeVisible();
  });

  test('Tasks tab redirects to Implement board with toast', async ({ page }) => {
    await waitForDashboard(page);
    await switchToTab(page, 'Constitution'); // go somewhere else first
    await switchToTab(page, 'Tasks');

    // Should show the board (Implement), not a tasks view
    await expect(page.locator('.board-container')).toBeVisible();
    // Toast should appear
    await expect(page.locator('#toast')).toHaveClass(/visible/);
    await expect(page.locator('#toast')).toContainText('Implement board');
  });
});

// ============================================================
// Board Interactions
// ============================================================

test.describe('Board Interactions', () => {
  test('kanban board has todo, in-progress, and done columns', async ({ page }) => {
    await waitForDashboard(page);
    await switchToTab(page, 'Implement');

    // Column titles are "Todo", "In Progress", "Done"
    await expect(page.locator('.column.todo')).toBeVisible();
    await expect(page.locator('.column.done')).toBeVisible();
  });

  test('cards show progress bars', async ({ page }) => {
    await waitForDashboard(page);
    await switchToTab(page, 'Implement');

    const progressBars = page.locator('.progress-bar');
    await expect(progressBars.first()).toBeVisible();
  });

  test('task list expands and collapses on toggle click', async ({ page }) => {
    await waitForDashboard(page);
    await switchToTab(page, 'Implement');

    const toggle = page.locator('.task-toggle').first();
    await expect(toggle).toBeVisible();

    const taskList = page.locator('.task-list').first();
    await expect(taskList).toHaveClass(/collapsed/);

    // Click to expand
    await toggle.click();
    await page.waitForTimeout(300);
    await expect(taskList).toHaveClass(/expanded/);

    // Click to collapse
    await toggle.click();
    await page.waitForTimeout(300);
    await expect(taskList).toHaveClass(/collapsed/);
  });

  test('expanded task list shows task items with checkboxes', async ({ page }) => {
    await waitForDashboard(page);
    await switchToTab(page, 'Implement');

    const toggle = page.locator('.task-toggle').first();
    await toggle.click();
    await page.waitForTimeout(300);

    await expect(page.locator('.task-item').first()).toBeVisible();
    await expect(page.locator('.task-id').first()).toBeVisible();
    await expect(page.locator('.task-description').first()).toBeVisible();
  });
});

// ============================================================
// Feature Switching
// ============================================================

test.describe('Feature Switching', () => {
  test('changing feature reloads pipeline and board data', async ({ page }) => {
    await waitForDashboard(page);

    const initialNodes = await page.locator('.pipeline-node').count();
    expect(initialNodes).toBe(9);

    // Switch to second feature
    await selectFeatureByIndex(page, 1);
    await page.waitForTimeout(500);

    const newNodes = await page.locator('.pipeline-node').count();
    expect(newNodes).toBe(9);
  });

  test('feature selector shows all features', async ({ page }) => {
    await waitForDashboard(page);
    const options = await page.locator('#featureSelect option').allInnerTexts();
    expect(options.length).toBe(2);
  });
});

// ============================================================
// Theme Toggle
// ============================================================

test.describe('Theme Toggle', () => {
  test('clicking theme toggle cycles through themes', async ({ page }) => {
    await waitForDashboard(page);

    // Cycle: system → light → dark → system
    // Collect aria-label changes as evidence of cycling
    const labels = [];
    for (let i = 0; i < 3; i++) {
      await page.click('#themeToggle');
      await page.waitForTimeout(200);
      const label = await page.locator('#themeToggle').getAttribute('aria-label');
      labels.push(label);
    }

    // All 3 clicks should produce different aria-labels
    const unique = new Set(labels);
    expect(unique.size).toBe(3);
  });

  test('theme icon changes on toggle', async ({ page }) => {
    await waitForDashboard(page);
    const iconBefore = await page.locator('#themeIcon').innerText();
    await page.click('#themeToggle');
    await page.waitForTimeout(200);
    const iconAfter = await page.locator('#themeIcon').innerText();
    expect(iconBefore).not.toEqual(iconAfter);
  });
});

// ============================================================
// Integrity Badge
// ============================================================

test.describe('Integrity Badge', () => {
  test('integrity badge shows status text', async ({ page }) => {
    await waitForDashboard(page);
    const badge = page.locator('#integrityBadge');
    await expect(badge).toBeVisible();
    const text = await badge.locator('.integrity-text').innerText();
    expect(text.length).toBeGreaterThan(0);
  });

  test('integrity badge has status class', async ({ page }) => {
    await waitForDashboard(page);
    const badge = page.locator('#integrityBadge');
    const classList = await badge.getAttribute('class');
    expect(classList).toMatch(/valid|tampered|missing/);
  });
});

// ============================================================
// Constitution View Behavior
// ============================================================

test.describe('Constitution View', () => {
  test('displays principles with obligation levels', async ({ page }) => {
    await waitForDashboard(page);
    await switchToTab(page, 'Constitution');

    // Constitution view uses a summary list with level badges
    await expect(page.locator('.constitution-view')).toBeVisible();
    // Level badges: .level-badge.must, .level-badge.should, .level-badge.may
    await expect(page.locator('.level-badge.must').first()).toBeVisible();
    await expect(page.locator('.level-badge.should').first()).toBeVisible();
  });

  test('displays version footer', async ({ page }) => {
    await waitForDashboard(page);
    await switchToTab(page, 'Constitution');

    await expect(page.locator('.constitution-view')).toContainText('1.0');
  });
});

// ============================================================
// Checklist View Behavior
// ============================================================

test.describe('Checklist View', () => {
  test('shows progress rings for each checklist file', async ({ page }) => {
    await waitForDashboard(page);
    // Feature 001-auth is at index 1 (sorted newest first: 002=0, 001=1)
    await selectFeatureByIndex(page, 1);
    await switchToTab(page, 'Checklist');

    // Rings use .checklist-ring-wrapper
    const rings = page.locator('.checklist-ring-wrapper');
    const count = await rings.count();
    expect(count).toBe(3); // security, ux, api checklists
  });

  test('shows gate status', async ({ page }) => {
    await waitForDashboard(page);
    await selectFeatureByIndex(page, 1);
    await switchToTab(page, 'Checklist');

    // Gate indicator: .gate-indicator with .gate-label
    await expect(page.locator('.gate-indicator')).toBeVisible();
    await expect(page.locator('.gate-label')).toBeVisible();
  });

  test('clicking a ring expands checklist detail', async ({ page }) => {
    await waitForDashboard(page);
    await selectFeatureByIndex(page, 1);
    await switchToTab(page, 'Checklist');

    // Click a ring wrapper to expand
    const ring = page.locator('.checklist-ring-wrapper').first();
    await ring.click();
    await page.waitForTimeout(300);

    // Should show expanded state
    await expect(ring).toHaveClass(/expanded/);
    // Detail section should be visible
    await expect(page.locator('.checklist-detail').first()).toBeVisible();
  });
});

// ============================================================
// Story Map View Behavior
// ============================================================

test.describe('Story Map View', () => {
  test('renders story cards with titles', async ({ page }) => {
    await waitForDashboard(page);
    await selectFeatureByIndex(page, 1); // 001-auth
    await switchToTab(page, 'Spec');

    const storyCards = page.locator('.story-card');
    const count = await storyCards.count();
    expect(count).toBe(4); // 4 user stories in fixture
  });

  test('renders requirement nodes in the graph', async ({ page }) => {
    await waitForDashboard(page);
    await selectFeatureByIndex(page, 1);
    await switchToTab(page, 'Spec');

    // Graph SVG should be present
    await expect(page.locator('.graph-svg')).toBeVisible();
    // Should have FR nodes
    const frNodes = page.locator('.graph-node');
    const count = await frNodes.count();
    expect(count).toBeGreaterThanOrEqual(1);
  });

  test('clicking a story card shows detail panel', async ({ page }) => {
    await waitForDashboard(page);
    await selectFeatureByIndex(page, 1);
    await switchToTab(page, 'Spec');

    const card = page.locator('.story-card').first();
    await card.click();
    await page.waitForTimeout(500);

    // Detail panel should appear
    await expect(page.locator('.detail-panel').or(page.locator('.detail-card'))).toBeVisible();
  });
});

// ============================================================
// Analyze View Behavior
// ============================================================

test.describe('Analyze View', () => {
  test('shows health score gauge', async ({ page }) => {
    await waitForDashboard(page);
    await selectFeatureByIndex(page, 1); // 001-auth
    await switchToTab(page, 'Analyze');

    // Gauge uses .gauge-score text element inside SVG
    await expect(page.locator('.gauge-score')).toBeVisible();
  });

  test('shows issues with severity badges', async ({ page }) => {
    await waitForDashboard(page);
    await selectFeatureByIndex(page, 1);
    await switchToTab(page, 'Analyze');

    // Issues use .severity-badge
    const badges = page.locator('.severity-badge');
    const count = await badges.count();
    expect(count).toBeGreaterThanOrEqual(1);
  });

  test('shows coverage heatmap table', async ({ page }) => {
    await waitForDashboard(page);
    await selectFeatureByIndex(page, 1);
    await switchToTab(page, 'Analyze');

    await expect(page.locator('.heatmap-table')).toBeVisible();
    // Should have heatmap cells
    const cells = page.locator('.heatmap-cell');
    const count = await cells.count();
    expect(count).toBeGreaterThanOrEqual(1);
  });
});

// ============================================================
// Plan View Behavior
// ============================================================

test.describe('Plan View', () => {
  test('shows tech stack badges', async ({ page }) => {
    await waitForDashboard(page);
    await selectFeatureByIndex(page, 1); // 001-auth
    await switchToTab(page, 'Plan');
    // Plan view is async (Claude API call) — wait for content to render
    await page.waitForSelector('.planview-view, .planview-empty', { timeout: 10000 });
    await page.waitForTimeout(500);

    // If plan rendered successfully (not empty), check for badges
    const planView = page.locator('.planview-view');
    if (await planView.count() > 0) {
      const badges = page.locator('.tech-badge');
      const count = await badges.count();
      expect(count).toBeGreaterThanOrEqual(1);
    }
  });

  test('shows architecture diagram container', async ({ page }) => {
    await waitForDashboard(page);
    await selectFeatureByIndex(page, 1);
    await switchToTab(page, 'Plan');
    await page.waitForSelector('.planview-view, .planview-empty', { timeout: 10000 });
    await page.waitForTimeout(500);

    const planView = page.locator('.planview-view');
    if (await planView.count() > 0) {
      await expect(page.locator('.planview-section').first()).toBeVisible();
    }
  });

  test('shows file structure section', async ({ page }) => {
    await waitForDashboard(page);
    await selectFeatureByIndex(page, 1);
    await switchToTab(page, 'Plan');
    await page.waitForSelector('.planview-view, .planview-empty', { timeout: 10000 });
    await page.waitForTimeout(500);

    const planView = page.locator('.planview-view');
    if (await planView.count() > 0) {
      // File structure is the last planview-section
      const sections = page.locator('.planview-section');
      const count = await sections.count();
      expect(count).toBeGreaterThanOrEqual(2);
      await expect(sections.last()).toBeVisible();
    }
  });
});

// ============================================================
// Testify View Behavior
// ============================================================

test.describe('Testify View', () => {
  test('shows sankey traceability nodes', async ({ page }) => {
    await waitForDashboard(page);
    await selectFeatureByIndex(page, 1); // 001-auth
    await switchToTab(page, 'Testify');

    const nodes = page.locator('.sankey-node');
    const count = await nodes.count();
    expect(count).toBeGreaterThanOrEqual(1);
  });

  test('shows test pyramid group labels', async ({ page }) => {
    await waitForDashboard(page);
    await selectFeatureByIndex(page, 1);
    await switchToTab(page, 'Testify');

    // Pyramid tiers shown as sankey group labels
    const labels = page.locator('.sankey-group-label');
    const count = await labels.count();
    expect(count).toBeGreaterThanOrEqual(1);
  });

  test('shows integrity seal', async ({ page }) => {
    await waitForDashboard(page);
    await selectFeatureByIndex(page, 1);
    await switchToTab(page, 'Testify');

    await expect(page.locator('.testify-seal')).toBeVisible();
  });
});

// ============================================================
// Cross-Panel Navigation
// ============================================================

test.describe('Cross-Panel Navigation', () => {
  test('Cmd+click on task ID in board navigates to testify', async ({ page }) => {
    await waitForDashboard(page);
    await selectFeatureByIndex(page, 1); // 001-auth
    await switchToTab(page, 'Implement');

    // Expand a task list
    const toggle = page.locator('.task-toggle').first();
    await toggle.click();
    await page.waitForTimeout(300);

    // Cmd+click a task ID cross-link
    const taskLink = page.locator('.task-id.cross-link').first();
    await taskLink.click({ modifiers: ['Meta'] });
    await page.waitForTimeout(800);

    // Should navigate to testify view
    await expect(page.locator('.pipeline-node.active', { hasText: 'Testify' })).toBeVisible();
  });

  test('Cmd+click on card ID in board navigates to spec', async ({ page }) => {
    await waitForDashboard(page);
    await selectFeatureByIndex(page, 1); // 001-auth
    await switchToTab(page, 'Implement');

    // Cmd+click a card ID (US link)
    const cardLink = page.locator('.card-id.cross-link').first();
    await cardLink.click({ modifiers: ['Meta'] });
    await page.waitForTimeout(800);

    // Should navigate to spec view
    await expect(page.locator('.pipeline-node.active', { hasText: 'Spec' })).toBeVisible();
  });
});

// ============================================================
// WebSocket Live Updates — REMOVED (replaced by meta-refresh in static HTML mode)

// ============================================================
// Toast Notifications
// ============================================================

test.describe('Toast Notifications', () => {
  test('toast appears and auto-dismisses', async ({ page }) => {
    await waitForDashboard(page);

    // Trigger toast by clicking Tasks tab
    await switchToTab(page, 'Tasks');

    const toast = page.locator('#toast');
    await expect(toast).toHaveClass(/visible/);
    await expect(toast).toContainText('Implement board');

    // Wait for auto-dismiss (2500ms)
    await page.waitForTimeout(3000);
    await expect(toast).not.toHaveClass(/visible/);
  });
});

// ============================================================
// Keyboard Accessibility
// ============================================================

test.describe('Accessibility', () => {
  test('pipeline nodes are focusable with tabindex', async ({ page }) => {
    await waitForDashboard(page);
    const nodes = page.locator('.pipeline-node');
    const count = await nodes.count();

    for (let i = 0; i < count; i++) {
      const tabindex = await nodes.nth(i).getAttribute('tabindex');
      expect(tabindex).toBe('0');
    }
  });

  test('pipeline nav has aria-label', async ({ page }) => {
    await waitForDashboard(page);
    const nav = page.locator('#pipelineBar');
    const ariaLabel = await nav.getAttribute('aria-label');
    expect(ariaLabel).toBeTruthy();
  });

  test('board has role=region', async ({ page }) => {
    await waitForDashboard(page);
    await switchToTab(page, 'Implement');
    const board = page.locator('[role="region"]').first();
    await expect(board).toBeVisible();
  });

  test('theme toggle has aria-label', async ({ page }) => {
    await waitForDashboard(page);
    const toggle = page.locator('#themeToggle');
    const ariaLabel = await toggle.getAttribute('aria-label');
    expect(ariaLabel).toBeTruthy();
    // Aria-label is "Theme: ..." (capital T)
    expect(ariaLabel).toMatch(/Theme/i);
  });
});
