'use strict';

const fs = require('fs');
const path = require('path');
const {
  parseAnalysisFindings,
  parseAnalysisCoverage,
  parseAnalysisMetrics,
  parseConstitutionAlignment,
  parsePhaseSeparation,
  parseRequirements,
  parseSuccessCriteria
} = require('./parser');

const SEVERITY_PENALTIES = { CRITICAL: 25, HIGH: 15, MEDIUM: 5, LOW: 2 };

/**
 * Compute phase separation score from violation entries.
 * Score = max(0, 100 - sum(penalties)).
 *
 * @param {Array<{severity: string}>} violations
 * @returns {number}
 */
function computePhaseSeparationScore(violations) {
  if (!violations || violations.length === 0) return 100;

  const penalty = violations.reduce((sum, v) => {
    return sum + (SEVERITY_PENALTIES[v.severity] || 0);
  }, 0);

  return Math.max(0, 100 - penalty);
}

/**
 * Compute constitution compliance percentage from alignment entries.
 * (ALIGNED count / total) * 100, rounded.
 *
 * @param {Array<{status: string}>} entries
 * @returns {number}
 */
function computeConstitutionCompliance(entries) {
  if (!entries || entries.length === 0) return 100;

  const aligned = entries.filter(e => e.status === 'ALIGNED').length;
  return Math.round((aligned / entries.length) * 100);
}

/**
 * Compute health score from four factors (25% each).
 *
 * @param {{requirementsCoverage: number, constitutionCompliance: number, phaseSeparation: number, testCoverage: number}} factors
 * @returns {{score: number, zone: string, factors: Object}}
 */
function computeHealthScore(factors) {
  const { requirementsCoverage, constitutionCompliance, phaseSeparation, testCoverage } = factors;

  const score = Math.round(
    (requirementsCoverage + constitutionCompliance + phaseSeparation + testCoverage) / 4
  );

  let zone;
  if (score <= 40) zone = 'red';
  else if (score <= 70) zone = 'yellow';
  else zone = 'green';

  return {
    score,
    zone,
    factors: {
      requirementsCoverage: { value: requirementsCoverage, label: 'Requirements Coverage' },
      constitutionCompliance: { value: constitutionCompliance, label: 'Constitution Compliance' },
      phaseSeparation: { value: phaseSeparation, label: 'Phase Separation' },
      testCoverage: { value: testCoverage, label: 'Test Coverage' }
    }
  };
}

/**
 * Map a coverage entry to a cell status object.
 *
 * @param {boolean} hasArtifact
 * @param {string[]} ids
 * @param {string|null} statusStr - e.g., "Partial", "Full"
 * @returns {{status: string, refs: string[]}}
 */
function mapCellStatus(hasArtifact, ids, statusStr) {
  if (statusStr && /partial/i.test(statusStr)) {
    return { status: 'partial', refs: ids || [] };
  }
  if (hasArtifact && ids && ids.length > 0) {
    return { status: 'covered', refs: ids };
  }
  if (!hasArtifact || !ids || ids.length === 0) {
    return { status: 'missing', refs: [] };
  }
  return { status: 'covered', refs: ids };
}

/**
 * Build heatmap rows from requirements and coverage data.
 *
 * @param {Array<{id: string, text: string}>} requirements
 * @param {Array} coverageEntries
 * @returns {Array<{id: string, text: string, cells: Object}>}
 */
