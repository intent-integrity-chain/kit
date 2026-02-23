'use strict';

const path = require('path');
const fs = require('fs');
const os = require('os');

// === 009-bugs-tab: computeBugsState tests (T003) ===
// TS-036, TS-037, TS-038, TS-039, TS-040

describe('computeBugsState', () => {
  let tmpDir;

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'bugs-test-'));
    fs.mkdirSync(path.join(tmpDir, 'specs', 'test-feature'), { recursive: true });
  });

  afterEach(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  function writeFeatureFiles(bugsMd, tasksMd) {
    const featureDir = path.join(tmpDir, 'specs', 'test-feature');
    if (bugsMd !== null) {
      fs.writeFileSync(path.join(featureDir, 'bugs.md'), bugsMd);
    }
    if (tasksMd !== null) {
      fs.writeFileSync(path.join(featureDir, 'tasks.md'), tasksMd);
    }
  }

  const { computeBugsState } = require('../../.claude/skills/iikit-core/scripts/dashboard/src/bugs');

  // TS-036: BugsState summary.open counts only non-fixed bugs
  test('summary.open counts only non-fixed bugs', () => {
    writeFeatureFiles(`# Bug Reports

## BUG-001

**Severity**: critical
**Status**: reported
**Description**: Bug one

---

## BUG-002

**Severity**: medium
**Status**: fixed
**Description**: Bug two

---

## BUG-003

**Severity**: low
**Status**: reported
**Description**: Bug three
`, '# Tasks\n');

    const state = computeBugsState(tmpDir, 'test-feature');
    expect(state.summary.open).toBe(2);
    expect(state.summary.fixed).toBe(1);
    expect(state.summary.total).toBe(3);
  });

  // TS-037: highestOpenSeverity returns highest among open bugs only
  test('highestOpenSeverity returns highest among open bugs only', () => {
    writeFeatureFiles(`## BUG-001

**Severity**: critical
**Status**: fixed
**Description**: Fixed critical

---

## BUG-002

**Severity**: low
**Status**: reported
**Description**: Open low
`, '# Tasks\n');

    const state = computeBugsState(tmpDir, 'test-feature');
    expect(state.summary.highestOpenSeverity).toBe('low');
  });

  // TS-038: bySeverity counts only open bugs
  test('bySeverity counts only open bugs', () => {
    writeFeatureFiles(`## BUG-001

**Severity**: critical
**Status**: reported
**Description**: Open critical

---

## BUG-002

**Severity**: critical
**Status**: fixed
**Description**: Fixed critical

---

## BUG-003

**Severity**: medium
**Status**: reported
**Description**: Open medium
`, '# Tasks\n');

    const state = computeBugsState(tmpDir, 'test-feature');
    expect(state.summary.bySeverity).toEqual({ critical: 1, high: 0, medium: 1, low: 0 });
  });

  // TS-039: Severity hierarchy ordering is critical > high > medium > low
  test('severity hierarchy: critical > high > medium > low', () => {
    writeFeatureFiles(`## BUG-001

**Severity**: low
**Status**: reported
**Description**: Low bug

---

## BUG-002

**Severity**: medium
**Status**: reported
**Description**: Medium bug

---

## BUG-003

**Severity**: high
**Status**: reported
**Description**: High bug
`, '# Tasks\n');

    const state = computeBugsState(tmpDir, 'test-feature');
    expect(state.summary.highestOpenSeverity).toBe('high');
  });

  // TS-040: highestOpenSeverity is null when no open bugs
  test('highestOpenSeverity is null when all bugs are fixed', () => {
    writeFeatureFiles(`## BUG-001

**Severity**: critical
**Status**: fixed
**Description**: Fixed bug

---

## BUG-002

**Severity**: high
**Status**: fixed
**Description**: Also fixed
`, '# Tasks\n');

    const state = computeBugsState(tmpDir, 'test-feature');
    expect(state.summary.highestOpenSeverity).toBeNull();
  });

  test('exists is false when no bugs.md', () => {
    writeFeatureFiles(null, '# Tasks\n');
    const state = computeBugsState(tmpDir, 'test-feature');
    expect(state.exists).toBe(false);
    expect(state.bugs).toEqual([]);
    expect(state.summary.total).toBe(0);
    expect(state.summary.open).toBe(0);
    expect(state.summary.fixed).toBe(0);
    expect(state.summary.highestOpenSeverity).toBeNull();
    expect(state.summary.bySeverity).toEqual({ critical: 0, high: 0, medium: 0, low: 0 });
  });

  test('cross-references fix tasks with bugs', () => {
    writeFeatureFiles(`## BUG-001

**Severity**: critical
**Status**: reported
**Description**: Login fails
`, `# Tasks

## Bug Fix Tasks

- [ ] T-B001 [BUG-001] Investigate root cause
- [x] T-B002 [BUG-001] Implement fix
- [ ] T-B003 [BUG-001] Write regression test
`);

    const state = computeBugsState(tmpDir, 'test-feature');
    expect(state.bugs).toHaveLength(1);
    expect(state.bugs[0].fixTasks.total).toBe(3);
    expect(state.bugs[0].fixTasks.checked).toBe(1);
    expect(state.bugs[0].fixTasks.tasks).toHaveLength(3);
    expect(state.bugs[0].fixTasks.tasks[0]).toMatchObject({ id: 'T-B001', checked: false });
    expect(state.bugs[0].fixTasks.tasks[1]).toMatchObject({ id: 'T-B002', checked: true });
  });

  test('bugs sorted by severity descending then ID ascending', () => {
    writeFeatureFiles(`## BUG-001

**Severity**: low
**Status**: reported
**Description**: Low bug

---

## BUG-002

**Severity**: critical
**Status**: reported
**Description**: Critical bug

---

## BUG-003

**Severity**: medium
**Status**: reported
**Description**: Medium bug

---

## BUG-004

**Severity**: critical
**Status**: reported
**Description**: Another critical
`, '# Tasks\n');

    const state = computeBugsState(tmpDir, 'test-feature');
    const ids = state.bugs.map(b => b.id);
    expect(ids).toEqual(['BUG-002', 'BUG-004', 'BUG-003', 'BUG-001']);
  });

  test('detects orphaned T-B tasks (no matching bug)', () => {
    writeFeatureFiles(`## BUG-001

**Severity**: medium
**Status**: reported
**Description**: Known bug
`, `# Tasks
- [ ] T-B001 [BUG-001] Fix for known bug
- [ ] T-B002 [BUG-999] Fix for nonexistent bug
`);

    const state = computeBugsState(tmpDir, 'test-feature');
    expect(state.orphanedTasks).toBeDefined();
    expect(state.orphanedTasks).toHaveLength(1);
    expect(state.orphanedTasks[0].id).toBe('T-B002');
    expect(state.orphanedTasks[0].bugTag).toBe('BUG-999');
  });
});

