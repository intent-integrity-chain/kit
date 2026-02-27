'use strict';

const path = require('path');
const { parseChecklistsDetailed } = require('./parser');

/**
 * Map a percentage (0-100) to a color bracket.
 * @param {number} percentage
 * @returns {string} "red" | "yellow" | "green"
 */
function percentageToColor(percentage) {
  if (percentage <= 33) return 'red';
  if (percentage <= 66) return 'yellow';
  return 'green';
}

/**
 * Compute gate status from an array of file objects with percentage fields.
 * Uses worst-case precedence: red if any at 0%, yellow if all 1-99%, green if all 100%.
 *
 * @param {Array<{percentage: number}>} files
 * @returns {{status: string, level: string, label: string}}
 */
function computeGateStatus(files) {
  if (files.length === 0) {
    return { status: 'blocked', level: 'red', label: 'GATE: BLOCKED' };
  }

  const anyAtZero = files.some(f => f.percentage === 0);
  if (anyAtZero) {
    return { status: 'blocked', level: 'red', label: 'GATE: BLOCKED' };
  }

  const allComplete = files.every(f => f.percentage === 100);
  if (allComplete) {
    return { status: 'open', level: 'green', label: 'GATE: OPEN' };
  }

  return { status: 'blocked', level: 'yellow', label: 'GATE: BLOCKED' };
}

/**
 * Compute checklist view state for a feature.
 * Returns per-file detail with items, percentage, color, and aggregate gate status.
 *
 * @param {string} projectPath - Path to the project root
 * @param {string} featureId - Feature directory name (e.g., "001-kanban-board")
 * @returns {{files: Array, gate: {status: string, level: string, label: string}}}
 */
function computeChecklistViewState(projectPath, featureId) {
  const checklistDir = path.join(projectPath, 'specs', featureId, 'checklists');
  const parsed = parseChecklistsDetailed(checklistDir);

  const files = parsed.map(file => {
    const percentage = file.total > 0 ? Math.round((file.checked / file.total) * 100) : 0;
    return {
      ...file,
      percentage,
      color: percentageToColor(percentage)
    };
  });

  const gate = computeGateStatus(files);

  return { files, gate };
}

module.exports = { computeChecklistViewState };
