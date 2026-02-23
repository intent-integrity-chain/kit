const path = require('path');
const fs = require('fs');
const os = require('os');
const { buildEdges, findGaps, buildPyramid, computeTestifyState } = require('../../.claude/skills/iikit-core/scripts/dashboard/src/testify');

const FIXTURES_DIR = path.join(__dirname, 'fixtures/testify');

// T004: Tests for buildEdges — TS-028
describe('buildEdges', () => {
  test('creates requirement-to-test edges from traceability links', () => {
    const requirements = [{ id: 'FR-001' }, { id: 'FR-002' }];
    const testSpecs = [
      { id: 'TS-001', traceability: ['FR-001'] },
      { id: 'TS-002', traceability: ['FR-001', 'FR-002'] }
    ];
    const taskTestRefs = {};

    const edges = buildEdges(requirements, testSpecs, taskTestRefs);
    const reqToTest = edges.filter(e => e.type === 'requirement-to-test');

    expect(reqToTest).toContainEqual({ from: 'FR-001', to: 'TS-001', type: 'requirement-to-test' });
    expect(reqToTest).toContainEqual({ from: 'FR-001', to: 'TS-002', type: 'requirement-to-test' });
    expect(reqToTest).toContainEqual({ from: 'FR-002', to: 'TS-002', type: 'requirement-to-test' });
    expect(reqToTest).toHaveLength(3);
  });

  test('creates test-to-task edges from testSpecRefs', () => {
    const requirements = [];
    const testSpecs = [{ id: 'TS-001', traceability: [] }];
    const taskTestRefs = { T005: ['TS-001'] };

    const edges = buildEdges(requirements, testSpecs, taskTestRefs);
    const testToTask = edges.filter(e => e.type === 'test-to-task');

    expect(testToTask).toContainEqual({ from: 'TS-001', to: 'T005', type: 'test-to-task' });
    expect(testToTask).toHaveLength(1);
  });

  test('ignores orphaned references — FR-099 not in requirements', () => {
    const requirements = [{ id: 'FR-001' }];
    const testSpecs = [
      { id: 'TS-001', traceability: ['FR-001', 'FR-099'] }
    ];
    const taskTestRefs = { T001: ['TS-001', 'TS-999'] };

    const edges = buildEdges(requirements, testSpecs, taskTestRefs);

    // FR-099 not in requirements -> no edge
    expect(edges).not.toContainEqual(expect.objectContaining({ from: 'FR-099' }));
    // TS-999 not in testSpecs -> no edge
    expect(edges).not.toContainEqual(expect.objectContaining({ from: 'TS-999' }));
    // Valid edges should exist
    expect(edges).toContainEqual({ from: 'FR-001', to: 'TS-001', type: 'requirement-to-test' });
    expect(edges).toContainEqual({ from: 'TS-001', to: 'T001', type: 'test-to-task' });
  });

  test('returns empty array when no connections', () => {
    const edges = buildEdges([], [], {});
    expect(edges).toEqual([]);
  });
});

// T005: Tests for findGaps — TS-029, TS-030
describe('findGaps', () => {
  // TS-029: identifies untested requirements
  test('identifies untested requirements', () => {
    const requirements = [{ id: 'FR-001' }, { id: 'FR-002' }, { id: 'FR-003' }];
    const testSpecs = [{ id: 'TS-001' }];
    const edges = [
      { from: 'FR-001', to: 'TS-001', type: 'requirement-to-test' },
      { from: 'FR-002', to: 'TS-001', type: 'requirement-to-test' }
    ];

    const gaps = findGaps(requirements, testSpecs, edges);
    expect(gaps.untestedRequirements).toEqual(['FR-003']);
  });

  // TS-030: identifies unimplemented tests
  test('identifies unimplemented tests', () => {
    const requirements = [];
    const testSpecs = [{ id: 'TS-001' }, { id: 'TS-002' }, { id: 'TS-003' }];
    const edges = [
      { from: 'TS-001', to: 'T001', type: 'test-to-task' },
      { from: 'TS-002', to: 'T002', type: 'test-to-task' }
    ];

    const gaps = findGaps(requirements, testSpecs, edges);
    expect(gaps.unimplementedTests).toEqual(['TS-003']);
  });

  test('returns empty gaps when traceability is complete', () => {
    const requirements = [{ id: 'FR-001' }];
    const testSpecs = [{ id: 'TS-001' }];
    const edges = [
      { from: 'FR-001', to: 'TS-001', type: 'requirement-to-test' },
      { from: 'TS-001', to: 'T001', type: 'test-to-task' }
    ];

    const gaps = findGaps(requirements, testSpecs, edges);
    expect(gaps.untestedRequirements).toEqual([]);
    expect(gaps.unimplementedTests).toEqual([]);
  });

  test('handles empty inputs', () => {
    const gaps = findGaps([], [], []);
    expect(gaps.untestedRequirements).toEqual([]);
    expect(gaps.unimplementedTests).toEqual([]);
  });
});

