'use strict';

const path = require('path');
const fs = require('fs');
const { parseRequirements, parseSuccessCriteria, parseTestSpecs, parseTasks, parseTaskTestRefs } = require('./parser');
const { computeAssertionHash, checkIntegrity } = require('./integrity');

/**
 * Get sorted list of .feature file paths in a feature's tests/features/ directory.
 *
 * @param {string} featureDir - Path to the feature directory (e.g., specs/001-auth)
 * @returns {string[]} Sorted absolute paths to .feature files
 */
function getFeatureFiles(featureDir) {
  const featuresDir = path.join(featureDir, 'tests', 'features');
  if (!fs.existsSync(featuresDir)) return [];
  return fs.readdirSync(featuresDir)
    .filter(f => f.endsWith('.feature'))
    .sort()
    .map(f => path.join(featuresDir, f));
}

/**
 * Build edges between requirements, test specs, and tasks.
 * Only creates edges where both source and target nodes exist.
 *
 * @param {Array<{id: string}>} requirements
 * @param {Array<{id: string, traceability: string[]}>} testSpecs
 * @param {Object<string, string[]>} taskTestRefs - Map of taskId to testSpecIds
 * @returns {Array<{from: string, to: string, type: string}>}
 */
function buildEdges(requirements, testSpecs, taskTestRefs) {
  const edges = [];
  const reqIds = new Set(requirements.map(r => r.id));
  const tsIds = new Set(testSpecs.map(t => t.id));

  // requirement-to-test edges from traceability links
  for (const ts of testSpecs) {
    for (const reqId of ts.traceability) {
      if (reqIds.has(reqId)) {
        edges.push({ from: reqId, to: ts.id, type: 'requirement-to-test' });
      }
    }
  }

  // test-to-task edges from taskTestRefs
  for (const [taskId, tsRefs] of Object.entries(taskTestRefs)) {
    for (const tsId of tsRefs) {
      if (tsIds.has(tsId)) {
        edges.push({ from: tsId, to: taskId, type: 'test-to-task' });
      }
    }
  }

  return edges;
}

/**
 * Find gaps in the traceability chain.
 *
 * @param {Array<{id: string}>} requirements
 * @param {Array<{id: string}>} testSpecs
 * @param {Array<{from: string, to: string, type: string}>} edges
 * @returns {{untestedRequirements: string[], unimplementedTests: string[]}}
 */
function findGaps(requirements, testSpecs, edges) {
  const reqWithOutgoing = new Set(
    edges.filter(e => e.type === 'requirement-to-test').map(e => e.from)
  );
  const tsWithOutgoing = new Set(
    edges.filter(e => e.type === 'test-to-task').map(e => e.from)
  );

  return {
    untestedRequirements: requirements
      .map(r => r.id)
      .filter(id => !reqWithOutgoing.has(id)),
    unimplementedTests: testSpecs
      .map(t => t.id)
      .filter(id => !tsWithOutgoing.has(id))
  };
}

/**
 * Group test specs by type into pyramid tiers.
 *
 * @param {Array<{id: string, type: string}>} testSpecs
 * @returns {{acceptance: {count: number, ids: string[]}, contract: {count: number, ids: string[]}, validation: {count: number, ids: string[]}}}
 */
function buildPyramid(testSpecs) {
  const groups = { acceptance: [], contract: [], validation: [] };

  for (const ts of testSpecs) {
    if (groups[ts.type]) {
      groups[ts.type].push(ts.id);
    }
  }

  return {
    acceptance: { count: groups.acceptance.length, ids: groups.acceptance },
    contract: { count: groups.contract.length, ids: groups.contract },
    validation: { count: groups.validation.length, ids: groups.validation }
  };
}

/**
 * Compute the complete testify view state for a feature.
 *
 * @param {string} projectPath - Path to the project root
 * @param {string} featureId - Feature directory name
 * @returns {Object} TestifyViewState
 */
function computeTestifyState(projectPath, featureId) {
  const featureDir = path.join(projectPath, 'specs', featureId);
  const specPath = path.join(featureDir, 'spec.md');
  const tasksPath = path.join(featureDir, 'tasks.md');
  const contextPath = path.join(featureDir, 'context.json');

  const emptyState = {
    requirements: [],
    testSpecs: [],
    tasks: [],
    edges: [],
    gaps: { untestedRequirements: [], unimplementedTests: [] },
    pyramid: {
      acceptance: { count: 0, ids: [] },
      contract: { count: 0, ids: [] },
      validation: { count: 0, ids: [] }
    },
    integrity: { status: 'missing', currentHash: null, storedHash: null },
    exists: false
  };

  if (!fs.existsSync(featureDir)) return emptyState;

  // Parse requirements (FR-xxx and SC-xxx)
  const specContent = fs.existsSync(specPath) ? fs.readFileSync(specPath, 'utf-8') : '';
  const frReqs = parseRequirements(specContent);
  const scReqs = parseSuccessCriteria(specContent);
  const requirements = [...frReqs, ...scReqs];

  // Parse test specs from .feature files
  const featureFiles = getFeatureFiles(featureDir);
  const testSpecsExist = featureFiles.length > 0;
  const featureContents = featureFiles.map(f => fs.readFileSync(f, 'utf-8'));
  const allFeatureContent = featureContents.join('\n');
  const testSpecs = testSpecsExist
    ? featureContents.reduce((acc, content) => acc.concat(parseTestSpecs(content)), [])
    : [];

  // Parse tasks and extract test spec refs
  const tasksContent = fs.existsSync(tasksPath) ? fs.readFileSync(tasksPath, 'utf-8') : '';
  const rawTasks = parseTasks(tasksContent);
  const taskTestRefs = parseTaskTestRefs(rawTasks);
  const tasks = rawTasks.map(t => ({
    id: t.id,
    description: t.description,
    testSpecRefs: taskTestRefs[t.id] || []
  }));

  // Build edges, gaps, and pyramid
  const edges = buildEdges(requirements, testSpecs, taskTestRefs);
  const gaps = findGaps(requirements, testSpecs, edges);
  const pyramid = buildPyramid(testSpecs);

  // Integrity check
  let integrity = { status: 'missing', currentHash: null, storedHash: null };
  if (testSpecsExist) {
    const currentHash = computeAssertionHash(allFeatureContent);

    let storedHash = null;
    if (fs.existsSync(contextPath)) {
      try {
        const context = JSON.parse(fs.readFileSync(contextPath, 'utf-8'));
        storedHash = context?.testify?.assertion_hash || null;
      } catch {
        // malformed context.json
      }
    }

    integrity = checkIntegrity(currentHash, storedHash);
  }

  return {
    requirements,
    testSpecs,
    tasks,
    edges,
    gaps,
    pyramid,
    integrity,
    exists: testSpecsExist
  };
}

module.exports = { buildEdges, findGaps, buildPyramid, computeTestifyState, getFeatureFiles };
