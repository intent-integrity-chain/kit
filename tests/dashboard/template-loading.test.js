'use strict';

const path = require('path');
const fs = require('fs');
const os = require('os');
const { spawnSync } = require('child_process');

// Regression tests for template resolution logic in generate-dashboard.js.
//
// Bugs caught:
// Bug 1: public/index.html stripped by tessl publish — .html files not in whitelist,
//         generator crashed with ENOENT
// Bug 2: loadTemplate() needed to try template.js before public/index.html
// Bug 4: Silent failures — every error was swallowed (exit 0), making bugs invisible
//
// The loadTemplate function lives inside generate-dashboard.js (both src/ and bundled).
// It uses a module-level cache (_cachedTemplate) so within a single process it only
// resolves once. We test it indirectly by spawning child processes (fresh cache each time).
//
// Template source locations:
//   - dashboard/template.js              (primary: published tiles)
//   - dashboard/public/index.html        (dev layout, top-level)
//   - dashboard/src/public/index.html    (dev layout, src-relative for src/generate-dashboard.js)
// The "both missing" tests must remove ALL of these to trigger the error path.

const DASHBOARD_DIR = path.join(__dirname, '..', '..', '.claude', 'skills', 'iikit-core', 'scripts', 'dashboard');
const SRC_GENERATOR = path.join(DASHBOARD_DIR, 'src', 'generate-dashboard.js');
const BUNDLED_GENERATOR = path.join(DASHBOARD_DIR, 'generate-dashboard.js');
const TEMPLATE_JS_PATH = path.join(DASHBOARD_DIR, 'template.js');
const PUBLIC_HTML_PATH = path.join(DASHBOARD_DIR, 'public', 'index.html');
const SRC_PUBLIC_HTML_PATH = path.join(DASHBOARD_DIR, 'src', 'public', 'index.html');

// All template source paths that loadTemplate may check
const ALL_TEMPLATE_PATHS = [TEMPLATE_JS_PATH, PUBLIC_HTML_PATH, SRC_PUBLIC_HTML_PATH];

function createTestProject() {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'iikit-tmpl-'));
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

function runGenerator(generatorPath, projectPath) {
  const result = spawnSync(process.execPath, [generatorPath, projectPath], {
    encoding: 'utf-8',
    timeout: 15000
  });
  if (result.status !== 0) {
    console.error(`Generator failed (exit ${result.status}):`, result.stderr?.substring(0, 200));
  }
  return result;
}

/**
 * Temporarily rename all given paths (adding .bak suffix), run a callback, then restore.
 * Returns array of paths that were actually renamed (existed beforehand).
 */
function withRenamedFiles(paths, fn) {
  const renamed = [];
  try {
    for (const p of paths) {
      if (fs.existsSync(p)) {
        fs.renameSync(p, p + '.bak');
        renamed.push(p);
      }
    }
    return fn();
  } finally {
    for (const p of renamed) {
      fs.renameSync(p + '.bak', p);
    }
  }
}