// T006: Tests for buildPyramid — TS-032
describe('buildPyramid', () => {
  test('groups test specs by type with correct counts', () => {
    const testSpecs = [
      { id: 'TS-001', type: 'acceptance' },
      { id: 'TS-002', type: 'acceptance' },
      { id: 'TS-003', type: 'acceptance' },
      { id: 'TS-004', type: 'contract' },
      { id: 'TS-005', type: 'contract' },
      { id: 'TS-006', type: 'contract' },
      { id: 'TS-007', type: 'contract' },
      { id: 'TS-008', type: 'contract' },
      { id: 'TS-009', type: 'validation' },
      { id: 'TS-010', type: 'validation' },
      { id: 'TS-011', type: 'validation' },
      { id: 'TS-012', type: 'validation' },
      { id: 'TS-013', type: 'validation' },
      { id: 'TS-014', type: 'validation' },
      { id: 'TS-015', type: 'validation' },
      { id: 'TS-016', type: 'validation' }
    ];

    const pyramid = buildPyramid(testSpecs);
    expect(pyramid.acceptance.count).toBe(3);
    expect(pyramid.acceptance.ids).toEqual(['TS-001', 'TS-002', 'TS-003']);
    expect(pyramid.contract.count).toBe(5);
    expect(pyramid.contract.ids).toEqual(['TS-004', 'TS-005', 'TS-006', 'TS-007', 'TS-008']);
    expect(pyramid.validation.count).toBe(8);
    expect(pyramid.validation.ids).toHaveLength(8);
  });

  test('handles empty test specs', () => {
    const pyramid = buildPyramid([]);
    expect(pyramid.acceptance).toEqual({ count: 0, ids: [] });
    expect(pyramid.contract).toEqual({ count: 0, ids: [] });
    expect(pyramid.validation).toEqual({ count: 0, ids: [] });
  });

  test('handles missing types', () => {
    const testSpecs = [
      { id: 'TS-001', type: 'acceptance' },
      { id: 'TS-002', type: 'validation' }
    ];
    const pyramid = buildPyramid(testSpecs);
    expect(pyramid.acceptance.count).toBe(1);
    expect(pyramid.contract.count).toBe(0);
    expect(pyramid.validation.count).toBe(1);
  });
});

// T007: Tests for integrity state computation — TS-031
describe('computeTestifyState integrity', () => {
  let tmpDir;

  function copyFeatureFixtures(featureDir) {
    const featuresDir = path.join(featureDir, 'tests', 'features');
    fs.mkdirSync(featuresDir, { recursive: true });
    const srcFeaturesDir = path.join(FIXTURES_DIR, 'tests', 'features');
    for (const f of fs.readdirSync(srcFeaturesDir).filter(f => f.endsWith('.feature'))) {
      fs.copyFileSync(path.join(srcFeaturesDir, f), path.join(featuresDir, f));
    }
  }

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'testify-integrity-'));
    const featureDir = path.join(tmpDir, 'specs', 'test-feature');
    fs.mkdirSync(featureDir, { recursive: true });

    // Copy fixture files
    fs.copyFileSync(
      path.join(FIXTURES_DIR, 'spec.md'),
      path.join(featureDir, 'spec.md')
    );
    copyFeatureFixtures(featureDir);
    fs.copyFileSync(
      path.join(FIXTURES_DIR, 'tasks.md'),
      path.join(featureDir, 'tasks.md')
    );
  });

  afterEach(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  test('returns status "valid" when hashes match', () => {
    const featureDir = path.join(tmpDir, 'specs', 'test-feature');
    fs.copyFileSync(
      path.join(FIXTURES_DIR, 'context.json'),
      path.join(featureDir, 'context.json')
    );

    const state = computeTestifyState(tmpDir, 'test-feature');
    expect(state.integrity.status).toBe('valid');
    expect(state.integrity.currentHash).toBe(state.integrity.storedHash);
  });

  test('returns status "tampered" when hashes differ', () => {
    const featureDir = path.join(tmpDir, 'specs', 'test-feature');
    fs.copyFileSync(
      path.join(FIXTURES_DIR, 'context-tampered.json'),
      path.join(featureDir, 'context.json')
    );

    const state = computeTestifyState(tmpDir, 'test-feature');
    expect(state.integrity.status).toBe('tampered');
  });

  test('returns status "missing" when no hash stored', () => {
    const featureDir = path.join(tmpDir, 'specs', 'test-feature');
    fs.copyFileSync(
      path.join(FIXTURES_DIR, 'context-missing.json'),
      path.join(featureDir, 'context.json')
    );

    const state = computeTestifyState(tmpDir, 'test-feature');
    expect(state.integrity.status).toBe('missing');
  });

  test('returns status "missing" when no context.json exists', () => {
    const state = computeTestifyState(tmpDir, 'test-feature');
    expect(state.integrity.status).toBe('missing');
  });
});

