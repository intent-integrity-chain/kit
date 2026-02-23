'use strict';

const { computePlanViewState, classifyNodeTypes, fetchTesslEvalData, invalidateEvalCache } = require('../../.claude/skills/iikit-core/scripts/dashboard/src/planview');
const fs = require('fs');
const path = require('path');
const os = require('os');
const childProcess = require('child_process');

describe('computePlanViewState', () => {
  let tmpDir;

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'planview-test-'));
    fs.mkdirSync(path.join(tmpDir, 'specs', '001-test-feature'), { recursive: true });
  });

  afterEach(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  // TS-021: returns exists:false when no plan.md
  test('returns exists false when plan.md missing', async () => {
    const result = await computePlanViewState(tmpDir, '001-test-feature');
    expect(result.exists).toBe(false);
    expect(result.techContext).toEqual([]);
    expect(result.fileStructure).toBeNull();
    expect(result.diagram).toBeNull();
    expect(result.tesslTiles).toEqual([]);
  });

  // TS-001, TS-002, TS-023: techContext from plan.md
  test('extracts techContext from plan.md Technical Context', async () => {
    const planContent = `# Plan

## Technical Context

**Language/Version**: Node.js 20+ (LTS)
**Primary Dependencies**: Express, ws, chokidar
**Testing**: Jest

## Constitution Check
`;
    fs.writeFileSync(path.join(tmpDir, 'specs', '001-test-feature', 'plan.md'), planContent);
    const result = await computePlanViewState(tmpDir, '001-test-feature');
    expect(result.exists).toBe(true);
    expect(result.techContext).toHaveLength(3);
    expect(result.techContext[0]).toEqual({ label: 'Language/Version', value: 'Node.js 20+ (LTS)' });
  });

  // TS-004, TS-024: fileStructure from plan.md
  test('extracts fileStructure with exists boolean', async () => {
    // Create a real file so exists check works
    fs.mkdirSync(path.join(tmpDir, 'src'), { recursive: true });
    fs.writeFileSync(path.join(tmpDir, 'src', 'server.js'), '');

    const planContent = `# Plan

## File Structure

\`\`\`
myproject/
├── src/
│   ├── server.js          # Express server
│   └── newfile.js
\`\`\`
`;
    fs.writeFileSync(path.join(tmpDir, 'specs', '001-test-feature', 'plan.md'), planContent);
    const result = await computePlanViewState(tmpDir, '001-test-feature');
    expect(result.fileStructure).not.toBeNull();
    expect(result.fileStructure.rootName).toBe('myproject');

    const serverEntry = result.fileStructure.entries.find(e => e.name === 'server.js');
    expect(serverEntry.exists).toBe(true);

    const newfileEntry = result.fileStructure.entries.find(e => e.name === 'newfile.js');
    expect(newfileEntry.exists).toBe(false);
  });

  // TS-008, TS-025: diagram null when no Architecture Overview
  test('diagram is null when no ASCII diagram', async () => {
    const planContent = `# Plan

## Technical Context

**Language/Version**: Node.js 20+

## File Structure

\`\`\`
myproject/
├── index.js
\`\`\`
`;
    fs.writeFileSync(path.join(tmpDir, 'specs', '001-test-feature', 'plan.md'), planContent);
    const result = await computePlanViewState(tmpDir, '001-test-feature');
    expect(result.diagram).toBeNull();
  });

  // TS-026: tesslTiles from tessl.json
  test('reads tessl tiles from project root tessl.json', async () => {
    fs.writeFileSync(path.join(tmpDir, 'tessl.json'), JSON.stringify({
      dependencies: { 'tessl/npm-express': { version: '5.1.0' } }
    }));
    fs.writeFileSync(path.join(tmpDir, 'specs', '001-test-feature', 'plan.md'), '## Technical Context\n\n**Language**: Node.js\n');

    const result = await computePlanViewState(tmpDir, '001-test-feature', { fetchEvalData: async () => null });
    expect(result.tesslTiles).toHaveLength(1);
    expect(result.tesslTiles[0]).toEqual({ name: 'tessl/npm-express', version: '5.1.0', eval: null });
  });

  // TS-042: eval scores displayed when Tessl API returns eval data
  test('enriches tessl tiles with eval data when available', async () => {
    fs.writeFileSync(path.join(tmpDir, 'tessl.json'), JSON.stringify({
      dependencies: {
        'tessl/npm-express': { version: '5.1.0' },
        'tessl/npm-ws': { version: '8.18.0' }
      }
    }));
    fs.writeFileSync(path.join(tmpDir, 'specs', '001-test-feature', 'plan.md'), '## Technical Context\n\n**Language**: Node.js\n');

    const mockEvalData = { score: 94, multiplier: 1.21, chartData: { pass: 47, fail: 3 } };
    const fetchEvalData = async (tileName) => {
      if (tileName === 'tessl/npm-express') return mockEvalData;
      return null;
    };

    const result = await computePlanViewState(tmpDir, '001-test-feature', { fetchEvalData });
    expect(result.tesslTiles).toHaveLength(2);

    const expressTile = result.tesslTiles.find(t => t.name === 'tessl/npm-express');
    expect(expressTile.eval).toEqual(mockEvalData);
    expect(expressTile.eval.score).toBe(94);
    expect(expressTile.eval.multiplier).toBe(1.21);
    expect(expressTile.eval.chartData).toEqual({ pass: 47, fail: 3 });

    const wsTile = result.tesslTiles.find(t => t.name === 'tessl/npm-ws');
    expect(wsTile.eval).toBeNull();
  });

  // TS-043: eval scores absent when Tessl API returns no eval data
  test('tessl tiles have null eval when no eval data available', async () => {
    fs.writeFileSync(path.join(tmpDir, 'tessl.json'), JSON.stringify({
      dependencies: { 'tessl/npm-express': { version: '5.1.0' } }
    }));
    fs.writeFileSync(path.join(tmpDir, 'specs', '001-test-feature', 'plan.md'), '## Technical Context\n\n**Language**: Node.js\n');

    const result = await computePlanViewState(tmpDir, '001-test-feature', { fetchEvalData: async () => null });
    expect(result.tesslTiles).toHaveLength(1);
    expect(result.tesslTiles[0].eval).toBeNull();
    expect(result.tesslTiles[0].name).toBe('tessl/npm-express');
    expect(result.tesslTiles[0].version).toBe('5.1.0');
  });
});

