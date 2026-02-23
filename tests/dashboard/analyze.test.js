'use strict';

const {
  computeHealthScore,
  computeAnalyzeState,
  buildHeatmapRows,
  mapCellStatus,
  computePhaseSeparationScore,
  computeConstitutionCompliance
} = require('../../.claude/skills/iikit-core/scripts/dashboard/src/analyze');

// TS-052, TS-053: Health score computation and zone assignment
describe('computeHealthScore', () => {
  // TS-052: Health score computed as equal-weighted average of four factors
  test('computes equal-weighted average of four factors', () => {
    const result = computeHealthScore({
      requirementsCoverage: 80,
      constitutionCompliance: 100,
      phaseSeparation: 100,
      testCoverage: 90
    });

    expect(result.score).toBe(93); // Math.round((80 + 100 + 100 + 90) / 4)
  });

  test('returns factors with value and label in result', () => {
    const result = computeHealthScore({
      requirementsCoverage: 80,
      constitutionCompliance: 100,
      phaseSeparation: 100,
      testCoverage: 90
    });

    expect(result.factors).toHaveProperty('requirementsCoverage');
    expect(result.factors.requirementsCoverage).toHaveProperty('value', 80);
    expect(result.factors.requirementsCoverage).toHaveProperty('label');
    expect(result.factors).toHaveProperty('constitutionCompliance');
    expect(result.factors.constitutionCompliance).toHaveProperty('value', 100);
    expect(result.factors.constitutionCompliance).toHaveProperty('label');
    expect(result.factors).toHaveProperty('phaseSeparation');
    expect(result.factors.phaseSeparation).toHaveProperty('value', 100);
    expect(result.factors.phaseSeparation).toHaveProperty('label');
    expect(result.factors).toHaveProperty('testCoverage');
    expect(result.factors.testCoverage).toHaveProperty('value', 90);
    expect(result.factors.testCoverage).toHaveProperty('label');
  });

  // TS-053: Health score zone assignment follows color boundaries
  test('assigns "red" zone for score 0', () => {
    const result = computeHealthScore({
      requirementsCoverage: 0,
      constitutionCompliance: 0,
      phaseSeparation: 0,
      testCoverage: 0
    });
    expect(result.zone).toBe('red');
  });

  test('assigns "red" zone for score 40', () => {
    // All factors at 40 => average = 40
    const result = computeHealthScore({
      requirementsCoverage: 40,
      constitutionCompliance: 40,
      phaseSeparation: 40,
      testCoverage: 40
    });
    expect(result.score).toBe(40);
    expect(result.zone).toBe('red');
  });

  test('assigns "yellow" zone for score 41', () => {
    // Need average of 41: (41 + 41 + 41 + 41) / 4 = 41
    const result = computeHealthScore({
      requirementsCoverage: 41,
      constitutionCompliance: 41,
      phaseSeparation: 41,
      testCoverage: 41
    });
    expect(result.score).toBe(41);
    expect(result.zone).toBe('yellow');
  });

  test('assigns "yellow" zone for score 70', () => {
    const result = computeHealthScore({
      requirementsCoverage: 70,
      constitutionCompliance: 70,
      phaseSeparation: 70,
      testCoverage: 70
    });
    expect(result.score).toBe(70);
    expect(result.zone).toBe('yellow');
  });

  test('assigns "green" zone for score 71', () => {
    // Need average of 71: (71 + 71 + 71 + 71) / 4 = 71
    const result = computeHealthScore({
      requirementsCoverage: 71,
      constitutionCompliance: 71,
      phaseSeparation: 71,
      testCoverage: 71
    });
    expect(result.score).toBe(71);
    expect(result.zone).toBe('green');
  });

  test('assigns "green" zone for score 100', () => {
    const result = computeHealthScore({
      requirementsCoverage: 100,
      constitutionCompliance: 100,
      phaseSeparation: 100,
      testCoverage: 100
    });
    expect(result.score).toBe(100);
    expect(result.zone).toBe('green');
  });
});

// TS-054, TS-055: Phase separation score with severity penalties
describe('computeHealthScore - phase separation penalties', () => {
  // TS-054: Phase separation score applies severity penalties
  // CRITICAL=25, HIGH=15, MEDIUM=5, LOW=2
  test('applies severity penalties: 1 CRITICAL (25) + 2 MEDIUM (5 each) = 65', () => {
    const violations = [
      { severity: 'CRITICAL' },
      { severity: 'MEDIUM' },
      { severity: 'MEDIUM' }
    ];

    const score = computePhaseSeparationScore(violations);
    expect(score).toBe(65); // max(0, 100 - 25 - 5 - 5)
  });

  test('applies HIGH severity penalty of 15', () => {
    const violations = [{ severity: 'HIGH' }];
    const score = computePhaseSeparationScore(violations);
    expect(score).toBe(85); // max(0, 100 - 15)
  });

  test('applies LOW severity penalty of 2', () => {
    const violations = [{ severity: 'LOW' }];
    const score = computePhaseSeparationScore(violations);
    expect(score).toBe(98); // max(0, 100 - 2)
  });

  test('returns 100 for empty violations', () => {
    const score = computePhaseSeparationScore([]);
    expect(score).toBe(100);
  });

  // TS-055: Phase separation score floors at 0
  test('floors at 0 when penalties exceed 100 (5 CRITICAL = 125)', () => {
    const violations = [
      { severity: 'CRITICAL' },
      { severity: 'CRITICAL' },
      { severity: 'CRITICAL' },
      { severity: 'CRITICAL' },
      { severity: 'CRITICAL' }
    ];

    const score = computePhaseSeparationScore(violations);
    expect(score).toBe(0); // max(0, 100 - 125) = 0
  });
});