// T004/T005 combined: full computeTestifyState with fixture data
describe('computeTestifyState', () => {
  let tmpDir;

  function copyFeatureFixtures(featureDir) {
    const featuresDir = path.join(featureDir, 'tests', 'features');
    fs.mkdirSync(featuresDir, { recursive: true });
    const srcFeaturesDir = path.join(FIXTURES_DIR, 'tests', 'features');
    for (const f of fs.readdirSync(srcFeaturesDir).filter(f => f.endsWith('.feature'))) {
      fs.copyFileSync(path.join(srcFeaturesDir, f), path.join(featuresDir, f));
    }
  }

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'testify-full-'));
    const featureDir = path.join(tmpDir, 'specs', 'test-feature');
    fs.mkdirSync(featureDir, { recursive: true });

    fs.copyFileSync(path.join(FIXTURES_DIR, 'spec.md'), path.join(featureDir, 'spec.md'));
    copyFeatureFixtures(featureDir);
    fs.copyFileSync(path.join(FIXTURES_DIR, 'tasks.md'), path.join(featureDir, 'tasks.md'));
    fs.copyFileSync(path.join(FIXTURES_DIR, 'context.json'), path.join(featureDir, 'context.json'));
  });

  afterEach(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  test('returns complete TestifyViewState shape', () => {
    const state = computeTestifyState(tmpDir, 'test-feature');

    expect(state).toHaveProperty('requirements');
    expect(state).toHaveProperty('testSpecs');
    expect(state).toHaveProperty('tasks');
    expect(state).toHaveProperty('edges');
    expect(state).toHaveProperty('gaps');
    expect(state).toHaveProperty('pyramid');
    expect(state).toHaveProperty('integrity');
    expect(state).toHaveProperty('exists');
    expect(state.exists).toBe(true);
  });

  test('parses requirements from spec.md', () => {
    const state = computeTestifyState(tmpDir, 'test-feature');

    expect(state.requirements.length).toBeGreaterThan(0);
    const frIds = state.requirements.filter(r => r.id.startsWith('FR-'));
    const scIds = state.requirements.filter(r => r.id.startsWith('SC-'));
    expect(frIds.length).toBe(5);
    expect(scIds.length).toBe(3);
  });

  test('parses test specs from .feature files', () => {
    const state = computeTestifyState(tmpDir, 'test-feature');
    expect(state.testSpecs).toHaveLength(8);
    expect(state.testSpecs[0]).toHaveProperty('id');
    expect(state.testSpecs[0]).toHaveProperty('title');
    expect(state.testSpecs[0]).toHaveProperty('type');
    expect(state.testSpecs[0]).toHaveProperty('priority');
    expect(state.testSpecs[0]).toHaveProperty('traceability');
  });

  test('parses tasks with testSpecRefs', () => {
    const state = computeTestifyState(tmpDir, 'test-feature');
    expect(state.tasks.length).toBeGreaterThan(0);

    const t002 = state.tasks.find(t => t.id === 'T002');
    expect(t002).toBeDefined();
    expect(t002.testSpecRefs).toContain('TS-001');
  });

  test('builds edges between requirements, tests, and tasks', () => {
    const state = computeTestifyState(tmpDir, 'test-feature');
    expect(state.edges.length).toBeGreaterThan(0);

    const reqToTest = state.edges.filter(e => e.type === 'requirement-to-test');
    const testToTask = state.edges.filter(e => e.type === 'test-to-task');
    expect(reqToTest.length).toBeGreaterThan(0);
    expect(testToTask.length).toBeGreaterThan(0);
  });

  test('detects gaps structure is correct', () => {
    const state = computeTestifyState(tmpDir, 'test-feature');
    expect(state.gaps).toHaveProperty('untestedRequirements');
    expect(state.gaps).toHaveProperty('unimplementedTests');
    expect(Array.isArray(state.gaps.untestedRequirements)).toBe(true);
    expect(Array.isArray(state.gaps.unimplementedTests)).toBe(true);
  });

  test('builds pyramid with correct counts', () => {
    const state = computeTestifyState(tmpDir, 'test-feature');
    expect(state.pyramid.acceptance.count).toBe(3);
    expect(state.pyramid.contract.count).toBe(2);
    expect(state.pyramid.validation.count).toBe(3);
  });

  test('returns exists false when no .feature files exist', () => {
    const featureDir = path.join(tmpDir, 'specs', 'test-feature');
    fs.rmSync(path.join(featureDir, 'tests', 'features'), { recursive: true, force: true });

    const state = computeTestifyState(tmpDir, 'test-feature');
    expect(state.exists).toBe(false);
    expect(state.testSpecs).toEqual([]);
    expect(state.edges).toEqual([]);
    expect(state.pyramid.acceptance.count).toBe(0);
    expect(state.pyramid.contract.count).toBe(0);
    expect(state.pyramid.validation.count).toBe(0);
    expect(state.integrity.status).toBe('missing');
  });

  test('returns empty state when feature directory missing', () => {
    const state = computeTestifyState(tmpDir, 'nonexistent-feature');
    expect(state.exists).toBe(false);
    expect(state.requirements).toEqual([]);
    expect(state.testSpecs).toEqual([]);
    expect(state.tasks).toEqual([]);
  });
});
