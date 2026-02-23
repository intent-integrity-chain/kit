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

/**
 * Extract a normalised DOM structure from a given selector.
 * Returns a JSON tree of { tag, classes, dataAttrs, ariaAttrs, role, children }.
 * Strips text content, inline styles, and dynamic IDs.
 */
async function extractDOMStructure(page, selector) {
  return page.evaluate((sel) => {
    function walkNode(el) {
      if (!(el instanceof Element)) return null;

      const tag = el.tagName.toLowerCase();

      // Collect sorted class names
      const classes = [...el.classList].sort();

      // Collect data-* attributes
      const dataAttrs = {};
      for (const attr of el.attributes) {
        if (attr.name.startsWith('data-')) {
          dataAttrs[attr.name] = attr.value;
        }
      }

      // Collect aria-* attributes
      const ariaAttrs = {};
      for (const attr of el.attributes) {
        if (attr.name.startsWith('aria-')) {
          ariaAttrs[attr.name] = attr.value;
        }
      }

      // Role attribute
      const role = el.getAttribute('role') || null;

      // Recurse children (only Element nodes, skip text/comment)
      const children = [];
      for (const child of el.children) {
        const childNode = walkNode(child);
        if (childNode) {
          children.push(childNode);
        }
      }

      const node = { tag };
      if (classes.length > 0) node.classes = classes;
      if (Object.keys(dataAttrs).length > 0) node.dataAttrs = dataAttrs;
      if (Object.keys(ariaAttrs).length > 0) node.ariaAttrs = ariaAttrs;
      if (role) node.role = role;
      if (children.length > 0) node.children = children;

      return node;
    }

    const root = document.querySelector(sel);
    if (!root) return null;
    return walkNode(root);
  }, selector);
}

