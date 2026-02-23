'use strict';

const { computePipelineState } = require('../../.claude/skills/iikit-core/scripts/dashboard/src/pipeline');
const fs = require('fs');
const path = require('path');
const os = require('os');

/**
 * Helper to create a temporary project structure for testing.
 */
function createTempProject() {
  const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'pipeline-test-'));
  return tmpDir;
}

function createFeature(projectPath, featureId, files = {}) {
  const featureDir = path.join(projectPath, 'specs', featureId);
  fs.mkdirSync(featureDir, { recursive: true });

  for (const [filePath, content] of Object.entries(files)) {
    const fullPath = path.join(featureDir, filePath);
    fs.mkdirSync(path.dirname(fullPath), { recursive: true });
    fs.writeFileSync(fullPath, content, 'utf-8');
  }

  return featureDir;
}

function cleanup(dir) {
  fs.rmSync(dir, { recursive: true, force: true });
}

describe('computePipelineState', () => {
  let projectPath;

  beforeEach(() => {
    projectPath = createTempProject();
  });

  afterEach(() => {
    cleanup(projectPath);
  });

  // TS-016: Constitution detection — complete when file exists
  test('Constitution phase is complete when CONSTITUTION.md exists', () => {
    fs.writeFileSync(path.join(projectPath, 'CONSTITUTION.md'), '# Constitution\n## Principles\n');
    createFeature(projectPath, '001-test', { 'spec.md': '# Spec' });

    const result = computePipelineState(projectPath, '001-test');
    const constitution = result.phases.find(p => p.id === 'constitution');

    expect(constitution.status).toBe('complete');
  });

  // TS-017: Constitution detection — not started when file missing
  test('Constitution phase is not_started when CONSTITUTION.md missing', () => {
    createFeature(projectPath, '001-test', { 'spec.md': '# Spec' });

    const result = computePipelineState(projectPath, '001-test');
    const constitution = result.phases.find(p => p.id === 'constitution');

    expect(constitution.status).toBe('not_started');
  });

  // TS-002: Pipeline shows only Spec complete for new feature
  test('only Spec is complete for a new feature with just spec.md', () => {
    createFeature(projectPath, '001-test', { 'spec.md': '# Spec\n## Requirements\n' });

    const result = computePipelineState(projectPath, '001-test');

    expect(result.phases.find(p => p.id === 'spec').status).toBe('complete');
    expect(result.phases.find(p => p.id === 'plan').status).toBe('not_started');
    expect(result.phases.find(p => p.id === 'tasks').status).toBe('not_started');
    expect(result.phases.find(p => p.id === 'implement').status).toBe('not_started');
  });

  // TS-018: Clarify detection — complete when clarifications section exists
  test('Clarify is complete when spec.md has Clarifications section', () => {
    createFeature(projectPath, '001-test', {
      'spec.md': '# Spec\n## Clarifications\n### Session 2026-01-01\n- Q: test -> A: yes\n'
    });

    const result = computePipelineState(projectPath, '001-test');
    expect(result.phases.find(p => p.id === 'clarify').status).toBe('complete');
  });

  // TS-019: Clarify detection — skipped when plan exists without clarifications
  test('Clarify is skipped when plan.md exists but spec.md has no clarifications', () => {
    createFeature(projectPath, '001-test', {
      'spec.md': '# Spec\n## Requirements\n',
      'plan.md': '# Plan\n## Technical Context\n'
    });

    const result = computePipelineState(projectPath, '001-test');
    expect(result.phases.find(p => p.id === 'clarify').status).toBe('skipped');
  });

  // TS-020: Checklist detection — in progress with percentage
  test('Checklist is in_progress with percentage when partially complete', () => {
    createFeature(projectPath, '001-test', {
      'spec.md': '# Spec',
      'checklists/requirements.md': '# Checklist\n- [x] CHK001 Item 1\n',
      'checklists/domain.md': '# Domain\n- [x] CHK002 Item 2\n- [ ] CHK003 Item 3\n- [ ] CHK004 Item 4\n'
    });

    const result = computePipelineState(projectPath, '001-test');
    const checklist = result.phases.find(p => p.id === 'checklist');

    expect(checklist.status).toBe('in_progress');
    expect(checklist.progress).toBe('50%');
  });

  // TS-021: Checklist detection — complete when all 100%
  test('Checklist is complete when all items checked', () => {
    createFeature(projectPath, '001-test', {
      'spec.md': '# Spec',
      'checklists/requirements.md': '# Checklist\n- [x] CHK001 Item 1\n',
      'checklists/domain.md': '# Domain\n- [x] CHK002 Item 2\n'
    });

    const result = computePipelineState(projectPath, '001-test');
    expect(result.phases.find(p => p.id === 'checklist').status).toBe('complete');
  });

  // TS-022: Testify detection — skipped when TDD not required
  test('Testify is skipped when constitution has no TDD requirement and plan exists', () => {
    fs.writeFileSync(path.join(projectPath, 'CONSTITUTION.md'), '# Constitution\n## Principles\nBe nice.\n');
    createFeature(projectPath, '001-test', {
      'spec.md': '# Spec',
      'plan.md': '# Plan'
    });

    const result = computePipelineState(projectPath, '001-test');
    const testify = result.phases.find(p => p.id === 'testify');

    expect(testify.status).toBe('skipped');
    expect(testify.optional).toBe(true);
  });

  // TS-023: Tasks detection — binary complete when file exists
  test('Tasks is complete when tasks.md exists', () => {
    createFeature(projectPath, '001-test', {
      'spec.md': '# Spec',
      'tasks.md': '# Tasks\n- [ ] T001 Do something\n'
    });

    const result = computePipelineState(projectPath, '001-test');
    expect(result.phases.find(p => p.id === 'tasks').status).toBe('complete');
    expect(result.phases.find(p => p.id === 'tasks').progress).toBeNull();
  });

  // TS-024: Analyze detection — not started when no analysis.md
  test('Analyze is not_started when analysis.md does not exist', () => {
    createFeature(projectPath, '001-test', {
      'spec.md': '# Spec',
      'tasks.md': '# Tasks\n- [ ] T001 Do something\n'
    });

    const result = computePipelineState(projectPath, '001-test');
    expect(result.phases.find(p => p.id === 'analyze').status).toBe('not_started');
  });

  // TS-028: Analyze detection — complete when analysis.md exists
  test('Analyze is complete when analysis.md exists', () => {
    createFeature(projectPath, '001-test', {
      'spec.md': '# Spec',
      'tasks.md': '# Tasks\n- [ ] T001 Do something\n',
      'analysis.md': '# Analysis Report\nAll clear.\n'
    });

    const result = computePipelineState(projectPath, '001-test');
    expect(result.phases.find(p => p.id === 'analyze').status).toBe('complete');
  });

  // TS-025: Implement detection — in progress with percentage
  test('Implement is in_progress with percentage when some tasks checked', () => {
    createFeature(projectPath, '001-test', {
      'spec.md': '# Spec',
      'tasks.md': '# Tasks\n- [x] T001 Do something\n- [x] T002 Do more\n- [ ] T003 Not yet\n- [ ] T004 Also not yet\n- [x] T005 And another\n- [x] T006 Done\n- [ ] T007 Nope\n- [ ] T008 Nope\n- [ ] T009 Nope\n- [ ] T010 Nope\n'
    });

    const result = computePipelineState(projectPath, '001-test');
    const implement = result.phases.find(p => p.id === 'implement');

    expect(implement.status).toBe('in_progress');
    expect(implement.progress).toBe('40%');
  });

  // TS-001: Pipeline shows correct status for partially complete feature
  test('correct status for partially complete feature (spec+plan+tasks at 40%)', () => {
    fs.writeFileSync(path.join(projectPath, 'CONSTITUTION.md'), '# Constitution\nTDD MUST be used.\n');
    createFeature(projectPath, '001-test', {
      'spec.md': '# Spec\n## Clarifications\n### Session\n- Q: x -> A: y\n',
      'plan.md': '# Plan\n## Tech\n',
      'tasks.md': '# Tasks\n- [x] T001 A\n- [x] T002 B\n- [ ] T003 C\n- [ ] T004 D\n- [ ] T005 E\n'
    });

    const result = computePipelineState(projectPath, '001-test');

    expect(result.phases.find(p => p.id === 'constitution').status).toBe('complete');
    expect(result.phases.find(p => p.id === 'spec').status).toBe('complete');
    expect(result.phases.find(p => p.id === 'clarify').status).toBe('complete');
    expect(result.phases.find(p => p.id === 'plan').status).toBe('complete');
    expect(result.phases.find(p => p.id === 'tasks').status).toBe('complete');
    expect(result.phases.find(p => p.id === 'implement').status).toBe('in_progress');
    expect(result.phases.find(p => p.id === 'implement').progress).toBe('40%');
  });

  // TS-003: Pipeline shows all nodes complete for finished feature
  test('all nodes complete for finished feature', () => {
    fs.writeFileSync(path.join(projectPath, 'CONSTITUTION.md'), '# Constitution\nTDD MUST be used.\n');
    createFeature(projectPath, '001-test', {
      'spec.md': '# Spec\n## Clarifications\n### Session\n- Q: x -> A: y\n',
      'plan.md': '# Plan',
      'checklists/req.md': '- [x] CHK001 Done\n',
      'tests/features/acceptance.feature': '@TS-001 @acceptance @P1\nScenario: Test\n  Given x\n  Then y\n',
      'tasks.md': '# Tasks\n- [x] T001 Done\n- [x] T002 Done\n',
      'analysis.md': '# Analysis Report\nAll clear.\n'
    });

    const result = computePipelineState(projectPath, '001-test');

    for (const phase of result.phases) {
      expect(phase.status).toBe('complete');
    }
  });

  // Returns exactly 9 phases
  test('always returns exactly 9 phases', () => {
    createFeature(projectPath, '001-test', { 'spec.md': '# Spec' });

    const result = computePipelineState(projectPath, '001-test');
    expect(result.phases).toHaveLength(9);
  });

  // Phase IDs are correct and ordered
  test('phase IDs are in correct order', () => {
    createFeature(projectPath, '001-test', { 'spec.md': '# Spec' });

    const result = computePipelineState(projectPath, '001-test');
    const ids = result.phases.map(p => p.id);

    expect(ids).toEqual([
      'constitution', 'spec', 'clarify', 'plan',
      'checklist', 'testify', 'tasks', 'analyze', 'implement'
    ]);
  });
});
