'use strict';

const fs = require('fs');
const path = require('path');
const { parseBugs, parseTasks } = require('./parser');

const SEVERITY_ORDER = { critical: 0, high: 1, medium: 2, low: 3 };

/**
 * Resolve a GitHub issue reference like "#13" to a full URL.
 *
 * @param {string|null} issueRef - Issue reference (e.g., "#13") or null
 * @param {string|null} repoUrl - Repository URL from git remote or null
 * @returns {string|null} Full URL or null
 */
function resolveGitHubIssueUrl(issueRef, repoUrl) {
  if (!issueRef || !repoUrl) return null;

  // Skip sentinel values
  if (/^_\(/.test(issueRef)) return null;

  // Extract issue number
  const numMatch = issueRef.match(/#(\d+)/);
  if (!numMatch) return null;

  const issueNumber = numMatch[1];

  // Normalize repo URL
  let baseUrl = repoUrl;

  // Handle SSH format: git@github.com:user/repo.git
  const sshMatch = baseUrl.match(/^git@([^:]+):(.+?)(?:\.git)?$/);
  if (sshMatch) {
    baseUrl = `https://${sshMatch[1]}/${sshMatch[2]}`;
  }

  // Strip trailing .git
  baseUrl = baseUrl.replace(/\.git$/, '');

  return `${baseUrl}/issues/${issueNumber}`;
}

/**
 * Compute the bugs state for a feature.
 * Reads bugs.md and tasks.md, cross-references fix tasks by [BUG-NNN] tag.
 *
 * @param {string} projectPath - Path to the project root
 * @param {string} featureId - Feature directory name (e.g., "009-bugs-tab")
 * @returns {{exists: boolean, bugs: Array, orphanedTasks: Array, summary: Object, repoUrl: string|null}}
 */
function computeBugsState(projectPath, featureId) {
  const featureDir = path.join(projectPath, 'specs', featureId);
  const bugsPath = path.join(featureDir, 'bugs.md');
  const tasksPath = path.join(featureDir, 'tasks.md');

  const emptySummary = {
    total: 0,
    open: 0,
    fixed: 0,
    highestOpenSeverity: null,
    bySeverity: { critical: 0, high: 0, medium: 0, low: 0 }
  };

  if (!fs.existsSync(bugsPath)) {
    return { exists: false, bugs: [], orphanedTasks: [], summary: emptySummary, repoUrl: null };
  }

  const bugsContent = fs.readFileSync(bugsPath, 'utf-8');
  const bugs = parseBugs(bugsContent);

  // Parse tasks for fix task cross-referencing
  const tasksContent = fs.existsSync(tasksPath) ? fs.readFileSync(tasksPath, 'utf-8') : '';
  const allTasks = parseTasks(tasksContent);
  const bugFixTasks = allTasks.filter(t => t.isBugFix && t.bugTag);

  // Build lookup: BUG-NNN -> [task, ...]
  const tasksByBug = {};
  for (const task of bugFixTasks) {
    if (!tasksByBug[task.bugTag]) tasksByBug[task.bugTag] = [];
    tasksByBug[task.bugTag].push(task);
  }

  // Track which bug IDs exist
  const bugIds = new Set(bugs.map(b => b.id));

  // Enrich bugs with fix tasks
  for (const bug of bugs) {
    const tasks = tasksByBug[bug.id] || [];
    bug.fixTasks = {
      total: tasks.length,
      checked: tasks.filter(t => t.checked).length,
      tasks: tasks.map(t => ({
        id: t.id,
        description: t.description,
        checked: t.checked
      }))
    };
  }

  // Sort bugs: severity descending (critical first), then ID ascending
  bugs.sort((a, b) => {
    const sevA = SEVERITY_ORDER[a.severity] !== undefined ? SEVERITY_ORDER[a.severity] : 3;
    const sevB = SEVERITY_ORDER[b.severity] !== undefined ? SEVERITY_ORDER[b.severity] : 3;
    const sevDiff = sevA - sevB;
    if (sevDiff !== 0) return sevDiff;
    return a.id.localeCompare(b.id);
  });

  // Detect orphaned tasks (T-B tasks referencing non-existent BUG-NNN)
  const orphanedTasks = bugFixTasks
    .filter(t => !bugIds.has(t.bugTag))
    .map(t => ({ id: t.id, bugTag: t.bugTag, description: t.description, checked: t.checked }));

  // Compute summary
  const openBugs = bugs.filter(b => b.status !== 'fixed');
  const fixedBugs = bugs.filter(b => b.status === 'fixed');

  const bySeverity = { critical: 0, high: 0, medium: 0, low: 0 };
  for (const bug of openBugs) {
    if (bySeverity.hasOwnProperty(bug.severity)) {
      bySeverity[bug.severity]++;
    }
  }

  let highestOpenSeverity = null;
  for (const sev of ['critical', 'high', 'medium', 'low']) {
    if (bySeverity[sev] > 0) {
      highestOpenSeverity = sev;
      break;
    }
  }

  // Try to get repo URL from git remote
  let repoUrl = null;
  try {
    const { execSync } = require('child_process');
    repoUrl = execSync('git remote get-url origin', {
      cwd: projectPath,
      encoding: 'utf-8',
      stdio: ['pipe', 'pipe', 'pipe']
    }).trim();
    // Strip .git suffix
    repoUrl = repoUrl.replace(/\.git$/, '');
    // Handle SSH format
    const sshMatch = repoUrl.match(/^git@([^:]+):(.+)$/);
    if (sshMatch) {
      repoUrl = `https://${sshMatch[1]}/${sshMatch[2]}`;
    }
  } catch {
    // No git remote — repoUrl stays null
  }

  return {
    exists: true,
    bugs,
    orphanedTasks,
    summary: {
      total: bugs.length,
      open: openBugs.length,
      fixed: fixedBugs.length,
      highestOpenSeverity,
      bySeverity
    },
    repoUrl
  };
}

module.exports = { computeBugsState, resolveGitHubIssueUrl };
