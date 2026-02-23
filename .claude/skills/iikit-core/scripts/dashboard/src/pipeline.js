'use strict';

const fs = require('fs');
const path = require('path');
const { parseTasks, parseChecklists, parseConstitutionTDD, hasClarifications } = require('./parser');
const { getFeatureFiles } = require('./testify');

/**
 * Compute pipeline phase states for a feature by examining artifacts on disk.
 *
 * @param {string} projectPath - Path to the project root
 * @param {string} featureId - Feature directory name (e.g., "001-kanban-board")
 * @returns {{phases: Array<{id: string, name: string, status: string, progress: string|null, optional: boolean}>}}
 */
function computePipelineState(projectPath, featureId) {
  const featureDir = path.join(projectPath, 'specs', featureId);
  const constitutionPath = path.join(projectPath, 'CONSTITUTION.md');
  const specPath = path.join(featureDir, 'spec.md');
  const planPath = path.join(featureDir, 'plan.md');
  const checklistDir = path.join(featureDir, 'checklists');
  const tasksPath = path.join(featureDir, 'tasks.md');

  const analysisPath = path.join(featureDir, 'analysis.md');

  const specExists = fs.existsSync(specPath);
  const planExists = fs.existsSync(planPath);
  const tasksExists = fs.existsSync(tasksPath);
  const testSpecsExists = getFeatureFiles(featureDir).length > 0;
  const constitutionExists = fs.existsSync(constitutionPath);
  const premiseExists = fs.existsSync(path.join(projectPath, 'PREMISE.md'));
  const analysisExists = fs.existsSync(analysisPath);

  // Read spec content for clarifications check
  const specContent = specExists ? fs.readFileSync(specPath, 'utf-8') : '';

  // Parse tasks for implement progress
  const tasksContent = tasksExists ? fs.readFileSync(tasksPath, 'utf-8') : '';
  const tasks = parseTasks(tasksContent);
  const checkedCount = tasks.filter(t => t.checked).length;
  const totalCount = tasks.length;

  // Parse checklists
  const checklistStatus = parseChecklists(checklistDir);

  // TDD requirement check
  const tddRequired = constitutionExists ? parseConstitutionTDD(constitutionPath) : false;

  const phases = [
    {
      id: 'constitution',
      name: premiseExists ? 'Premise &\nConstitution' : 'Constitution',
      status: constitutionExists ? 'complete' : 'not_started',
      progress: null,
      optional: false
    },
    {
      id: 'spec',
      name: 'Spec',
      status: specExists ? 'complete' : 'not_started',
      progress: null,
      optional: false
    },
    {
      id: 'clarify',
      name: 'Clarify',
      status: hasClarifications(specContent) ? 'complete' : (planExists && !hasClarifications(specContent) ? 'skipped' : 'not_started'),
      progress: null,
      optional: true
    },
    {
      id: 'plan',
      name: 'Plan',
      status: planExists ? 'complete' : 'not_started',
      progress: null,
      optional: false
    },
    {
      id: 'checklist',
      name: 'Checklist',
      status: checklistStatus.total === 0
        ? 'not_started'
        : checklistStatus.checked === checklistStatus.total
          ? 'complete'
          : 'in_progress',
      progress: checklistStatus.total > 0
        ? `${Math.round((checklistStatus.checked / checklistStatus.total) * 100)}%`
        : null,
      optional: false
    },
    {
      id: 'testify',
      name: 'Testify',
      status: testSpecsExists
        ? 'complete'
        : (!tddRequired && planExists ? 'skipped' : 'not_started'),
      progress: null,
      optional: !tddRequired
    },
    {
      id: 'tasks',
      name: 'Tasks',
      status: tasksExists ? 'complete' : 'not_started',
      progress: null,
      optional: false
    },
    {
      id: 'analyze',
      name: 'Analyze',
      status: analysisExists ? 'complete' : 'not_started',
      progress: null,
      optional: false
    },
    {
      id: 'implement',
      name: 'Implement',
      status: totalCount === 0 || checkedCount === 0
        ? 'not_started'
        : checkedCount === totalCount
          ? 'complete'
          : 'in_progress',
      progress: totalCount > 0 && checkedCount > 0
        ? `${Math.round((checkedCount / totalCount) * 100)}%`
        : null,
      optional: false
    }
  ];

  return { phases };
}

module.exports = { computePipelineState };
