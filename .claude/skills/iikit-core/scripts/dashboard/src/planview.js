'use strict';

const fs = require('fs');
const path = require('path');
const childProcess = require('child_process');
const { promisify } = require('util');
const { parseTechContext, parseFileStructure, parseAsciiDiagram, parseTesslJson, parseResearchDecisions } = require('./parser');

module.exports = { computePlanViewState, classifyNodeTypes, fetchTesslEvalData };


/**
 * Compute plan view state from parsed plan.md data.
 * Follows the same pattern as board.js and storymap.js.
 *
 * @param {string} projectPath - Path to project root
 * @param {string} featureId - Feature directory name
 * @param {Object} [options] - Optional configuration
 * @param {Function} [options.fetchEvalData] - Custom eval data fetcher (for testing)
 * @returns {Promise<Object>} Plan view state
 */
async function computePlanViewState(projectPath, featureId, options = {}) {
  const evalFetcher = options.fetchEvalData || fetchTesslEvalData;
  const featureDir = path.join(projectPath, 'specs', featureId);
  const planPath = path.join(featureDir, 'plan.md');

  if (!fs.existsSync(planPath)) {
    return {
      techContext: [],
      researchDecisions: [],
      fileStructure: null,
      diagram: null,
      tesslTiles: [],
      exists: false,
    };
  }

  const planContent = fs.readFileSync(planPath, 'utf-8');

  // Parse tech context
  const techContext = parseTechContext(planContent);

  // Parse research decisions for tooltips
  const researchPath = path.join(featureDir, 'research.md');
  let researchDecisions = [];
  if (fs.existsSync(researchPath)) {
    const researchContent = fs.readFileSync(researchPath, 'utf-8');
    researchDecisions = parseResearchDecisions(researchContent);
  }

  // Parse file structure and check existence
  let fileStructure = parseFileStructure(planContent);
  if (fileStructure) {
    fileStructure.entries = fileStructure.entries.map(entry => {
      const filePath = buildFilePath(fileStructure.entries, entry, fileStructure.rootName);
      const fullPath = path.join(projectPath, filePath);
      return { ...entry, exists: fs.existsSync(fullPath) };
    });
  }

  // Parse ASCII diagram
  let diagram = parseAsciiDiagram(planContent);
  if (diagram && diagram.nodes.length > 0) {
    // Read pre-computed node classifications from context.json (written by /iikit-02-plan)
    let types = {};
    const contextPath = path.join(projectPath, '.specify', 'context.json');
    if (fs.existsSync(contextPath)) {
      try {
        const ctx = JSON.parse(fs.readFileSync(contextPath, 'utf-8'));
        if (ctx.planview && ctx.planview.nodeClassifications) {
          types = ctx.planview.nodeClassifications;
        }
      } catch { /* malformed context.json */ }
    }

    diagram.nodes = diagram.nodes.map(n => ({
      ...n,
      type: types[n.label] || 'default'
    }));
  }

  // Parse tessl.json and enrich with eval + review data
  const tesslTiles = parseTesslJson(projectPath);
  const [evalResults, reviewScores] = await Promise.all([
    Promise.all(tesslTiles.map(tile => evalFetcher(tile.name).catch(() => null))),
    fetchTesslReviewScores(tesslTiles.map(t => t.name)).catch(() => ({}))
  ]);
  tesslTiles.forEach((tile, i) => {
    tile.eval = evalResults[i];
    tile.reviewScore = reviewScores[tile.name] ?? null;
  });

  return {
    techContext,
    researchDecisions,
    fileStructure,
    diagram,
    tesslTiles,
    exists: true,
  };
}

/**
 * Build file path from tree entries by walking up the depth chain.
 */
function buildFilePath(entries, targetEntry, rootName) {
  const idx = entries.indexOf(targetEntry);
  const parts = [targetEntry.name];
  let currentDepth = targetEntry.depth;

  // Walk backwards to find all parent directories
  for (let i = idx - 1; i >= 0; i--) {
    if (entries[i].depth < currentDepth && entries[i].type === 'directory') {
      parts.unshift(entries[i].name);
      currentDepth = entries[i].depth;
      if (currentDepth === 0) break;
    }
  }

  // If entry is at depth 0 and has no directory parent, prepend rootName
  if (currentDepth === 0 && rootName && parts[0] !== rootName) {
    // Check if the entry is NOT under a different depth-0 directory
    // (i.e., it belongs to the rootName section)
    let hasDepth0DirParent = false;
    for (let i = idx - 1; i >= 0; i--) {
      if (entries[i].depth === 0 && entries[i].type === 'directory') {
        hasDepth0DirParent = true;
        break;
      }
    }
    if (!hasDepth0DirParent) {
      parts.unshift(rootName);
    }
  }

  return parts.join('/');
}

