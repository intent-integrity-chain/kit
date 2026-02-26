#!/usr/bin/env node
'use strict';

const path = require('path');
const fs = require('fs');

const { parseSpecStories, parseTasks, parseConstitutionPrinciples, parsePremise } = require('./parser');
const { computeBoardState } = require('./board');
const { computeAssertionHash, checkIntegrity } = require('./integrity');
const { computePipelineState } = require('./pipeline');
const { computeStoryMapState } = require('./storymap');
const { computePlanViewState } = require('./planview');
const { computeChecklistViewState } = require('./checklist');
const { computeTestifyState, getFeatureFiles } = require('./testify');
const { computeAnalyzeState } = require('./analyze');
const { computeBugsState } = require('./bugs');

/**
 * List features from specs/ directory.
 * A feature is a directory under specs/ that contains spec.md (FR-004).
 */
function listFeatures(projectPath) {
  const specsDir = path.join(projectPath, 'specs');
  if (!fs.existsSync(specsDir)) return [];

  const entries = fs.readdirSync(specsDir, { withFileTypes: true });
  const features = [];

  for (const entry of entries) {
    if (!entry.isDirectory()) continue;
    const featureDir = path.join(specsDir, entry.name);
    const specPath = path.join(featureDir, 'spec.md');
    if (!fs.existsSync(specPath)) continue;

    const tasksPath = path.join(featureDir, 'tasks.md');
    const specContent = fs.readFileSync(specPath, 'utf-8');
    const tasksContent = fs.existsSync(tasksPath) ? fs.readFileSync(tasksPath, 'utf-8') : '';
    const stories = parseSpecStories(specContent);
    const tasks = parseTasks(tasksContent);

    const checkedCount = tasks.filter(t => t.checked).length;
    const totalCount = tasks.length;

    const namePart = entry.name.replace(/^\d+-/, '');
    const name = namePart.split('-').map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(' ');

    features.push({
      id: entry.name,
      name,
      stories: stories.length,
      progress: `${checkedCount}/${totalCount}`
    });
  }

  return features.reverse();
}

/**
 * Compute board state with integrity for a feature.
 */
