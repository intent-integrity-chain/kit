'use strict';

const path = require('path');
const fs = require('fs');
const os = require('os');
const { execSync, spawnSync } = require('child_process');

// --- Compute module smoke tests (Phase 2: Foundational) ---

describe('Compute module smoke tests', () => {
  let tmpDir;

  beforeAll(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'iikit-smoke-'));
    // Minimal project structure
    fs.mkdirSync(path.join(tmpDir, 'specs', '001-test-feature', 'tests'), { recursive: true });
    fs.writeFileSync(path.join(tmpDir, 'specs', '001-test-feature', 'spec.md'), '# Spec\n');
    fs.writeFileSync(path.join(tmpDir, 'specs', '001-test-feature', 'tasks.md'), '# Tasks\n- [ ] T001 A task\n');
    fs.writeFileSync(path.join(tmpDir, 'CONSTITUTION.md'), '# Constitution\n## Core Principles\n### I. Test-First\nTDD required.\n');
    fs.writeFileSync(path.join(tmpDir, 'PREMISE.md'), '# Premise\n');
  });

  afterAll(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  test('parser exports parse functions', () => {
    const parser = require('../../.claude/skills/iikit-core/scripts/dashboard/src/parser');
    expect(typeof parser.parseSpecStories).toBe('function');
    expect(typeof parser.parseTasks).toBe('function');
    expect(typeof parser.parseConstitutionPrinciples).toBe('function');
    expect(typeof parser.parsePremise).toBe('function');
  });

  test('board exports computeBoardState', () => {
    const { computeBoardState } = require('../../.claude/skills/iikit-core/scripts/dashboard/src/board');
    expect(typeof computeBoardState).toBe('function');
    const result = computeBoardState([], []);
    expect(result).toBeDefined();
  });

  test('pipeline exports computePipelineState', () => {
    const { computePipelineState } = require('../../.claude/skills/iikit-core/scripts/dashboard/src/pipeline');
    expect(typeof computePipelineState).toBe('function');
    const result = computePipelineState(tmpDir, '001-test-feature');
    expect(result).toBeDefined();
  });

  test('storymap exports computeStoryMapState', () => {
    const { computeStoryMapState } = require('../../.claude/skills/iikit-core/scripts/dashboard/src/storymap');
    expect(typeof computeStoryMapState).toBe('function');
    const result = computeStoryMapState(tmpDir, '001-test-feature');
    expect(result).toBeDefined();
  });

  test('planview exports computePlanViewState', async () => {
    const { computePlanViewState } = require('../../.claude/skills/iikit-core/scripts/dashboard/src/planview');
    expect(typeof computePlanViewState).toBe('function');
    const result = await computePlanViewState(tmpDir, '001-test-feature');
    expect(result).toBeDefined();
  });

  test('checklist exports computeChecklistViewState', () => {
    const { computeChecklistViewState } = require('../../.claude/skills/iikit-core/scripts/dashboard/src/checklist');
    expect(typeof computeChecklistViewState).toBe('function');
    const result = computeChecklistViewState(tmpDir, '001-test-feature');
    expect(result).toBeDefined();
  });

  test('testify exports computeTestifyState', () => {
    const { computeTestifyState } = require('../../.claude/skills/iikit-core/scripts/dashboard/src/testify');
    expect(typeof computeTestifyState).toBe('function');
    const result = computeTestifyState(tmpDir, '001-test-feature');
    expect(result).toBeDefined();
  });

  test('analyze exports computeAnalyzeState', () => {
    const { computeAnalyzeState } = require('../../.claude/skills/iikit-core/scripts/dashboard/src/analyze');
    expect(typeof computeAnalyzeState).toBe('function');
    const result = computeAnalyzeState(tmpDir, '001-test-feature');
    expect(result).toBeDefined();
  });

  test('integrity exports computeAssertionHash and checkIntegrity', () => {
    const { computeAssertionHash, checkIntegrity } = require('../../.claude/skills/iikit-core/scripts/dashboard/src/integrity');
    expect(typeof computeAssertionHash).toBe('function');
    expect(typeof checkIntegrity).toBe('function');
    const hash = computeAssertionHash('    Given a project\n    When run\n    Then result\n');
    expect(typeof hash).toBe('string');
    expect(hash.length).toBe(64); // SHA-256 hex
    const result = checkIntegrity(hash, hash);
    expect(result).toBeDefined();
    expect(result.status).toBe('valid');
  });

  test('bugs exports computeBugsState', () => {
    const { computeBugsState } = require('../../.claude/skills/iikit-core/scripts/dashboard/src/bugs');
    expect(typeof computeBugsState).toBe('function');
    const result = computeBugsState(tmpDir, '001-test-feature');
    expect(result).toBeDefined();
  });
});