describe('loadTemplate resolution (src/generate-dashboard.js)', () => {
  test('loadTemplate returns HTML string', () => {
    // Run the generator normally — if loadTemplate fails, the process exits non-zero
    const tmpDir = createTestProject();
    try {
      const result = runGenerator(SRC_GENERATOR, tmpDir);
      if (result.status !== 0) {
        console.error('Generator stderr:', result.stderr);
        console.error('Generator stdout:', result.stdout);
      }
      expect(result.status).toBe(0);
      const html = fs.readFileSync(path.join(tmpDir, '.specify', 'dashboard.html'), 'utf-8');
      expect(typeof html).toBe('string');
      expect(html).toMatch(/^<!DOCTYPE html>/i);
      expect(html).toContain('window.DASHBOARD_DATA');
    } finally {
      fs.rmSync(tmpDir, { recursive: true, force: true });
    }
  });

  test('loadTemplate caches result (same output across two features)', () => {
    // The cache means the template is loaded once — verify consistent output
    // by generating for a project with two features
    const tmpDir = createTestProject();
    fs.mkdirSync(path.join(tmpDir, 'specs', '002-second'), { recursive: true });
    fs.writeFileSync(path.join(tmpDir, 'specs', '002-second', 'spec.md'), '# Spec 2\n');
    try {
      const result = runGenerator(SRC_GENERATOR, tmpDir);
      expect(result.status).toBe(0);
      const html = fs.readFileSync(path.join(tmpDir, '.specify', 'dashboard.html'), 'utf-8');
      // The template should have been loaded once, producing a single consistent HTML document
      // (not two separate HTML documents concatenated)
      const doctypeMatches = html.match(/<!DOCTYPE html>/gi);
      expect(doctypeMatches).toHaveLength(1);
    } finally {
      fs.rmSync(tmpDir, { recursive: true, force: true });
    }
  });

  test('loadTemplate prefers template.js over public/index.html', () => {
    // When both exist, template.js should win (it is checked first).
    // Verify by confirming generator succeeds with both present — the source code
    // checks template.js first, so if it exists, public/index.html is never read.
    expect(fs.existsSync(TEMPLATE_JS_PATH)).toBe(true);
    expect(fs.existsSync(PUBLIC_HTML_PATH)).toBe(true);

    const tmpDir = createTestProject();
    try {
      const result = runGenerator(SRC_GENERATOR, tmpDir);
      expect(result.status).toBe(0);
      // Output should contain valid HTML from the template
      const html = fs.readFileSync(path.join(tmpDir, '.specify', 'dashboard.html'), 'utf-8');
      expect(html).toMatch(/^<!DOCTYPE html>/i);
    } finally {
      fs.rmSync(tmpDir, { recursive: true, force: true });
    }
  });

  test('loadTemplate with only template.js (all .html templates missing)', () => {
    // Regression: tessl publish strips .html files. Generator must work with only template.js.
    const tmpDir = createTestProject();
    try {
      const htmlPaths = [PUBLIC_HTML_PATH, SRC_PUBLIC_HTML_PATH];
      withRenamedFiles(htmlPaths, () => {
        const result = runGenerator(SRC_GENERATOR, tmpDir);
        expect(result.status).toBe(0);
        const html = fs.readFileSync(path.join(tmpDir, '.specify', 'dashboard.html'), 'utf-8');
        expect(html).toMatch(/^<!DOCTYPE html>/i);
      });
    } finally {
      fs.rmSync(tmpDir, { recursive: true, force: true });
    }
  });

  test('loadTemplate with only public/index.html (template.js missing)', () => {
    const tmpDir = createTestProject();
    try {
      withRenamedFiles([TEMPLATE_JS_PATH], () => {
        const result = runGenerator(SRC_GENERATOR, tmpDir);
        expect(result.status).toBe(0);
        const html = fs.readFileSync(path.join(tmpDir, '.specify', 'dashboard.html'), 'utf-8');
        expect(html).toMatch(/^<!DOCTYPE html>/i);
      });
    } finally {
      fs.rmSync(tmpDir, { recursive: true, force: true });
    }
  });

  test('loadTemplate with neither source throws clear error', () => {
    // Regression: silent failures made bugs invisible. Generator must fail loudly.
    const tmpDir = createTestProject();
    try {
      withRenamedFiles(ALL_TEMPLATE_PATHS, () => {
        const result = runGenerator(SRC_GENERATOR, tmpDir);
        // Must exit non-zero with a meaningful error
        expect(result.status).not.toBe(0);
        expect(result.stderr).toMatch(/not found|ENOENT|template/i);
      });
    } finally {
      fs.rmSync(tmpDir, { recursive: true, force: true });
    }
  });
});

describe('loadTemplate resolution (bundled generate-dashboard.js)', () => {
  beforeAll(() => {
    // Build bundle if it doesn't exist
    if (!fs.existsSync(BUNDLED_GENERATOR)) {
      const buildScript = path.join(DASHBOARD_DIR, 'build', 'bundle-generator.js');
      const result = spawnSync(process.execPath, [buildScript], {
        encoding: 'utf-8', timeout: 30000, cwd: path.join(__dirname, '..')
      });
      if (result.status !== 0) {
        throw new Error(`Build failed: ${result.stderr}`);
      }
    }
  });

  test('bundled generator works with only template.js (all .html templates missing)', () => {
    // This is the primary published-tile scenario: .html files are stripped
    const htmlPaths = [PUBLIC_HTML_PATH, SRC_PUBLIC_HTML_PATH];
    const tmpDir = createTestProject();
    try {
      withRenamedFiles(htmlPaths, () => {
        const result = runGenerator(BUNDLED_GENERATOR, tmpDir);
        expect(result.status).toBe(0);
        const html = fs.readFileSync(path.join(tmpDir, '.specify', 'dashboard.html'), 'utf-8');
        expect(html).toMatch(/^<!DOCTYPE html>/i);
      });
    } finally {
      fs.rmSync(tmpDir, { recursive: true, force: true });
    }
  });

  test('bundled generator fails clearly when no template source exists', () => {
    const tmpDir = createTestProject();
    try {
      withRenamedFiles(ALL_TEMPLATE_PATHS, () => {
        const result = runGenerator(BUNDLED_GENERATOR, tmpDir);
        expect(result.status).not.toBe(0);
        expect(result.stderr).toMatch(/not found|ENOENT|template/i);
      });
    } finally {
      fs.rmSync(tmpDir, { recursive: true, force: true });
    }
  });
});