test.describe('DOM Structure Snapshots', () => {

  test('header structure', async ({ page }) => {
    await waitForDashboard(page);
    const structure = await extractDOMStructure(page, 'header.header');
    expect(structure).not.toBeNull();
    expect(JSON.stringify(structure, null, 2)).toMatchSnapshot('header-dom-structure.json');
  });

  test('pipeline bar structure', async ({ page }) => {
    await waitForDashboard(page);
    const structure = await extractDOMStructure(page, '#pipelineBar');
    expect(structure).not.toBeNull();
    expect(JSON.stringify(structure, null, 2)).toMatchSnapshot('pipeline-bar-dom-structure.json');
  });

  test('Implement (board) view structure', async ({ page }) => {
    await waitForDashboard(page);
    await switchToTab(page, 'Implement');
    await page.waitForTimeout(300);
    const structure = await extractDOMStructure(page, '#contentArea');
    expect(structure).not.toBeNull();
    expect(JSON.stringify(structure, null, 2)).toMatchSnapshot('implement-view-dom-structure.json');
  });

  test('Constitution view structure', async ({ page }) => {
    await waitForDashboard(page);
    await switchToTab(page, 'Constitution');
    await page.waitForTimeout(300);
    const structure = await extractDOMStructure(page, '#contentArea');
    expect(structure).not.toBeNull();
    expect(JSON.stringify(structure, null, 2)).toMatchSnapshot('constitution-view-dom-structure.json');
  });

  test('Spec (story map) view structure', async ({ page }) => {
    await waitForDashboard(page);
    await page.selectOption('#featureSelect', { index: 1 });
    await page.waitForTimeout(500);
    await switchToTab(page, 'Spec');
    await page.waitForTimeout(500);
    const structure = await extractDOMStructure(page, '#contentArea');
    expect(structure).not.toBeNull();
    expect(JSON.stringify(structure, null, 2)).toMatchSnapshot('storymap-view-dom-structure.json');
  });

  test('Clarify view structure', async ({ page }) => {
    await waitForDashboard(page);
    await page.selectOption('#featureSelect', { index: 1 });
    await page.waitForTimeout(500);
    await switchToTab(page, 'Clarify');
    await page.waitForTimeout(500);
    const structure = await extractDOMStructure(page, '#contentArea');
    expect(structure).not.toBeNull();
    expect(JSON.stringify(structure, null, 2)).toMatchSnapshot('clarify-view-dom-structure.json');
  });

  test('Plan view structure', async ({ page }) => {
    await waitForDashboard(page);
    await page.selectOption('#featureSelect', { index: 1 });
    await page.waitForTimeout(500);
    await switchToTab(page, 'Plan');
    await page.waitForSelector('.planview-view, .planview-empty', { timeout: 10000 });
    await page.waitForTimeout(500);
    const structure = await extractDOMStructure(page, '#contentArea');
    expect(structure).not.toBeNull();
    expect(JSON.stringify(structure, null, 2)).toMatchSnapshot('plan-view-dom-structure.json');
  });

  test('Checklist view structure', async ({ page }) => {
    await waitForDashboard(page);
    await page.selectOption('#featureSelect', { index: 1 });
    await page.waitForTimeout(500);
    await switchToTab(page, 'Checklist');
    await page.waitForTimeout(500);
    const structure = await extractDOMStructure(page, '#contentArea');
    expect(structure).not.toBeNull();
    expect(JSON.stringify(structure, null, 2)).toMatchSnapshot('checklist-view-dom-structure.json');
  });

  test('Testify view structure', async ({ page }) => {
    await waitForDashboard(page);
    await page.selectOption('#featureSelect', { index: 1 });
    await page.waitForTimeout(500);
    await switchToTab(page, 'Testify');
    await page.waitForTimeout(500);
    const structure = await extractDOMStructure(page, '#contentArea');
    expect(structure).not.toBeNull();
    expect(JSON.stringify(structure, null, 2)).toMatchSnapshot('testify-view-dom-structure.json');
  });

  test('Analyze view structure', async ({ page }) => {
    await waitForDashboard(page);
    await page.selectOption('#featureSelect', { index: 1 });
    await page.waitForTimeout(500);
    await switchToTab(page, 'Analyze');
    await page.waitForTimeout(500);
    const structure = await extractDOMStructure(page, '#contentArea');
    expect(structure).not.toBeNull();
    expect(JSON.stringify(structure, null, 2)).toMatchSnapshot('analyze-view-dom-structure.json');
  });

  test('empty-state board structure (feature with minimal data)', async ({ page }) => {
    await waitForDashboard(page);
    // 002-payments (index 0) has minimal data
    await page.selectOption('#featureSelect', { index: 0 });
    await page.waitForTimeout(500);
    await switchToTab(page, 'Implement');
    await page.waitForTimeout(300);
    const structure = await extractDOMStructure(page, '#contentArea');
    expect(structure).not.toBeNull();
    expect(JSON.stringify(structure, null, 2)).toMatchSnapshot('empty-board-dom-structure.json');
  });

  test('empty-state checklist structure', async ({ page }) => {
    await waitForDashboard(page);
    // 002-payments has no checklists
    await page.selectOption('#featureSelect', { index: 0 });
    await page.waitForTimeout(500);
    await switchToTab(page, 'Checklist');
    await page.waitForTimeout(500);
    const structure = await extractDOMStructure(page, '#contentArea');
    expect(structure).not.toBeNull();
    expect(JSON.stringify(structure, null, 2)).toMatchSnapshot('empty-checklist-dom-structure.json');
  });

  test('empty-state testify structure', async ({ page }) => {
    await waitForDashboard(page);
    await page.selectOption('#featureSelect', { index: 0 });
    await page.waitForTimeout(500);
    await switchToTab(page, 'Testify');
    await page.waitForTimeout(500);
    const structure = await extractDOMStructure(page, '#contentArea');
    expect(structure).not.toBeNull();
    expect(JSON.stringify(structure, null, 2)).toMatchSnapshot('empty-testify-dom-structure.json');
  });

  test('empty-state analyze structure', async ({ page }) => {
    await waitForDashboard(page);
    await page.selectOption('#featureSelect', { index: 0 });
    await page.waitForTimeout(500);
    await switchToTab(page, 'Analyze');
    await page.waitForTimeout(500);
    const structure = await extractDOMStructure(page, '#contentArea');
    expect(structure).not.toBeNull();
    expect(JSON.stringify(structure, null, 2)).toMatchSnapshot('empty-analyze-dom-structure.json');
  });
});