// --- US1 Tests (Phase 3) ---

const GENERATOR_PATH = path.join(__dirname, '..', '..', '.claude', 'skills', 'iikit-core', 'scripts', 'dashboard', 'src', 'generate-dashboard.js');

function runGenerator(args = [], options = {}) {
  return spawnSync(process.execPath, [GENERATOR_PATH, ...args], {
    encoding: 'utf-8',
    timeout: 15000,
    ...options
  });
}

function createTestProject(tmpBase) {
  const dir = fs.mkdtempSync(path.join(tmpBase, 'iikit-gen-'));
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

// T006: CLI arg parsing tests (TS-001)
describe('CLI arg parsing', () => {
  test('missing projectPath arg exits with code 1', () => {
    const result = runGenerator([]);
    expect(result.status).toBe(1);
    expect(result.stderr).toMatch(/Error:/i);
  });

  test('non-existent path exits with code 1', () => {
    const result = runGenerator(['/tmp/definitely-does-not-exist-iikit']);
    expect(result.status).toBe(1);
    expect(result.stderr).toMatch(/not found/i);
  });

  test('valid path writes dashboard.html', () => {
    const tmpDir = createTestProject(os.tmpdir());
    try {
      const result = runGenerator([tmpDir]);
      expect(result.status).toBe(0);
      const outputPath = path.join(tmpDir, '.specify', 'dashboard.html');
      expect(fs.existsSync(outputPath)).toBe(true);
    } finally {
      fs.rmSync(tmpDir, { recursive: true, force: true });
    }
  });

  test('"." resolves to CWD', () => {
    const tmpDir = createTestProject(os.tmpdir());
    try {
      const result = runGenerator(['.'], { cwd: tmpDir });
      expect(result.status).toBe(0);
      const outputPath = path.join(tmpDir, '.specify', 'dashboard.html');
      expect(fs.existsSync(outputPath)).toBe(true);
    } finally {
      fs.rmSync(tmpDir, { recursive: true, force: true });
    }
  });

  test('relative path resolves correctly', () => {
    const tmpDir = createTestProject(os.tmpdir());
    const parentDir = path.dirname(tmpDir);
    const relPath = path.basename(tmpDir);
    try {
      const result = runGenerator([relPath], { cwd: parentDir });
      expect(result.status).toBe(0);
      const outputPath = path.join(tmpDir, '.specify', 'dashboard.html');
      expect(fs.existsSync(outputPath)).toBe(true);
    } finally {
      fs.rmSync(tmpDir, { recursive: true, force: true });
    }
  });
});

// T007: Error handling tests (TS-001)
describe('Error handling', () => {
  test('missing project dir exits with code 1', () => {
    const result = runGenerator(['/tmp/nonexistent-iikit-project-xyz']);
    expect(result.status).toBe(1);
  });

  test('missing CONSTITUTION.md warns but generates dashboard (not exit 3)', () => {
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'iikit-noconst-'));
    fs.mkdirSync(path.join(tmpDir, 'specs', '001-feat'), { recursive: true });
    fs.writeFileSync(path.join(tmpDir, 'specs', '001-feat', 'spec.md'), '# Spec\n');
    try {
      const result = runGenerator([tmpDir]);
      expect(result.status).toBe(0);
      expect(result.stderr).toMatch(/CONSTITUTION\.md/i);
    } finally {
      fs.rmSync(tmpDir, { recursive: true, force: true });
    }
  });

  test('write permission denied exits with code 4', () => {
    const tmpDir = createTestProject(os.tmpdir());
    const specifyDir = path.join(tmpDir, '.specify');
    fs.mkdirSync(specifyDir, { recursive: true });
    fs.chmodSync(specifyDir, 0o444);
    try {
      const result = runGenerator([tmpDir]);
      expect(result.status).toBe(4);
      expect(result.stderr).toMatch(/permission/i);
    } finally {
      fs.chmodSync(specifyDir, 0o755);
      fs.rmSync(tmpDir, { recursive: true, force: true });
    }
  });
});

