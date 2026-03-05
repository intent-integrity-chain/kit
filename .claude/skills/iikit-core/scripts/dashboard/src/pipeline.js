'use strict';

const fs = require('fs');
const path = require('path');
const { parseTasks, parseChecklists, parseConstitutionTDD, hasClarifications, countClarifications, parseClarifications } = require('./parser');
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

  // Read plan content for clarifications check
  const planContent = planExists ? fs.readFileSync(planPath, 'utf-8') : '';

  // Parse tasks for implement progress
  const tasksContent = tasksExists ? fs.readFileSync(tasksPath, 'utf-8') : '';
  const tasks = parseTasks(tasksContent);
  const checkedCount = tasks.filter(t => t.checked).length;
  const totalCount = tasks.length;

  // Read context.json for phase metadata
  const contextPath = path.join(projectPath, '.specify', 'context.json');
  let ctx = {};
  if (fs.existsSync(contextPath)) {
    try { ctx = JSON.parse(fs.readFileSync(contextPath, 'utf-8')); } catch { /* malformed */ }
  }

  // TDD requirement check
  let tddRequired = false;
  if (ctx.tdd_determination) {
    tddRequired = ctx.tdd_determination === 'mandatory';
  } else {
    tddRequired = constitutionExists ? parseConstitutionTDD(constitutionPath) : false;
  }

  // Checklist phase was run (not just requirements.md from specify)
  const checklistReviewed = !!ctx.checklist_reviewed_at;

  // Parse checklists (include requirements.md only after checklist phase was run)
  const checklistStatus = parseChecklists(checklistDir, { includeRequirements: checklistReviewed });

  // Read constitution content for clarifications check
  const constitutionContent = constitutionExists ? fs.readFileSync(constitutionPath, 'utf-8') : '';

  // Read checklist content for clarifications check
  let checklistContent = '';
  if (fs.existsSync(checklistDir)) {
    const clFiles = fs.readdirSync(checklistDir).filter(f => f.endsWith('.md'));
    checklistContent = clFiles.map(f => fs.readFileSync(path.join(checklistDir, f), 'utf-8')).join('\n');
  }

  // Read analysis content for clarifications check
  const analysisContent = analysisExists ? fs.readFileSync(analysisPath, 'utf-8') : '';

  // Read testify clarifications from companion markdown file (not .feature files — Gherkin can't hold markdown)
  const testifyClarificationsPath = path.join(featureDir, 'tests', 'clarifications.md');
  let testifyContent = '';
  if (fs.existsSync(testifyClarificationsPath)) {
    testifyContent = fs.readFileSync(testifyClarificationsPath, 'utf-8');
  }

  // Count and parse clarification items per artifact
  const clarifications = {
    constitution: countClarifications(constitutionContent),
    spec: countClarifications(specContent),
    plan: countClarifications(planContent),
    checklist: countClarifications(checklistContent),
    testify: countClarifications(testifyContent),
    tasks: countClarifications(tasksContent),
    analysis: countClarifications(analysisContent)
  };

  // Parse full Q&A entries per artifact for the clarify panel
  const clarificationEntries = {
    constitution: parseClarifications(constitutionContent),
    spec: parseClarifications(specContent),
    plan: parseClarifications(planContent),
    checklist: parseClarifications(checklistContent),
    testify: parseClarifications(testifyContent),
    tasks: parseClarifications(tasksContent),
    analysis: parseClarifications(analysisContent)
  };

  const phases = [
    {
      id: 'constitution',
      name: premiseExists ? 'Premise &\nConstitution' : 'Constitution',
      status: constitutionExists ? 'complete' : 'not_started',
      progress: null,
      optional: false,
      clarifications: clarifications.constitution,
      clarificationEntries: clarificationEntries.constitution
    },
    {
      id: 'spec',
      name: 'Spec',
      status: specExists ? 'complete' : 'not_started',
      progress: null,
      optional: false,
      clarifications: clarifications.spec,
      clarificationEntries: clarificationEntries.spec
    },
    {
      id: 'plan',
      name: 'Plan',
      status: planExists ? 'complete' : 'not_started',
      progress: null,
      optional: false,
      clarifications: clarifications.plan,
      clarificationEntries: clarificationEntries.plan
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
      optional: false,
      clarifications: clarifications.checklist,
      clarificationEntries: clarificationEntries.checklist
    },
    {
      id: 'testify',
      name: 'Testify',
      status: testSpecsExists
        ? 'complete'
        : (!tddRequired && planExists ? 'skipped' : 'not_started'),
      progress: null,
      optional: !tddRequired,
      clarifications: clarifications.testify,
      clarificationEntries: clarificationEntries.testify
    },
    {
      id: 'tasks',
      name: 'Tasks',
      status: tasksExists ? 'complete' : 'not_started',
      progress: null,
      optional: false,
      clarifications: 0,
      clarificationEntries: []
    },
    {
      id: 'analyze',
      name: 'Analyze',
      status: analysisExists ? 'complete' : 'not_started',
      progress: null,
      optional: false,
      clarifications: clarifications.analysis,
      clarificationEntries: clarificationEntries.analysis
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
      optional: false,
      clarifications: clarifications.tasks,
      clarificationEntries: clarificationEntries.tasks
    }
  ];

  return { phases };
}

module.exports = { computePipelineState };
