'use strict';

const { computeChecklistViewState } = require('../../.claude/skills/iikit-core/scripts/dashboard/src/checklist');
const fs = require('fs');
const path = require('path');
const os = require('os');

describe('computeChecklistViewState', () => {
  let tmpDir;

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'checklist-view-test-'));
  });

  afterEach(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  /**
   * Helper: create a checklist file inside the standard project structure.
   * Creates tmpDir/specs/<featureId>/checklists/<filename>.
   *
   * @param {string} featureId - feature directory name
   * @param {string} filename - checklist filename (e.g., "ux.md")
   * @param {string} content - markdown content
   */
  function writeChecklist(featureId, filename, content) {
    const dir = path.join(tmpDir, 'specs', featureId, 'checklists');
    fs.mkdirSync(dir, { recursive: true });
    fs.writeFileSync(path.join(dir, filename), content);
  }

  /**
   * Helper: generate N checked + M unchecked items as markdown lines.
   */
  function generateItems(checked, unchecked) {
    const lines = [];
    for (let i = 0; i < checked; i++) {
      lines.push(`- [x] CHK-${String(i + 1).padStart(3, '0')} Checked item ${i + 1}`);
    }
    for (let i = 0; i < unchecked; i++) {
      lines.push(`- [ ] CHK-${String(checked + i + 1).padStart(3, '0')} Unchecked item ${checked + i + 1}`);
    }
    return lines.join('\n') + '\n';
  }

  // TS-022: Color mapping — red for 0-33%
  describe('color mapping red for 0-33%', () => {
    test('0% maps to red', () => {
      // 0 checked, 3 unchecked = 0%
      writeChecklist('test-feature', 'review.md', generateItems(0, 3));
      const result = computeChecklistViewState(tmpDir, 'test-feature');
      const file = result.files.find(f => f.filename === 'review.md');
      expect(file).toBeDefined();
      expect(file.percentage).toBe(0);
      expect(file.color).toBe('red');
    });

    test('15% maps to red', () => {
      // ~15%: need ratio close to 0.15 -> 3 checked, 17 unchecked = 3/20 = 15%
      writeChecklist('test-feature', 'review.md', generateItems(3, 17));
      const result = computeChecklistViewState(tmpDir, 'test-feature');
      const file = result.files.find(f => f.filename === 'review.md');
      expect(file.percentage).toBe(15);
      expect(file.color).toBe('red');
    });

    test('33% maps to red', () => {
      // 1 checked, 2 unchecked = 33% (Math.round(1/3 * 100))
      writeChecklist('test-feature', 'review.md', generateItems(1, 2));
      const result = computeChecklistViewState(tmpDir, 'test-feature');
      const file = result.files.find(f => f.filename === 'review.md');
      expect(file.percentage).toBe(33);
      expect(file.color).toBe('red');
    });
  });

  // TS-023: Color mapping — yellow for 34-66%
  describe('color mapping yellow for 34-66%', () => {
    test('34% maps to yellow', () => {
      // Need ratio ~0.34 -> Math.round(x/n * 100) = 34
      // 34/100 = 0.34 -> 34 checked, 66 unchecked
      writeChecklist('test-feature', 'review.md', generateItems(34, 66));
      const result = computeChecklistViewState(tmpDir, 'test-feature');
      const file = result.files.find(f => f.filename === 'review.md');
      expect(file.percentage).toBe(34);
      expect(file.color).toBe('yellow');
    });

    test('50% maps to yellow', () => {
      // 2 checked, 2 unchecked = 50%
      writeChecklist('test-feature', 'review.md', generateItems(2, 2));
      const result = computeChecklistViewState(tmpDir, 'test-feature');
      const file = result.files.find(f => f.filename === 'review.md');
      expect(file.percentage).toBe(50);
      expect(file.color).toBe('yellow');
    });

    test('66% maps to yellow', () => {
      // 2 checked, 1 unchecked = 67% -> that's green boundary
      // Need exactly 66%: Math.round(x/n * 100) = 66
      // 66/100 = 0.66 -> 66 checked, 34 unchecked
      writeChecklist('test-feature', 'review.md', generateItems(66, 34));
      const result = computeChecklistViewState(tmpDir, 'test-feature');
      const file = result.files.find(f => f.filename === 'review.md');
      expect(file.percentage).toBe(66);
      expect(file.color).toBe('yellow');
    });
  });

  // TS-024: Color mapping — green for 67-100%
  describe('color mapping green for 67-100%', () => {
    test('67% maps to green', () => {
      // 2 checked, 1 unchecked = Math.round(2/3 * 100) = 67%
      writeChecklist('test-feature', 'review.md', generateItems(2, 1));
      const result = computeChecklistViewState(tmpDir, 'test-feature');
      const file = result.files.find(f => f.filename === 'review.md');
      expect(file.percentage).toBe(67);
      expect(file.color).toBe('green');
    });

    test('85% maps to green', () => {
      // Math.round(17/20 * 100) = 85%
      writeChecklist('test-feature', 'review.md', generateItems(17, 3));
      const result = computeChecklistViewState(tmpDir, 'test-feature');
      const file = result.files.find(f => f.filename === 'review.md');
      expect(file.percentage).toBe(85);
      expect(file.color).toBe('green');
    });

    test('100% maps to green', () => {
      writeChecklist('test-feature', 'review.md', generateItems(4, 0));
      const result = computeChecklistViewState(tmpDir, 'test-feature');
      const file = result.files.find(f => f.filename === 'review.md');
      expect(file.percentage).toBe(100);
      expect(file.color).toBe('green');
    });
  });

  // TS-025: Gate status — red when any file at 0%
  test('gate status red when any file at 0%', () => {
    // File 1: 0% (0 checked, 4 unchecked)
    writeChecklist('test-feature', 'ux.md', generateItems(0, 4));
    // File 2: 50% (2 checked, 2 unchecked)
    writeChecklist('test-feature', 'api.md', generateItems(2, 2));
    const result = computeChecklistViewState(tmpDir, 'test-feature');
    expect(result.gate).toEqual({ status: 'blocked', level: 'red', label: 'GATE: BLOCKED' });
  });

  // TS-026: Gate status — yellow when all between 1-99%
  test('gate status yellow when all between 1-99%', () => {
    // File 1: 25% (1 checked, 3 unchecked)
    writeChecklist('test-feature', 'ux.md', generateItems(1, 3));
    // File 2: 75% (3 checked, 1 unchecked)
    writeChecklist('test-feature', 'api.md', generateItems(3, 1));
    const result = computeChecklistViewState(tmpDir, 'test-feature');
    expect(result.gate).toEqual({ status: 'blocked', level: 'yellow', label: 'GATE: BLOCKED' });
  });

  // TS-027: Gate status — green when all at 100%
  test('gate status green when all at 100%', () => {
    // File 1: 100%
    writeChecklist('test-feature', 'ux.md', generateItems(4, 0));
    // File 2: 100%
    writeChecklist('test-feature', 'api.md', generateItems(3, 0));
    const result = computeChecklistViewState(tmpDir, 'test-feature');
    expect(result.gate).toEqual({ status: 'open', level: 'green', label: 'GATE: OPEN' });
  });

  // TS-028: Gate status — red when no files exist
  test('gate status red when no files exist', () => {
    // Create the feature directory structure but no checklist files
    const dir = path.join(tmpDir, 'specs', 'test-feature', 'checklists');
    fs.mkdirSync(dir, { recursive: true });
    const result = computeChecklistViewState(tmpDir, 'test-feature');
    expect(result.files).toEqual([]);
    expect(result.gate).toEqual({ status: 'blocked', level: 'red', label: 'GATE: BLOCKED' });
  });
});