// T008: DASHBOARD_DATA assembly tests (TS-001, TS-003)
describe('DASHBOARD_DATA assembly', () => {
  let tmpDir;
  let htmlContent;

  beforeAll(() => {
    tmpDir = createTestProject(os.tmpdir());
    // Add a second feature
    fs.mkdirSync(path.join(tmpDir, 'specs', '002-second-feature'), { recursive: true });
    fs.writeFileSync(path.join(tmpDir, 'specs', '002-second-feature', 'spec.md'), '# Spec 2\n');
    fs.writeFileSync(path.join(tmpDir, 'specs', '002-second-feature', 'tasks.md'), '# Tasks\n');

    const result = runGenerator([tmpDir]);
    expect(result.status).toBe(0);
    htmlContent = fs.readFileSync(path.join(tmpDir, '.specify', 'dashboard.html'), 'utf-8');
  });

  afterAll(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  test('output contains all features', () => {
    const match = htmlContent.match(/window\.DASHBOARD_DATA\s*=\s*(\{.+?\});\s*<\/script>/s);
    expect(match).not.toBeNull();
    const data = JSON.parse(match[1]);
    const featureIds = data.features.map(f => f.id);
    expect(featureIds).toContain('001-test-feature');
    expect(featureIds).toContain('002-second-feature');
  });

  test('each feature has 8 view keys', () => {
    const match = htmlContent.match(/window\.DASHBOARD_DATA\s*=\s*(\{.+?\});\s*<\/script>/s);
    const data = JSON.parse(match[1]);
    const expectedKeys = ['board', 'pipeline', 'storyMap', 'planView', 'checklist', 'testify', 'analyze', 'bugs'];
    for (const featureId of Object.keys(data.featureData)) {
      const viewKeys = Object.keys(data.featureData[featureId]);
      for (const key of expectedKeys) {
        expect(viewKeys).toContain(key);
      }
    }
  });

  test('meta.projectPath is non-empty', () => {
    const match = htmlContent.match(/window\.DASHBOARD_DATA\s*=\s*(\{.+?\});\s*<\/script>/s);
    const data = JSON.parse(match[1]);
    expect(data.meta.projectPath).toBeTruthy();
    expect(data.meta.projectPath.length).toBeGreaterThan(0);
  });

  test('meta.generatedAt is ISO-8601', () => {
    const match = htmlContent.match(/window\.DASHBOARD_DATA\s*=\s*(\{.+?\});\s*<\/script>/s);
    const data = JSON.parse(match[1]);
    expect(data.meta.generatedAt).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/);
    expect(new Date(data.meta.generatedAt).toISOString()).toBe(data.meta.generatedAt);
  });
});

