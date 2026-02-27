'use strict';

const fs = require('fs');
const path = require('path');
const { parseSpecStories, parseRequirements, parseSuccessCriteria, parseClarifications, parseStoryRequirementRefs } = require('./parser');

/**
 * Compute story map state for a feature by parsing spec.md.
 *
 * @param {string} projectPath - Path to the project root
 * @param {string} featureId - Feature directory name
 * @returns {{stories: Array, requirements: Array, successCriteria: Array, clarifications: Array, edges: Array}}
 */
function computeStoryMapState(projectPath, featureId) {
  const featureDir = path.join(projectPath, 'specs', featureId);
  const specPath = path.join(featureDir, 'spec.md');

  if (!fs.existsSync(specPath)) {
    return { stories: [], requirements: [], successCriteria: [], clarifications: [], edges: [] };
  }

  const content = fs.readFileSync(specPath, 'utf-8');

  const rawStories = parseSpecStories(content);
  const requirements = parseRequirements(content);
  const successCriteria = parseSuccessCriteria(content);
  const clarifications = parseClarifications(content);
  const edges = parseStoryRequirementRefs(content);

  // Add clarificationCount to each story (global count per FR-010)
  const clarificationCount = clarifications.length;
  const stories = rawStories.map(s => ({
    ...s,
    clarificationCount
  }));

  return { stories, requirements, successCriteria, clarifications, edges };
}

module.exports = { computeStoryMapState };
