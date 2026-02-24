'use strict';

const path = require('path');
const fs = require('fs');
const os = require('os');
const { execSync } = require('child_process');

// Regression tests for prepare-tile.sh self-containment.
//
// Bugs caught:
// Bug 1: public/index.html stripped by tessl publish — .html not in whitelist
// Bug 3: generate-dashboard-safe.sh path resolution — ../dashboard/ doesn't resolve
//         from self-contained skill dirs, needed candidate path search
// Bug 4: Silent failures — every error was swallowed (exit 0), making bugs invisible
//
// These tests copy the tile to a temp directory, run prepare-tile.sh, and verify
// that the self-contained skills have the correct files and references.

const SKILLS_DIR = path.join(__dirname, '..', '..', '.claude', 'skills');
const PREPARE_TILE = path.join(__dirname, '..', 'prepare-tile.sh');

function copySkillsToTemp() {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'iikit-self-'));
  // Copy all iikit-* directories to temp
  const entries = fs.readdirSync(SKILLS_DIR, { withFileTypes: true });
  for (const entry of entries) {
    if (entry.isDirectory() && entry.name.startsWith('iikit-')) {
      const src = path.join(SKILLS_DIR, entry.name);
      const dst = path.join(tmpDir, entry.name);
      execSync(`cp -R "${src}" "${dst}"`, { encoding: 'utf-8' });
    }
  }
  return tmpDir;
}

function runPrepareTile(skillsDir) {
  return execSync(`bash "${PREPARE_TILE}" "${skillsDir}"`, {
    encoding: 'utf-8',
    timeout: 30000
  });
}

// Skills that reference check-prerequisites in SKILL.md (and thus get generate-dashboard-safe)
function getSkillsWithCheckPrerequisites(skillsDir) {
  const skills = [];
  const entries = fs.readdirSync(skillsDir, { withFileTypes: true });
  for (const entry of entries) {
    if (!entry.isDirectory() || !entry.name.startsWith('iikit-') || entry.name === 'iikit-core') continue;
    const skillMd = path.join(skillsDir, entry.name, 'SKILL.md');
    if (!fs.existsSync(skillMd)) continue;
    const content = fs.readFileSync(skillMd, 'utf-8');
    if (content.includes('check-prerequisites')) {
      skills.push(entry.name);
    }
  }
  return skills;
}

// Skills that reference generate-dashboard-safe in SKILL.md
function getSkillsWithDashboardSafe(skillsDir) {
  const skills = [];
  const entries = fs.readdirSync(skillsDir, { withFileTypes: true });
  for (const entry of entries) {
    if (!entry.isDirectory() || !entry.name.startsWith('iikit-') || entry.name === 'iikit-core') continue;
    const skillMd = path.join(skillsDir, entry.name, 'SKILL.md');
    if (!fs.existsSync(skillMd)) continue;
    const content = fs.readFileSync(skillMd, 'utf-8');
    if (content.includes('generate-dashboard-safe')) {
      skills.push(entry.name);
    }
  }
  return skills;
}