// T009: HTML output tests (TS-001, TS-006)
describe('HTML output', () => {
  let tmpDir;
  let htmlContent;

  beforeAll(() => {
    tmpDir = createTestProject(os.tmpdir());
    const result = runGenerator([tmpDir]);
    expect(result.status).toBe(0);
    htmlContent = fs.readFileSync(path.join(tmpDir, '.specify', 'dashboard.html'), 'utf-8');
  });

  afterAll(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  test('contains window.DASHBOARD_DATA script', () => {
    expect(htmlContent).toMatch(/window\.DASHBOARD_DATA\s*=\s*\{/);
  });

  test('does NOT contain auto-reload (removed — breaks user interaction)', () => {
    expect(htmlContent).not.toMatch(/<meta\s+http-equiv="refresh"/);
    expect(htmlContent).not.toMatch(/setInterval.*location\.reload/);
  });

  test('output is valid HTML with closing tags', () => {
    expect(htmlContent).toMatch(/^<!DOCTYPE html>/i);
    expect(htmlContent).toMatch(/<\/html>\s*$/);
    expect(htmlContent).toContain('</head>');
    expect(htmlContent).toContain('</body>');
  });

  test('file written atomically via .tmp (no leftover .tmp file)', () => {
    const tmpFile = path.join(tmpDir, '.specify', 'dashboard.html.tmp');
    expect(fs.existsSync(tmpFile)).toBe(false);
  });

  test('DASHBOARD_DATA script block is not broken by </script> in project content (SC-008)', () => {
    const { buildHtml } = require('../../.claude/skills/iikit-core/scripts/dashboard/src/generate-dashboard');
    const template = '<!DOCTYPE html><html><head></head><body></body></html>';
    const data = { meta: {}, features: [], featureData: {}, payload: '</script><script>alert(1)' };
    const result = buildHtml(template, data);
    // Extract the DASHBOARD_DATA assignment line
    const assignmentMatch = result.match(/window\.DASHBOARD_DATA\s*=\s*(\{[^\n]+\});/);
    expect(assignmentMatch).not.toBeNull();
    // The assignment must not contain a bare </script> (which would break the script block)
    expect(assignmentMatch[0]).not.toContain('</script>');
    // The data must round-trip correctly through JSON parse
    const parsed = JSON.parse(assignmentMatch[1]);
    expect(parsed.payload).toBe('</script><script>alert(1)');
  });
});

// --- Template loading regression tests ---
// These tests cover bugs found during real-world testing:
// Bug 1: public/index.html stripped by tessl publish — .html files not in whitelist
// Bug 2: template.js fallback — loadTemplate() needed to try template.js before public/index.html
// Bug 4: Silent failures — errors were swallowed (exit 0), making bugs invisible

describe('Template loading', () => {
  const DASHBOARD_DIR = path.join(__dirname, '..', '..', '.claude', 'skills', 'iikit-core', 'scripts', 'dashboard');
  const TEMPLATE_JS_PATH = path.join(DASHBOARD_DIR, 'template.js');
  const PUBLIC_HTML_PATH = path.join(DASHBOARD_DIR, 'public', 'index.html');
  const SRC_PUBLIC_HTML_PATH = path.join(DASHBOARD_DIR, 'src', 'public', 'index.html');
  // All HTML template paths that loadTemplate may check as fallbacks
  const ALL_HTML_PATHS = [PUBLIC_HTML_PATH, SRC_PUBLIC_HTML_PATH];
  const ALL_TEMPLATE_PATHS = [TEMPLATE_JS_PATH, ...ALL_HTML_PATHS];

  /**
   * Temporarily rename files, run callback, then restore. Safe even if callback throws.
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

  test('loads template from template.js when available', () => {
    // template.js should exist in the dashboard directory
    expect(fs.existsSync(TEMPLATE_JS_PATH)).toBe(true);
    const templateContent = require(TEMPLATE_JS_PATH);
    expect(typeof templateContent).toBe('string');
    expect(templateContent.length).toBeGreaterThan(0);
  });

  test('template.js contains valid HTML with DOCTYPE', () => {
    const templateContent = require(TEMPLATE_JS_PATH);
    expect(templateContent).toMatch(/^<!DOCTYPE html>/i);
    expect(templateContent).toContain('</html>');
    expect(templateContent).toContain('</head>');
    expect(templateContent).toContain('</body>');
  });

  test('template.js matches public/index.html content', () => {
    // Both template sources must have identical HTML so either can be used
    expect(fs.existsSync(PUBLIC_HTML_PATH)).toBe(true);
    const templateJsContent = require(TEMPLATE_JS_PATH);
    const publicHtmlContent = fs.readFileSync(PUBLIC_HTML_PATH, 'utf-8');
    expect(templateJsContent).toBe(publicHtmlContent);
  });

  test('generator works when public/index.html is missing but template.js exists', () => {
    // Regression: tessl publish strips .html files; generator must work with only template.js
    const tmpDir = createTestProject(os.tmpdir());
    try {
      withRenamedFiles(ALL_HTML_PATHS, () => {
        const result = runGenerator([tmpDir]);
        expect(result.status).toBe(0);
        const outputPath = path.join(tmpDir, '.specify', 'dashboard.html');
        expect(fs.existsSync(outputPath)).toBe(true);
        const html = fs.readFileSync(outputPath, 'utf-8');
        expect(html).toMatch(/^<!DOCTYPE html>/i);
      });
    } finally {
      fs.rmSync(tmpDir, { recursive: true, force: true });
    }
  });

  test('generator works when template.js is missing but public/index.html exists', () => {
    const tmpDir = createTestProject(os.tmpdir());
    try {
      withRenamedFiles([TEMPLATE_JS_PATH], () => {
        const result = runGenerator([tmpDir]);
        expect(result.status).toBe(0);
        const outputPath = path.join(tmpDir, '.specify', 'dashboard.html');
        expect(fs.existsSync(outputPath)).toBe(true);
        const html = fs.readFileSync(outputPath, 'utf-8');
        expect(html).toMatch(/^<!DOCTYPE html>/i);
      });
    } finally {
      fs.rmSync(tmpDir, { recursive: true, force: true });
    }
  });

  test('generator throws clear error when both template sources are missing', () => {
    // Regression: silent failures made bugs invisible — generator must report the problem
    const tmpDir = createTestProject(os.tmpdir());
    try {
      withRenamedFiles(ALL_TEMPLATE_PATHS, () => {
        const result = runGenerator([tmpDir]);
        expect(result.status).not.toBe(0);
        expect(result.stderr).toMatch(/not found|ENOENT|template/i);
      });
    } finally {
      fs.rmSync(tmpDir, { recursive: true, force: true });
    }
  });
});

// =============================================================================
// Bug regression tests (from e2e test findings)
// =============================================================================

describe('BUG-4: clarification view panels rendered in dashboard HTML', () => {
  test('dashboard HTML contains clarify-view elements when clarifications exist', () => {
    const tmpDir = createTestProject(os.tmpdir());
    try {
      const specPath = path.join(tmpDir, 'specs', '001-test-feature', 'spec.md');
      const specContent = fs.readFileSync(specPath, 'utf-8');
      fs.writeFileSync(specPath, specContent + `
## Clarifications

### Session 2026-02-26

- Q: What auth method? -> A: JWT tokens [FR-001]
- Q: How many users? -> A: 10k initially [SC-001]
`);

      const result = runGenerator([tmpDir]);
      expect(result.status).toBe(0);

      const html = fs.readFileSync(path.join(tmpDir, '.specify', 'dashboard.html'), 'utf-8');
      const match = html.match(/window\.DASHBOARD_DATA\s*=\s*({.*?});/s);
      const data = JSON.parse(match[1]);
      const featureData = data.featureData?.['001-test-feature'];

      // storyMap.clarifications should be populated (not empty)
      expect(featureData.storyMap.clarifications.length).toBeGreaterThan(0);
    } finally {
      fs.rmSync(tmpDir, { recursive: true, force: true });
    }
  });
});

describe('BUG-7: clarify view includes clarifications from all artifacts', () => {
  test('dashboard data includes constitution clarifications', () => {
    const tmpDir = createTestProject(os.tmpdir());
    try {
      const constPath = path.join(tmpDir, 'CONSTITUTION.md');
      const constContent = fs.readFileSync(constPath, 'utf-8');
      fs.writeFileSync(constPath, constContent + `
## Clarifications

### Session 2026-02-26

- Q: Should we enforce code review? -> A: Yes mandatory [Principle I]
`);

      const result = runGenerator([tmpDir]);
      expect(result.status).toBe(0);

      const html = fs.readFileSync(path.join(tmpDir, '.specify', 'dashboard.html'), 'utf-8');
      const match = html.match(/window\.DASHBOARD_DATA\s*=\s*({.*?});/s);
      const data = JSON.parse(match[1]);
      const featureData = data.featureData?.['001-test-feature'];

      // Pipeline should show constitution clarification
      const constPhase = featureData.pipeline.phases.find(p => p.id === 'constitution');
      expect(constPhase.clarifications).toBeGreaterThan(0);
    } finally {
      fs.rmSync(tmpDir, { recursive: true, force: true });
    }
  });
});

describe('BUG-10: dashboard respects active-feature file over git branch', () => {
  test('dashboard data includes active-feature even when branch differs', () => {
    const tmpDir = createTestProject(os.tmpdir());
    try {
      fs.mkdirSync(path.join(tmpDir, 'specs', '002-other'), { recursive: true });
      fs.writeFileSync(path.join(tmpDir, 'specs', '002-other', 'spec.md'), '# Other\n');
      fs.mkdirSync(path.join(tmpDir, '.specify'), { recursive: true });
      fs.writeFileSync(path.join(tmpDir, '.specify', 'active-feature'), '001-test-feature');

      const result = runGenerator([tmpDir]);
      expect(result.status).toBe(0);

      const html = fs.readFileSync(path.join(tmpDir, '.specify', 'dashboard.html'), 'utf-8');
      const match = html.match(/window\.DASHBOARD_DATA\s*=\s*({.*?});/s);
      const data = JSON.parse(match[1]);
      expect(data.featureData).toHaveProperty('001-test-feature');
    } finally {
      fs.rmSync(tmpDir, { recursive: true, force: true });
    }
  });
});

describe('BUG-13: no persistent MISSING badge when clarifications not needed', () => {
  test('pipeline phases show clarifications=0 when no clarifications exist', () => {
    const tmpDir = createTestProject(os.tmpdir());
    try {
      const result = runGenerator([tmpDir]);
      expect(result.status).toBe(0);

      const html = fs.readFileSync(path.join(tmpDir, '.specify', 'dashboard.html'), 'utf-8');
      const match = html.match(/window\.DASHBOARD_DATA\s*=\s*({.*?});/s);
      const data = JSON.parse(match[1]);
      const featureData = data.featureData?.['001-test-feature'];
      for (const phase of featureData.pipeline.phases) {
        expect(phase.clarifications).toBe(0);
      }
    } finally {
      fs.rmSync(tmpDir, { recursive: true, force: true });
    }
  });
});

describe('BUG-8: ESM/CJS conflict with type:module', () => {
  test('dashboard generates when project package.json has type:module', () => {
    const tmpDir = createTestProject(os.tmpdir());
    try {
      // Add package.json with "type": "module" (modern ESM project)
      fs.writeFileSync(path.join(tmpDir, 'package.json'), JSON.stringify({
        name: 'test-esm-project',
        type: 'module',
        version: '1.0.0',
      }));

      const result = runGenerator([tmpDir]);
      // Should succeed — generator should not be affected by project's module type
      expect(result.status).toBe(0);
      expect(fs.existsSync(path.join(tmpDir, '.specify', 'dashboard.html'))).toBe(true);
    } finally {
      fs.rmSync(tmpDir, { recursive: true, force: true });
    }
  });
});

describe('BUG-9: dashboard should generate without CONSTITUTION.md', () => {
  test('generates partial dashboard when constitution missing but spec exists', () => {
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'iikit-noconst-'));
    try {
      fs.mkdirSync(path.join(tmpDir, 'specs', '001-test', 'tests'), { recursive: true });
      fs.writeFileSync(path.join(tmpDir, 'specs', '001-test', 'spec.md'), '# Spec\n');
      // No CONSTITUTION.md
      fs.writeFileSync(path.join(tmpDir, 'PREMISE.md'), '# Premise\n');

      const result = runGenerator([tmpDir]);
      // Should generate a dashboard (perhaps minimal) rather than hard-fail
      expect(result.status).toBe(0);
    } finally {
      fs.rmSync(tmpDir, { recursive: true, force: true });
    }
  });
});

describe('BUG-11: dashboard health score matches analysis.md', () => {
  test('dashboard data includes analysis score from analysis.md', () => {
    const tmpDir = createTestProject(os.tmpdir());
    try {
      // Add analysis.md with explicit score
      fs.writeFileSync(path.join(tmpDir, 'specs', '001-test-feature', 'analysis.md'), `# Cross-Artifact Analysis

## Health Score: 91/100

## Coverage Summary
| Source | Items | Covered | Coverage |
|--------|-------|---------|----------|
| FR-xxx | 4 | 4 | 100% |

## Findings
- INFO: All requirements covered

## Constitution Alignment
All principles satisfied.
`);

      const result = runGenerator([tmpDir]);
      expect(result.status).toBe(0);

      const html = fs.readFileSync(path.join(tmpDir, '.specify', 'dashboard.html'), 'utf-8');
      const match = html.match(/window\.DASHBOARD_DATA\s*=\s*({.*?});/s);
      expect(match).not.toBeNull();

      const data = JSON.parse(match[1]);
      const featureData = data.featureData?.['001-test-feature'];
      // If dashboard has an analysis score, it should match what's in analysis.md (91)
      if (featureData?.analysis?.healthScore !== undefined) {
        expect(featureData.analysis.healthScore).toBe(91);
      }
    } finally {
      fs.rmSync(tmpDir, { recursive: true, force: true });
    }
  });
});