/**
 * Classify diagram node labels into component types.
 * Node classifications are pre-computed by /iikit-02-plan and stored in context.json.
 * This function is a no-op stub kept for backward compatibility.
 *
 * @param {string[]} labels - Node labels to classify
 * @returns {Promise<Object>} Mapping of label -> "default"
 */
async function classifyNodeTypes(labels) {
  const result = {};
  for (const label of labels) result[label] = 'default';
  return result;
}

/**
 * Fetch review scores for tiles by parsing `tessl search` output.
 * Batches all tile names into individual searches (tessl search has no batch mode).
 *
 * @param {string[]} tileNames - Tile names to look up
 * @returns {Promise<Object>} Mapping of tileName -> score (number) or null
 */
async function fetchTesslReviewScores(tileNames) {
  if (!tileNames || tileNames.length === 0) return {};

  try {
    const execAsync = promisify(childProcess.exec);
    // Check tessl is available
    await execAsync('command -v tessl', { timeout: 2000 });

    const results = {};
    await Promise.all(tileNames.map(async (name) => {
      try {
        const { stdout } = await execAsync(`tessl search "${name}"`, { timeout: 10000 });
        // Parse: "name | score | version [type]" — score is a number or "- ⧗-"
        const escapedName = name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
        const match = stdout.match(new RegExp(`${escapedName}\\s*\\|\\s*(\\d+|[^|]+)\\s*\\|`));
        if (match) {
          const scoreStr = match[1].trim();
          const score = parseInt(scoreStr, 10);
          results[name] = isNaN(score) ? null : score;
        } else {
          results[name] = null;
        }
      } catch {
        results[name] = null;
      }
    }));
    return results;
  } catch {
    return {};
  }
}

// In-memory cache for eval data per tile name
const evalCache = new Map();

/**
 * Fetch eval data for a Tessl tile using the tessl CLI.
 * Returns structured eval data or null if unavailable.
 *
 * @param {string} tileName - Tile name (e.g., "tessl/npm-express")
 * @returns {Promise<{score: number, multiplier: number, chartData: {pass: number, fail: number}}|null>}
 */
async function fetchTesslEvalData(tileName) {
  if (evalCache.has(tileName)) return evalCache.get(tileName);

  try {
    const execAsync = promisify(childProcess.exec);

    // List eval runs for the tile
    const { stdout: listOut } = await execAsync(
      `tessl eval list --json --tile "${tileName}" --limit 1`,
      { timeout: 10000 }
    );
    const listJson = JSON.parse(listOut.substring(listOut.indexOf('{')));

    if (!listJson.data || listJson.data.length === 0) {
      evalCache.set(tileName, null);
      return null;
    }

    // Find the most recent completed eval run
    const completedRun = listJson.data.find(r => r.attributes && r.attributes.status === 'completed');
    if (!completedRun) {
      evalCache.set(tileName, null);
      return null;
    }

    // Fetch detailed eval results
    const { stdout: viewOut } = await execAsync(
      `tessl eval view --json ${completedRun.id}`,
      { timeout: 15000 }
    );
    const viewJson = JSON.parse(viewOut.substring(viewOut.indexOf('{')));

    const evalData = computeEvalSummary(viewJson.data);
    evalCache.set(tileName, evalData);
    return evalData;
  } catch {
    evalCache.set(tileName, null);
    return null;
  }
}

/**
 * Compute eval summary from a detailed eval run response.
 * Extracts score, multiplier, and pass/fail chart data from scenarios.
 */
function computeEvalSummary(evalRun) {
  if (!evalRun || !evalRun.attributes || !evalRun.attributes.scenarios) return null;

  let usageTotal = 0, usageMax = 0, baselineTotal = 0;
  let pass = 0, fail = 0;

  for (const scenario of evalRun.attributes.scenarios) {
    if (!scenario.solutions) continue;

    const usageSpec = scenario.solutions.find(s => s.variant === 'usage-spec');
    const baseline = scenario.solutions.find(s => s.variant === 'baseline');

    if (usageSpec && usageSpec.assessmentResults) {
      for (const r of usageSpec.assessmentResults) {
        usageTotal += r.score;
        usageMax += r.max_score;
        if (r.score === r.max_score) pass++;
        else fail++;
      }
    }

    if (baseline && baseline.assessmentResults) {
      for (const r of baseline.assessmentResults) {
        baselineTotal += r.score;
      }
    }
  }

  if (usageMax === 0) return null;

  const score = Math.round(usageTotal / usageMax * 100);
  const multiplier = baselineTotal > 0
    ? Math.round(usageTotal / baselineTotal * 100) / 100
    : null;

  return { score, multiplier, chartData: { pass, fail } };
}

/**
 * Invalidate eval cache (e.g., when tessl.json changes).
 */
function invalidateEvalCache() {
  evalCache.clear();
}

module.exports.invalidateEvalCache = invalidateEvalCache;