// fetchTesslEvalData unit tests
describe('fetchTesslEvalData', () => {
  let execSpy;

  beforeEach(() => {
    invalidateEvalCache();
  });

  afterEach(() => {
    if (execSpy) execSpy.mockRestore();
  });

  test('returns eval data from completed eval run', async () => {
    const listResponse = JSON.stringify({
      data: [{
        id: 'eval-run-001',
        type: 'eval-run',
        attributes: { status: 'completed' }
      }]
    });

    const viewResponse = JSON.stringify({
      data: {
        attributes: {
          scenarios: [{
            solutions: [
              {
                variant: 'baseline',
                assessmentResults: [
                  { name: 'check-1', score: 5, max_score: 10 },
                  { name: 'check-2', score: 0, max_score: 10 }
                ]
              },
              {
                variant: 'usage-spec',
                assessmentResults: [
                  { name: 'check-1', score: 10, max_score: 10 },
                  { name: 'check-2', score: 8, max_score: 10 }
                ]
              }
            ]
          }]
        }
      }
    });

    let callCount = 0;
    execSpy = jest.spyOn(childProcess, 'exec').mockImplementation((cmd, opts, cb) => {
      if (typeof opts === 'function') { cb = opts; opts = {}; }
      callCount++;
      if (callCount === 1) {
        // eval list call
        cb(null, { stdout: listResponse, stderr: '' });
      } else {
        // eval view call
        cb(null, { stdout: viewResponse, stderr: '' });
      }
      return { on: () => {} };
    });

    const result = await fetchTesslEvalData('tessl/npm-express');
    expect(result).not.toBeNull();
    expect(result.score).toBe(90); // (10+8)/(10+10) = 90%
    expect(result.chartData.pass).toBe(1); // check-1 got full marks
    expect(result.chartData.fail).toBe(1); // check-2 got partial
    expect(result.multiplier).toBeCloseTo(3.6, 1); // 18/5 = 3.6
  });

  test('returns null when no eval runs exist', async () => {
    const listResponse = JSON.stringify({ data: [] });

    execSpy = jest.spyOn(childProcess, 'exec').mockImplementation((cmd, opts, cb) => {
      if (typeof opts === 'function') { cb = opts; opts = {}; }
      cb(null, { stdout: listResponse, stderr: '' });
      return { on: () => {} };
    });

    const result = await fetchTesslEvalData('tessl/npm-express');
    expect(result).toBeNull();
  });

  test('returns null when eval run is not completed', async () => {
    const listResponse = JSON.stringify({
      data: [{
        id: 'eval-run-001',
        attributes: { status: 'pending' }
      }]
    });

    execSpy = jest.spyOn(childProcess, 'exec').mockImplementation((cmd, opts, cb) => {
      if (typeof opts === 'function') { cb = opts; opts = {}; }
      cb(null, { stdout: listResponse, stderr: '' });
      return { on: () => {} };
    });

    const result = await fetchTesslEvalData('tessl/npm-express');
    expect(result).toBeNull();
  });

  test('returns null when tessl CLI fails', async () => {
    execSpy = jest.spyOn(childProcess, 'exec').mockImplementation((cmd, opts, cb) => {
      if (typeof opts === 'function') { cb = opts; opts = {}; }
      cb(new Error('command not found: tessl'));
      return { on: () => {} };
    });

    const result = await fetchTesslEvalData('tessl/npm-express');
    expect(result).toBeNull();
  });
});

// TS-039, TS-040: classifyNodeTypes fallback
describe('classifyNodeTypes', () => {
  test('returns all default when no API key', async () => {
    const origKey = process.env.ANTHROPIC_API_KEY;
    delete process.env.ANTHROPIC_API_KEY;

    const result = await classifyNodeTypes(['Browser', 'Server']);
    expect(result['Browser']).toBe('default');
    expect(result['Server']).toBe('default');

    if (origKey) process.env.ANTHROPIC_API_KEY = origKey;
  });

  test('returns all default for empty labels', async () => {
    const result = await classifyNodeTypes([]);
    expect(result).toEqual({});
  });
});