// TS-056: Constitution compliance percentage from alignment entries
describe('computeHealthScore - constitution compliance', () => {
  // TS-056: Constitution compliance percentage computed from alignment entries
  test('computes percentage from alignment entries: 3 ALIGNED out of 4 = 75', () => {
    const alignmentEntries = [
      { status: 'ALIGNED' },
      { status: 'ALIGNED' },
      { status: 'ALIGNED' },
      { status: 'VIOLATION' }
    ];

    const compliance = computeConstitutionCompliance(alignmentEntries);
    expect(compliance).toBe(75); // Math.round((3/4) * 100)
  });

  test('returns 100 when all entries are ALIGNED', () => {
    const alignmentEntries = [
      { status: 'ALIGNED' },
      { status: 'ALIGNED' }
    ];

    const compliance = computeConstitutionCompliance(alignmentEntries);
    expect(compliance).toBe(100);
  });

  test('returns 0 when all entries are VIOLATION', () => {
    const alignmentEntries = [
      { status: 'VIOLATION' },
      { status: 'VIOLATION' }
    ];

    const compliance = computeConstitutionCompliance(alignmentEntries);
    expect(compliance).toBe(0);
  });

  test('returns 100 for empty alignment entries', () => {
    const compliance = computeConstitutionCompliance([]);
    expect(compliance).toBe(100);
  });
});

// TS-057: Heatmap row assembly
describe('buildHeatmapRows', () => {
  // TS-057: Heatmap row assembly combines spec requirements with coverage data
  test('assembles rows combining requirements with coverage data', () => {
    const requirements = [
      { id: 'FR-001', text: 'System MUST display heatmap' }
    ];
    const coverageEntries = [
      {
        id: 'FR-001',
        hasTask: true,
        taskIds: ['T-003'],
        hasTest: true,
        testIds: ['TS-001'],
        status: 'Full'
      }
    ];

    const rows = buildHeatmapRows(requirements, coverageEntries);

    expect(rows).toHaveLength(1);
    expect(rows[0]).toEqual({
      id: 'FR-001',
      text: 'System MUST display heatmap',
      cells: {
        tasks: { status: 'covered', refs: ['T-003'] },
        tests: { status: 'covered', refs: ['TS-001'] },
        plan: { status: 'na', refs: [] }
      }
    });
  });

  test('returns empty array for empty requirements', () => {
    const rows = buildHeatmapRows([], []);
    expect(rows).toEqual([]);
  });

  test('uses mapCellStatus for plan cell when hasPlan is present in coverage', () => {
    const requirements = [
      { id: 'FR-001', text: 'System MUST display heatmap' }
    ];
    const coverageEntries = [
      {
        id: 'FR-001',
        hasTask: true,
        taskIds: ['T-003'],
        hasTest: true,
        testIds: ['TS-001'],
        hasPlan: true,
        planRefs: ['KDD-4', 'KDD-7'],
        status: 'Full'
      }
    ];

    const rows = buildHeatmapRows(requirements, coverageEntries);

    expect(rows).toHaveLength(1);
    expect(rows[0].cells.plan).toEqual({ status: 'covered', refs: ['KDD-4', 'KDD-7'] });
  });

  test('plan cell is missing when hasPlan is false with no refs', () => {
    const requirements = [
      { id: 'FR-002', text: 'System MUST log events' }
    ];
    const coverageEntries = [
      {
        id: 'FR-002',
        hasTask: true,
        taskIds: ['T-005'],
        hasTest: false,
        testIds: [],
        hasPlan: false,
        planRefs: [],
        status: null
      }
    ];

    const rows = buildHeatmapRows(requirements, coverageEntries);
    expect(rows[0].cells.plan).toEqual({ status: 'missing', refs: [] });
  });

  test('marks all cells as missing when requirement has no coverage entry', () => {
    const requirements = [
      { id: 'FR-002', text: 'System MUST log events' }
    ];
    const coverageEntries = [];

    const rows = buildHeatmapRows(requirements, coverageEntries);

    expect(rows).toHaveLength(1);
    expect(rows[0].cells.tasks).toEqual({ status: 'missing', refs: [] });
    expect(rows[0].cells.tests).toEqual({ status: 'missing', refs: [] });
    expect(rows[0].cells.plan).toEqual({ status: 'na', refs: [] });
  });
});

// TS-058: Cell status mapping
describe('mapCellStatus', () => {
  // TS-058: Cell status maps coverage entry boolean to status string
  test('maps hasArtifact=true with IDs to "covered"', () => {
    const result = mapCellStatus(true, ['T-001'], null);
    expect(result).toEqual({ status: 'covered', refs: ['T-001'] });
  });

  test('maps hasArtifact=false with empty IDs to "missing"', () => {
    const result = mapCellStatus(false, [], null);
    expect(result).toEqual({ status: 'missing', refs: [] });
  });

  test('maps status "Partial" to "partial"', () => {
    const result = mapCellStatus(true, ['T-001'], 'Partial');
    expect(result).toEqual({ status: 'partial', refs: ['T-001'] });
  });

  test('maps hasArtifact=true with multiple IDs to "covered"', () => {
    const result = mapCellStatus(true, ['T-001', 'T-002'], null);
    expect(result).toEqual({ status: 'covered', refs: ['T-001', 'T-002'] });
  });
});