// === 009-bugs-tab: resolveGitHubIssueUrl tests (T004) ===
// TS-041, TS-042

describe('resolveGitHubIssueUrl', () => {
  const { resolveGitHubIssueUrl } = require('../../.claude/skills/iikit-core/scripts/dashboard/src/bugs');

  // TS-041: GitHub issue reference resolved to URL from git remote
  test('resolves #number to full GitHub URL', () => {
    const url = resolveGitHubIssueUrl('#13', 'https://github.com/user/repo.git');
    expect(url).toBe('https://github.com/user/repo/issues/13');
  });

  test('handles remote URL without .git suffix', () => {
    const url = resolveGitHubIssueUrl('#42', 'https://github.com/user/repo');
    expect(url).toBe('https://github.com/user/repo/issues/42');
  });

  // TS-042: GitHub issue reference as plain text when no remote
  test('returns null when no repo URL provided', () => {
    const url = resolveGitHubIssueUrl('#13', null);
    expect(url).toBeNull();
  });

  test('returns null when repo URL is empty', () => {
    const url = resolveGitHubIssueUrl('#13', '');
    expect(url).toBeNull();
  });

  test('returns null when issue ref is null', () => {
    const url = resolveGitHubIssueUrl(null, 'https://github.com/user/repo');
    expect(url).toBeNull();
  });

  test('handles SSH remote URL format', () => {
    const url = resolveGitHubIssueUrl('#5', 'git@github.com:user/repo.git');
    expect(url).toBe('https://github.com/user/repo/issues/5');
  });

  test('returns null when issueRef is "_(none)_"', () => {
    const url = resolveGitHubIssueUrl('_(none)_', 'https://github.com/user/repo');
    expect(url).toBeNull();
  });

  // Exact TS-041 scenario: repoUrl without .git + #13
  test('resolves #13 to full GitHub URL given clean repo URL (TS-041 exact)', () => {
    const url = resolveGitHubIssueUrl('#13', 'https://github.com/user/repo');
    expect(url).toBe('https://github.com/user/repo/issues/13');
  });
});