describe('prepare-tile.sh self-containment', () => {
  let tmpDir;

  beforeAll(() => {
    tmpDir = copySkillsToTemp();
    // Remember which skills had check-prerequisites BEFORE prepare runs
    // (prepare rewrites paths, so we check originals)
    runPrepareTile(tmpDir);
  });

  afterAll(() => {
    if (tmpDir) {
      fs.rmSync(tmpDir, { recursive: true, force: true });
    }
  });

  test('prepare-tile.sh copies dashboard/ to each skill that needs it', () => {
    // After prepare, skills with generate-dashboard-safe.sh should have a dashboard/ directory.
    // We check all non-core skills that got generate-dashboard-safe.sh.
    const entries = fs.readdirSync(tmpDir, { withFileTypes: true });
    let foundAtLeastOne = false;
    for (const entry of entries) {
      if (!entry.isDirectory() || entry.name === 'iikit-core') continue;
      const dashSafe = path.join(tmpDir, entry.name, 'scripts', 'bash', 'generate-dashboard-safe.sh');
      if (fs.existsSync(dashSafe)) {
        foundAtLeastOne = true;
        const dashboardDir = path.join(tmpDir, entry.name, 'scripts', 'dashboard');
        expect(fs.existsSync(dashboardDir)).toBe(true);
      }
    }
    // Ensure we actually tested at least one skill
    expect(foundAtLeastOne).toBe(true);
  });

  test('each skill with check-prerequisites gets generate-dashboard-safe.sh', () => {
    // Transitive dep: check-prerequisites.sh calls generate-dashboard-safe.sh at runtime
    const entries = fs.readdirSync(tmpDir, { withFileTypes: true });
    let foundAtLeastOne = false;
    for (const entry of entries) {
      if (!entry.isDirectory() || entry.name === 'iikit-core') continue;
      const checkPrereq = path.join(tmpDir, entry.name, 'scripts', 'bash', 'check-prerequisites.sh');
      if (fs.existsSync(checkPrereq)) {
        foundAtLeastOne = true;
        const dashSafe = path.join(tmpDir, entry.name, 'scripts', 'bash', 'generate-dashboard-safe.sh');
        expect(fs.existsSync(dashSafe)).toBe(true);
      }
    }
    expect(foundAtLeastOne).toBe(true);
  });

  test('each skill with generate-dashboard-safe.sh gets dashboard/ directory', () => {
    // Transitive dep: generate-dashboard-safe.sh looks for ../dashboard/src/generate-dashboard.js
    const entries = fs.readdirSync(tmpDir, { withFileTypes: true });
    let foundAtLeastOne = false;
    for (const entry of entries) {
      if (!entry.isDirectory() || entry.name === 'iikit-core') continue;
      const dashSafe = path.join(tmpDir, entry.name, 'scripts', 'bash', 'generate-dashboard-safe.sh');
      if (fs.existsSync(dashSafe)) {
        foundAtLeastOne = true;
        const dashboardDir = path.join(tmpDir, entry.name, 'scripts', 'dashboard');
        expect(fs.existsSync(dashboardDir)).toBe(true);
      }
    }
    expect(foundAtLeastOne).toBe(true);
  });

  test('dashboard/ copy includes template.js', () => {
    // Regression: without template.js, the generator crashes when .html files are stripped.
    // The template.js file must be present in every self-contained dashboard/ copy.
    const entries = fs.readdirSync(tmpDir, { withFileTypes: true });
    let foundAtLeastOne = false;
    for (const entry of entries) {
      if (!entry.isDirectory() || entry.name === 'iikit-core') continue;
      const dashboardDir = path.join(tmpDir, entry.name, 'scripts', 'dashboard');
      if (fs.existsSync(dashboardDir)) {
        foundAtLeastOne = true;
        const templateJs = path.join(dashboardDir, 'template.js');
        expect(fs.existsSync(templateJs)).toBe(true);
      }
    }
    expect(foundAtLeastOne).toBe(true);
  });

  test('dashboard/ copy includes src/generate-dashboard.js', () => {
    // The source generator must be present for the dashboard to work
    const entries = fs.readdirSync(tmpDir, { withFileTypes: true });
    let foundAtLeastOne = false;
    for (const entry of entries) {
      if (!entry.isDirectory() || entry.name === 'iikit-core') continue;
      const dashboardDir = path.join(tmpDir, entry.name, 'scripts', 'dashboard');
      if (fs.existsSync(dashboardDir)) {
        foundAtLeastOne = true;
        const generator = path.join(dashboardDir, 'src', 'generate-dashboard.js');
        expect(fs.existsSync(generator)).toBe(true);
      }
    }
    expect(foundAtLeastOne).toBe(true);
  });

  test('generate-dashboard-safe.sh references in non-core skills are updated', () => {
    // Bug 3 regression: after self-containment, generate-dashboard-safe.sh should
    // have the candidate path search that finds ../dashboard/ relative to its own location.
    // Verify the script contains the CANDIDATE_DIRS array that handles both layouts.
    const entries = fs.readdirSync(tmpDir, { withFileTypes: true });
    let foundAtLeastOne = false;
    for (const entry of entries) {
      if (!entry.isDirectory() || entry.name === 'iikit-core') continue;
      const dashSafe = path.join(tmpDir, entry.name, 'scripts', 'bash', 'generate-dashboard-safe.sh');
      if (!fs.existsSync(dashSafe)) continue;
      foundAtLeastOne = true;
      const content = fs.readFileSync(dashSafe, 'utf-8');
      // The script must use candidate path search (not hardcoded ../dashboard/ only)
      expect(content).toContain('CANDIDATE_DIRS');
      // It must include the sibling-directory candidate that works in self-contained layout
      expect(content).toMatch(/\$SCRIPT_DIR\/\.\.\/dashboard/);
      // It must include the iikit-core fallback for dev layout
      expect(content).toMatch(/iikit-core\/scripts\/dashboard/);
    }
    expect(foundAtLeastOne).toBe(true);
  });
});

describe('generate-dashboard-safe.sh error behavior', () => {
  test('script exits 0 for non-fatal missing prerequisites (by design)', () => {
    // generate-dashboard-safe.sh is designed to be safe — it exits 0 when node is missing,
    // generator not found, or CONSTITUTION.md not present. This is intentional because
    // it runs as a side-effect of other skills that should not fail just because the
    // dashboard cannot be generated.
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'iikit-safe-'));
    const scriptPath = path.join(SKILLS_DIR, 'iikit-core', 'scripts', 'bash', 'generate-dashboard-safe.sh');
    try {
      // Run without CONSTITUTION.md — should exit 0 (safe failure)
      const result = execSync(`bash "${scriptPath}" "${tmpDir}" 2>&1; echo "EXIT:$?"`, {
        encoding: 'utf-8',
        timeout: 10000
      });
      expect(result).toContain('EXIT:0');
    } finally {
      fs.rmSync(tmpDir, { recursive: true, force: true });
    }
  });

  test('script logs generator errors to dashboard.log instead of suppressing', () => {
    // The generate-dashboard-safe.sh logs errors to .specify/dashboard.log
    // instead of swallowing them with 2>/dev/null.
    const scriptPath = path.join(SKILLS_DIR, 'iikit-core', 'scripts', 'bash', 'generate-dashboard-safe.sh');
    const content = fs.readFileSync(scriptPath, 'utf-8');
    expect(content).toContain('dashboard.log');
    expect(content).not.toContain('2>/dev/null');
  });

  test('generate-dashboard.js (the generator) does NOT silently succeed on errors', () => {
    // Regression: silent failures made bugs invisible.
    // The generator itself (not the safe wrapper) must exit non-zero on real errors.
    const { spawnSync } = require('child_process');
    const generatorPath = path.join(SKILLS_DIR, 'iikit-core', 'scripts', 'dashboard', 'src', 'generate-dashboard.js');

    // Missing project path — must exit 1, not 0
    const result1 = spawnSync(process.execPath, [generatorPath], {
      encoding: 'utf-8', timeout: 10000
    });
    expect(result1.status).toBe(1);
    expect(result1.stderr).toMatch(/Error:/i);

    // Non-existent path — must exit 1, not 0
    const result2 = spawnSync(process.execPath, [generatorPath, '/tmp/nonexistent-iikit-xyz'], {
      encoding: 'utf-8', timeout: 10000
    });
    expect(result2.status).toBe(1);
    expect(result2.stderr).toMatch(/not found/i);
  });
});