function buildHeatmapRows(requirements, coverageEntries) {
  if (!requirements || requirements.length === 0) return [];

  const coverageMap = {};
  for (const entry of (coverageEntries || [])) {
    coverageMap[entry.id] = entry;
  }

  return requirements.map(req => {
    const coverage = coverageMap[req.id];
    if (!coverage) {
      return {
        id: req.id,
        text: req.text,
        cells: {
          tasks: { status: 'missing', refs: [] },
          tests: { status: 'missing', refs: [] },
          plan: { status: 'na', refs: [] }
        }
      };
    }

    return {
      id: req.id,
      text: req.text,
      cells: {
        tasks: mapCellStatus(coverage.hasTask, coverage.taskIds, coverage.status === 'Partial' && !coverage.hasTask ? 'Partial' : null),
        tests: mapCellStatus(coverage.hasTest, coverage.testIds, null),
        plan: coverage.hasPlan !== undefined
          ? mapCellStatus(coverage.hasPlan, coverage.planRefs, null)
          : { status: 'na', refs: [] }
      }
    };
  });
}

/**
 * Compute the full analyze view state for a feature.
 *
 * @param {string} projectPath
 * @param {string} featureId
 * @returns {Object}
 */
function computeAnalyzeState(projectPath, featureId) {
  const featureDir = path.join(projectPath, 'specs', featureId);
  const analysisPath = path.join(featureDir, 'analysis.md');
  const specPath = path.join(featureDir, 'spec.md');

  if (!fs.existsSync(analysisPath)) {
    return {
      healthScore: null,
      heatmap: { columns: [], rows: [] },
      issues: [],
      metrics: null,
      constitutionAlignment: [],
      exists: false
    };
  }

  const analysisContent = fs.readFileSync(analysisPath, 'utf-8');
  const specContent = fs.existsSync(specPath) ? fs.readFileSync(specPath, 'utf-8') : '';

  // Parse all sections
  const findings = parseAnalysisFindings(analysisContent);
  const coverage = parseAnalysisCoverage(analysisContent);
  const metrics = parseAnalysisMetrics(analysisContent);
  const constitutionAlignment = parseConstitutionAlignment(analysisContent);
  const phaseSeparationViolations = parsePhaseSeparation(analysisContent);

  // Build heatmap from spec requirements + coverage data
  const requirements = [
    ...parseRequirements(specContent),
    ...parseSuccessCriteria(specContent)
  ];
  const heatmapRows = buildHeatmapRows(requirements, coverage);

  // Compute health score factors
  const reqCovPct = metrics.requirementCoveragePct || 0;
  const testCovPct = metrics.testCoveragePct || 100;
  const constitutionCompliancePct = computeConstitutionCompliance(constitutionAlignment);
  const phaseSepScore = computePhaseSeparationScore(
    phaseSeparationViolations.filter(v => v.severity)
  );

  const healthScore = computeHealthScore({
    requirementsCoverage: reqCovPct,
    constitutionCompliance: constitutionCompliancePct,
    phaseSeparation: phaseSepScore,
    testCoverage: testCovPct
  });

  // Map findings to issues (API terminology)
  const issues = findings.map(f => ({
    id: f.id,
    category: f.category,
    severity: f.severity.toLowerCase(),
    location: f.location,
    summary: f.summary,
    recommendation: f.recommendation,
    resolved: f.resolved
  }));

  return {
    healthScore: {
      ...healthScore,
      trend: null
    },
    heatmap: {
      columns: ['tasks', 'tests', 'plan'],
      rows: heatmapRows
    },
    issues,
    metrics: {
      totalRequirements: metrics.totalRequirements,
      totalTasks: metrics.totalTasks,
      totalTestSpecs: metrics.totalTestSpecs,
      requirementCoverage: metrics.requirementCoverage,
      criticalIssues: metrics.criticalIssues,
      highIssues: metrics.highIssues,
      mediumIssues: metrics.mediumIssues,
      lowIssues: metrics.lowIssues
    },
    constitutionAlignment: constitutionAlignment.map(a => ({
      principle: a.principle,
      status: a.status,
      evidence: a.evidence
    })),
    exists: true
  };
}

module.exports = {
  computeHealthScore,
  computeAnalyzeState,
  buildHeatmapRows,
  mapCellStatus,
  computePhaseSeparationScore,
  computeConstitutionCompliance
};
