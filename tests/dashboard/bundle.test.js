'use strict';

const path = require('path');
const fs = require('fs');
const os = require('os');
const { spawnSync } = require('child_process');
const crypto = require('crypto');

const MODULAR_PATH = path.join(__dirname, '../../.claude/skills/iikit-core/scripts/dashboard', 'src', 'generate-dashboard.js');
const BUNDLED_PATH = path.join(__dirname, '../../.claude/skills/iikit-core/scripts/dashboard', 'generate-dashboard.js');

function createTestProject() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'iikit-bundle-'));
  fs.mkdirSync(path.join(dir, 'specs', '001-test-feature', 'tests'), { recursive: true });
  fs.mkdirSync(path.join(dir, 'specs', '001-test-feature', 'checklists'), { recursive: true });
  fs.writeFileSync(path.join(dir, 'specs', '001-test-feature', 'spec.md'),
    '# Feature Specification: Test\n\n## User Scenarios\n\n### User Story 1\nAs a user...\n\n**Acceptance Scenarios**:\n1. **Given** X, **When** Y, **Then** Z\n');
  fs.writeFileSync(path.join(dir, 'specs', '001-test-feature', 'tasks.md'),
    '# Tasks\n- [ ] T001 A task\n- [x] T002 Done task\n');
  fs.writeFileSync(path.join(dir, 'CONSTITUTION.md'),
    '# Constitution\n## Core Principles\n### I. Test-First\nTDD required.\n');
  fs.writeFileSync(path.join(dir, 'PREMISE.md'), '# Premise\nThis is the premise.\n');
  return dir;
}

function extractDashboardData(htmlPath) {
  const html = fs.readFileSync(htmlPath, 'utf-8');
  const match = html.match(/window\.DASHBOARD_DATA\s*=\s*(\{.+?\});\s*<\/script>/s);
  if (!match) throw new Error('DASHBOARD_DATA not found in HTML');
  const data = JSON.parse(match[1]);
  // Remove fields that will differ between runs
  delete data.meta.generatedAt;
  delete data.meta.projectPath;
  return data;
}

describe('Bundle correctness (TS-004, FR-006a)', () => {
  beforeAll(() => {
    // Build bundle if it doesn't exist (CI doesn't run build step)
    if (!fs.existsSync(BUNDLED_PATH)) {
      const buildScript = path.join(__dirname, '../../.claude/skills/iikit-core/scripts/dashboard', 'build', 'bundle-generator.js');
      const result = spawnSync(process.execPath, [buildScript], {
        encoding: 'utf-8', timeout: 30000, cwd: path.join(__dirname, '..')
      });
      if (result.status !== 0) {
        throw new Error(`Build failed: ${result.stderr}`);
      }
    }
  });

  test('bundled and modular generator produce identical DASHBOARD_DATA', () => {
    expect(fs.existsSync(BUNDLED_PATH)).toBe(true);

    const tmpDir1 = createTestProject();
    const tmpDir2 = createTestProject();

    try {
      // Run modular version
      const modResult = spawnSync(process.execPath, [MODULAR_PATH, tmpDir1], {
        encoding: 'utf-8', timeout: 15000
      });
      expect(modResult.status).toBe(0);

      // Run bundled version
      const bundleResult = spawnSync(process.execPath, [BUNDLED_PATH, tmpDir2], {
        encoding: 'utf-8', timeout: 15000
      });
      expect(bundleResult.status).toBe(0);

      // Compare DASHBOARD_DATA (without timestamps)
      const modularData = extractDashboardData(path.join(tmpDir1, '.specify', 'dashboard.html'));
      const bundledData = extractDashboardData(path.join(tmpDir2, '.specify', 'dashboard.html'));

      const modularHash = crypto.createHash('sha256')
        .update(JSON.stringify(modularData)).digest('hex');
      const bundledHash = crypto.createHash('sha256')
        .update(JSON.stringify(bundledData)).digest('hex');

      expect(bundledHash).toBe(modularHash);
    } finally {
      fs.rmSync(tmpDir1, { recursive: true, force: true });
      fs.rmSync(tmpDir2, { recursive: true, force: true });
    }
  });
});

// --- template.js bundle regression tests ---
// Regression: tessl publish strips .html files from the whitelist, so the bundled
// generator must ship with template.js containing the full HTML as a JS string export.

describe('template.js bundle integrity', () => {
  const DASHBOARD_DIR = path.join(__dirname, '../../.claude/skills/iikit-core/scripts/dashboard');
  const TEMPLATE_JS_PATH = path.join(DASHBOARD_DIR, 'template.js');

  test('template.js exists alongside bundled generator', () => {
    // Regression: without template.js, the generator crashes with ENOENT when
    // public/index.html is stripped by tessl publish
    expect(fs.existsSync(TEMPLATE_JS_PATH)).toBe(true);
  });

  test('template.js exports a string', () => {
    const templateExport = require(TEMPLATE_JS_PATH);
    expect(typeof templateExport).toBe('string');
  });

  test('template.js export starts with DOCTYPE', () => {
    const templateExport = require(TEMPLATE_JS_PATH);
    expect(templateExport.trimStart()).toMatch(/^<!DOCTYPE html>/i);
  });
});
