// @ts-check
const { test, expect } = require('@playwright/test');
const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');

let projectDir;
let dashboardPath;

test.beforeAll(() => {
  // Create a temp project with enough artifacts to generate a dashboard
  projectDir = fs.mkdtempSync(path.join(os.tmpdir(), 'iikit-dashboard-test-'));

  execSync('git init', { cwd: projectDir });
  execSync('git config user.email "test@test.com"', { cwd: projectDir });
  execSync('git config user.name "Test"', { cwd: projectDir });

  fs.mkdirSync(path.join(projectDir, 'specs', '001-test'), { recursive: true });
  fs.mkdirSync(path.join(projectDir, '.specify'), { recursive: true });

  fs.writeFileSync(path.join(projectDir, 'CONSTITUTION.md'), `# Constitution

## Core Principles

### I. Quality First
Code quality MUST be maintained at all times.

**Rationale**: Quality is non-negotiable.

**Version**: 1.0.0 | **Ratified**: 2026-02-22 | **Last Amended**: 2026-02-22
`);

  fs.writeFileSync(path.join(projectDir, 'specs', '001-test', 'spec.md'), `# Feature Specification: Test Feature

**Created**: 2026-02-22
**Status**: Draft

## User Scenarios & Testing

### User Story 1 - Login (Priority: P1)

As a user I want to log in.

**Acceptance Scenarios**:
1. **Given** a registered user, **When** they enter credentials, **Then** they are logged in.

## Requirements

- **FR-001**: Users MUST be able to log in
- **FR-002**: Login MUST validate credentials

## Success Criteria

- **SC-001**: Login works with valid credentials
`);

  // Generate the dashboard
  const generatorPath = path.resolve(__dirname, '../../.claude/skills/iikit-core/scripts/dashboard/generate-dashboard.js');
  execSync(`node "${generatorPath}" "${projectDir}"`, { timeout: 15000 });

  dashboardPath = path.join(projectDir, '.specify', 'dashboard.html');
});

test.afterAll(() => {
  if (projectDir && fs.existsSync(projectDir)) {
    fs.rmSync(projectDir, { recursive: true, force: true });
  }
});

test('dashboard.html is generated', () => {
  expect(fs.existsSync(dashboardPath)).toBe(true);
});

test('dashboard.html is valid HTML', () => {
  const content = fs.readFileSync(dashboardPath, 'utf-8');
  expect(content).toContain('<!DOCTYPE html>');
  expect(content).toContain('</html>');
});

test('dashboard opens and renders a page title', async ({ page }) => {
  await page.goto(`file://${dashboardPath}`);
  await expect(page).toHaveTitle(/.+/);
});

test('dashboard shows the project name or feature', async ({ page }) => {
  await page.goto(`file://${dashboardPath}`);
  // The dashboard should render something visible — not a blank page
  const body = await page.textContent('body');
  expect(body.length).toBeGreaterThan(100);
});

test('dashboard contains constitution section', async ({ page }) => {
  await page.goto(`file://${dashboardPath}`);
  const content = await page.textContent('body');
  expect(content).toMatch(/constitution|Constitution|governance/i);
});

test('dashboard contains feature/spec information', async ({ page }) => {
  await page.goto(`file://${dashboardPath}`);
  const content = await page.textContent('body');
  expect(content).toMatch(/test.feature|Login|FR-001|spec/i);
});

test('dashboard file:// URL is clickable', async ({ page }) => {
  const fileUrl = `file://${dashboardPath}`;
  const response = await page.goto(fileUrl);
  // file:// URLs don't have HTTP status codes, but the page should load
  expect(page.url()).toContain('dashboard.html');
});

test('dashboard has no JavaScript errors', async ({ page }) => {
  const errors = [];
  page.on('pageerror', err => errors.push(err.message));
  await page.goto(`file://${dashboardPath}`);
  // Wait for any async rendering
  await page.waitForTimeout(1000);
  expect(errors).toEqual([]);
});
