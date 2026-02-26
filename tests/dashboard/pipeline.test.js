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

  // TS-018: Clarification count — spec clarifications tracked on spec phase
  test('Spec phase has clarification count when spec.md has Clarifications section', () => {
    createFeature(projectPath, '001-test', {
      'spec.md': '# Spec\n## Clarifications\n### Session 2026-01-01\n- Q: test -> A: yes\n'
    });

    const result = computePipelineState(projectPath, '001-test');
    expect(result.phases.find(p => p.id === 'spec').clarifications).toBe(1);
  });

  // TS-019: No clarify phase in pipeline (clarify is now a utility)
  test('No clarify phase exists in pipeline (clarify is a utility)', () => {
    createFeature(projectPath, '001-test', {
      'spec.md': '# Spec\n## Requirements\n',
      'plan.md': '# Plan\n## Technical Context\n'
    });

    const result = computePipelineState(projectPath, '001-test');
    expect(result.phases.find(p => p.id === 'clarify')).toBeUndefined();
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

    // Only domain.md counts (requirements.md is excluded as spec quality checklist)
    expect(checklist.status).toBe('in_progress');
    expect(checklist.progress).toBe('33%');
  });

  // TS-021: Checklist detection — complete when all 100%
  test('Checklist is complete when all items checked', () => {
    createFeature(projectPath, '001-test', {
      'spec.md': '# Spec',
      'checklists/requirements.md': '# Checklist\n- [x] CHK001 Item 1\n',
      'checklists/domain.md': '# Domain\n- [x] CHK002 Item 2\n'
    });

    const result = computePipelineState(projectPath, '001-test');
    // Only domain.md counts (requirements.md excluded)
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
      'spec.md': '# Spec\n## Clarifications\n### Session 2026-01-15\n- Q: x -> A: y\n',
      'plan.md': '# Plan\n## Tech\n',
      'tasks.md': '# Tasks\n- [x] T001 A\n- [x] T002 B\n- [ ] T003 C\n- [ ] T004 D\n- [ ] T005 E\n'
    });

    const result = computePipelineState(projectPath, '001-test');

    expect(result.phases.find(p => p.id === 'constitution').status).toBe('complete');
    expect(result.phases.find(p => p.id === 'spec').status).toBe('complete');
    expect(result.phases.find(p => p.id === 'spec').clarifications).toBe(1);
    expect(result.phases.find(p => p.id === 'plan').status).toBe('complete');
    expect(result.phases.find(p => p.id === 'tasks').status).toBe('complete');
    expect(result.phases.find(p => p.id === 'implement').status).toBe('in_progress');
    expect(result.phases.find(p => p.id === 'implement').progress).toBe('40%');
  });

  // TS-003: Pipeline shows all nodes complete for finished feature
  test('all nodes complete for finished feature', () => {
    fs.writeFileSync(path.join(projectPath, 'CONSTITUTION.md'), '# Constitution\nTDD MUST be used.\n');
    createFeature(projectPath, '001-test', {
      'spec.md': '# Spec\n## Clarifications\n### Session 2026-01-15\n- Q: x -> A: y\n',
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

  // Returns exactly 8 phases (clarify removed — now a utility)
  test('always returns exactly 8 phases', () => {
    createFeature(projectPath, '001-test', { 'spec.md': '# Spec' });

    const result = computePipelineState(projectPath, '001-test');
    expect(result.phases).toHaveLength(8);
  });

  // Phase IDs are correct and ordered (no clarify — it's a utility)
  test('phase IDs are in correct order', () => {
    createFeature(projectPath, '001-test', { 'spec.md': '# Spec' });

    const result = computePipelineState(projectPath, '001-test');
    const ids = result.phases.map(p => p.id);

    expect(ids).toEqual([
      'constitution', 'spec', 'plan',
      'checklist', 'testify', 'tasks', 'analyze', 'implement'
    ]);
  });

  // Each phase has a clarifications count field
  test('each phase has a clarifications count field', () => {
    createFeature(projectPath, '001-test', { 'spec.md': '# Spec' });

    const result = computePipelineState(projectPath, '001-test');
    for (const phase of result.phases) {
      expect(typeof phase.clarifications).toBe('number');
    }
  });

  // =========================================================================
  // Bug regression tests (from e2e test findings)
  // =========================================================================

  test('BUG-6: checklist phase tracks clarification count', () => {
    createFeature(projectPath, '001-test', {
      'spec.md': '# Spec\n## Requirements\n- FR-001\n## Success Criteria\n- SC-001\n## User Scenarios\n### US1\n',
      'plan.md': '# Plan',
      'checklists/quality.md': `# Checklist
- [x] CL-001 Item one
- [x] CL-002 Item two

## Clarifications

### Session 2026-02-26

- Q: Is the threshold correct? -> A: Yes, 80% is fine [CL-001]
- Q: Missing any checks? -> A: No, coverage is complete [CL-002]
`,
    });

    const result = computePipelineState(projectPath, '001-test');
    const checklist = result.phases.find(p => p.id === 'checklist');
    // Checklist clarifications should be tracked, not hardcoded to 0
    expect(checklist.clarifications).toBeGreaterThan(0);
  });

  test('BUG-12: story cards reflect correct task counts for tagged tasks', () => {
    createFeature(projectPath, '001-test', {
      'spec.md': `# Spec
## Requirements
- FR-001: First
- FR-002: Second
## Success Criteria
- SC-001: Test
## User Scenarios
### User Story 1 - Login (Priority: P1)
Given a user, When they login, Then they are authenticated.
`,
      'plan.md': '# Plan',
      'tasks.md': `# Tasks
## Phase 1
- [x] T001 [US1] First task
- [x] T002 [US1] Second task
- [x] T003 Untagged task
`,
    });

    const result = computePipelineState(projectPath, '001-test');
    const implement = result.phases.find(p => p.id === 'implement');
    // All 3 tasks are done, implement should be complete
    expect(implement.status).toBe('complete');
  });
});