function getBoardState(projectPath, featureId) {
  const featureDir = path.join(projectPath, 'specs', featureId);
  const specPath = path.join(featureDir, 'spec.md');
  const tasksPath = path.join(featureDir, 'tasks.md');
  const contextPath = path.join(featureDir, 'context.json');

  const specContent = fs.existsSync(specPath) ? fs.readFileSync(specPath, 'utf-8') : '';
  const tasksContent = fs.existsSync(tasksPath) ? fs.readFileSync(tasksPath, 'utf-8') : '';

  const stories = parseSpecStories(specContent);
  const tasks = parseTasks(tasksContent);
  const board = computeBoardState(stories, tasks);

  let integrity = { status: 'missing', currentHash: null, storedHash: null };
  const featureFiles = getFeatureFiles(featureDir);
  if (featureFiles.length > 0) {
    const allFeatureContent = featureFiles.map(f => fs.readFileSync(f, 'utf-8')).join('\n');
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

  return { ...board, integrity };
}

/**
 * Assemble DASHBOARD_DATA for all features.
 */
async function assembleDashboardData(projectPath) {
  const resolvedPath = path.resolve(projectPath);
  const features = listFeatures(resolvedPath);
  const constitution = parseConstitutionPrinciples(resolvedPath);
  const premise = parsePremise(resolvedPath);

  const featureData = {};
  for (const feature of features) {
    const fid = feature.id;
    try {
      featureData[fid] = {
        board: getBoardState(resolvedPath, fid),
        pipeline: computePipelineState(resolvedPath, fid),
        storyMap: computeStoryMapState(resolvedPath, fid),
        planView: await computePlanViewState(resolvedPath, fid),
        checklist: computeChecklistViewState(resolvedPath, fid),
        testify: computeTestifyState(resolvedPath, fid),
        analyze: computeAnalyzeState(resolvedPath, fid),
        bugs: computeBugsState(resolvedPath, fid)
      };
    } catch (err) {
      process.stderr.write(`Error: Parser failed on specs/${fid}/spec.md: ${err.message}. Check artifact syntax.\n`);
      process.exit(5);
    }
  }

  return {
    meta: {
      projectPath: resolvedPath,
      generatedAt: new Date().toISOString()
    },
    features,
    constitution,
    premise,
    featureData
  };
}

/**
 * Inject data into HTML template and return the complete HTML string.
 */
function buildHtml(templateHtml, dashboardData) {
  let html = templateHtml;

  // Inject DASHBOARD_DATA into <head> (FR-004, FR-005)
  // DASHBOARD_DATA must be in <head> so it's available before the IIFE in <body> runs
  // Escape </script> to prevent script-tag injection from data file content (SC-008)
  const safeJson = JSON.stringify(dashboardData).replace(/<\/script>/gi, '<\\/script>');
  const headInject = `  <script>window.DASHBOARD_DATA = ${safeJson};</script>\n`;
  html = html.replace('</head>', headInject + '</head>');

  // No auto-reload — it destroys user interaction (expanded cards, scroll position).
  // Dashboard is regenerated by generate-dashboard-safe.sh after each skill invocation.
  // User refreshes manually (F5) or clicks the refresh button in the header.

  return html;
}

/**
 * Write HTML atomically: write to .tmp then rename (FR-011).
 */
function writeAtomic(outputPath, content) {
  const dir = path.dirname(outputPath);
  fs.mkdirSync(dir, { recursive: true });

  const tmpPath = outputPath + '.tmp';
  fs.writeFileSync(tmpPath, content, 'utf-8');
  fs.renameSync(tmpPath, outputPath);
}

// Template HTML — loaded from template.js (published) or public/index.html (dev)
let _cachedTemplate = null;
function loadTemplate() {
  if (_cachedTemplate) return _cachedTemplate;
  // Try template.js first (published tiles)
  const templateJs = path.join(__dirname, '..', 'template.js');
  if (fs.existsSync(templateJs)) {
    _cachedTemplate = require(templateJs);
    return _cachedTemplate;
  }
  // Fall back to public/index.html (dev layout)
  const templatePath = path.join(__dirname, 'public', 'index.html');
  if (fs.existsSync(templatePath)) {
    _cachedTemplate = fs.readFileSync(templatePath, 'utf-8');
    return _cachedTemplate;
  }
  throw new Error('Dashboard template not found. Checked: ' + templateJs + ', ' + templatePath);
}

/**
 * Run one generation cycle.
 */
async function generate(projectPath) {
  const resolvedPath = path.resolve(projectPath);
  const templateHtml = loadTemplate();

  const dashboardData = await assembleDashboardData(resolvedPath);

  // Size warning (SC-007)
  for (const feature of dashboardData.features) {
    const featureJson = JSON.stringify(dashboardData.featureData[feature.id] || {});
    if (featureJson.length > 500 * 1024) {
      const sizeMB = (featureJson.length / (1024 * 1024)).toFixed(1);
      process.stderr.write(`Warning: Feature ${feature.id}: large artifacts detected (${sizeMB} MB). Dashboard may load slowly.\n`);
    }
  }

  const html = buildHtml(templateHtml, dashboardData);
  const outputPath = path.join(resolvedPath, '.specify', 'dashboard.html');

  writeAtomic(outputPath, html);
  const now = new Date().toISOString().slice(0, 19).replace('T', ' ');
  process.stdout.write(`[${now}] Generated dashboard.html (${(html.length / 1024).toFixed(0)} KB)\n`);
}

/**
 * Main CLI entry point.
 */
async function main() {
  const args = process.argv.slice(2);

  if (args.length === 0) {
    process.stderr.write('Error: Project path is required. Usage: generate-dashboard.js <projectPath>\n');
    process.exit(1);
  }

  const projectPath = path.resolve(args[0]);

  // Validate project directory exists (exit 1)
  if (!fs.existsSync(projectPath) || !fs.statSync(projectPath).isDirectory()) {
    process.stderr.write(`Error: Project directory not found: ${projectPath}. Verify the path is correct.\n`);
    process.exit(1);
  }

  // Warn if CONSTITUTION.md missing but continue (dashboard still useful)
  const constitutionPath = path.join(projectPath, 'CONSTITUTION.md');
  if (!fs.existsSync(constitutionPath)) {
    process.stderr.write('Warning: CONSTITUTION.md not found in project root. Dashboard will show constitution as missing.\n');
  }

  // Check write permissions (exit 4)
  const specifyDir = path.join(projectPath, '.specify');
  try {
    fs.mkdirSync(specifyDir, { recursive: true });
    // Test write by creating and removing a temp file
    const testFile = path.join(specifyDir, '.write-test-' + process.pid);
    fs.writeFileSync(testFile, '');
    fs.unlinkSync(testFile);
  } catch (err) {
    process.stderr.write(`Error: Permission denied writing to .specify/dashboard.html. Check directory permissions.\n`);
    process.exit(4);
  }

  // Run generation
  try {
    await generate(projectPath);
  } catch (err) {
    process.stderr.write(`Error: ${err.message}\n`);
    process.exit(5);
  }
}

if (require.main === module) {
  main();
}

module.exports = { generate, assembleDashboardData, buildHtml, listFeatures, getBoardState };
