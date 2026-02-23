'use strict';

const http = require('http');
const path = require('path');
const fs = require('fs');
const os = require('os');

/**
 * Create a temp project directory with rich fixtures for all dashboard views.
 * Returns the path to the temp dir — caller must clean up.
 */
function createFixtureProject() {
  const testDir = fs.mkdtempSync(path.join(os.tmpdir(), 'iikit-visual-test-'));
  const feature1Dir = path.join(testDir, 'specs', '001-auth');
  const feature2Dir = path.join(testDir, 'specs', '002-payments');
  const testsDir1 = path.join(feature1Dir, 'tests');
  const checklistDir = path.join(feature1Dir, 'checklists');
  const specifyDir = path.join(testDir, '.specify');

  fs.mkdirSync(feature1Dir, { recursive: true });
  fs.mkdirSync(feature2Dir, { recursive: true });
  fs.mkdirSync(testsDir1, { recursive: true });
  fs.mkdirSync(checklistDir, { recursive: true });
  fs.mkdirSync(specifyDir, { recursive: true });

  // CONSTITUTION.md at project root
  fs.writeFileSync(path.join(testDir, 'CONSTITUTION.md'), `# Project Constitution

## Preamble

This constitution governs development practices for the Auth Platform project.

## Principles

### I. Test-First Development (MUST)

All production code MUST be preceded by a failing test. No code shall be merged without corresponding test coverage.

**Rationale**: Test-first development ensures design quality and prevents regressions.

### II. Real-Time Feedback (SHOULD)

The development workflow SHOULD provide real-time feedback on specification compliance and test integrity.

**Rationale**: Immediate feedback loops reduce cognitive load and catch issues early.

### III. Specification Traceability (MUST)

Every implementation task MUST trace back to a specific functional requirement or success criterion in the specification.

**Rationale**: Traceability ensures nothing is built that wasn't specified and nothing specified is left unbuilt.

### IV. Incremental Delivery (SHOULD)

Features SHOULD be delivered in small, independently verifiable increments aligned with user stories.

**Rationale**: Small increments reduce risk and enable continuous validation.

### V. Documentation as Code (MAY)

Project documentation MAY be generated from structured artifacts rather than maintained manually.

**Rationale**: Generated documentation stays in sync with the actual state of the project.

## Footer

**Version**: 1.0 | **Ratified**: 2026-02-01 | **Last Amended**: 2026-02-15
`);

  // PREMISE.md
  fs.writeFileSync(path.join(testDir, 'PREMISE.md'), '# Project Premise\nThis is an authentication platform.\n');

  // Feature 1: 001-auth — rich data for all views
  fs.writeFileSync(path.join(feature1Dir, 'spec.md'), `# Feature Specification: User Authentication

## Overview

Implement a complete user authentication system with email login, password reset, and OAuth integration.

### User Story 1 - Login with Email (Priority: P1)

As a user, I want to log in with my email and password so that I can access my account.

#### Scenarios

**Given** a registered user with valid credentials
**When** they submit the login form
**Then** they are authenticated and redirected to the dashboard

**Given** a user with invalid credentials
**When** they submit the login form
**Then** they see an error message and can retry

### User Story 2 - Password Reset (Priority: P1)

As a user, I want to reset my password so that I can regain access to my account.

#### Scenarios

**Given** a registered user who forgot their password
**When** they request a password reset
**Then** they receive a reset email within 30 seconds

### User Story 3 - OAuth Integration (Priority: P2)

As a user, I want to log in with Google or GitHub so that I can use my existing accounts.

#### Scenarios

**Given** a user with a Google account
**When** they click "Sign in with Google"
**Then** they are authenticated via OAuth 2.0

### User Story 4 - Session Management (Priority: P2)

As a user, I want my session to persist so that I don't have to log in repeatedly.

#### Scenarios

**Given** an authenticated user
**When** they close and reopen the browser
**Then** they remain logged in for up to 7 days

## Requirements

### Functional Requirements

- **FR-001**: System MUST authenticate users via email and password
- **FR-002**: System MUST support password reset via email
- **FR-003**: System MUST integrate Google and GitHub OAuth providers
- **FR-004**: System MUST maintain user sessions with configurable TTL
- **FR-005**: System MUST hash passwords using bcrypt with cost factor 12
- **FR-006**: System MUST rate-limit login attempts to 5 per minute per IP
- **FR-007**: System SHOULD log all authentication events for audit

## Success Criteria

- **SC-001**: Login completes in under 3 seconds (p95)
- **SC-002**: Password reset email sent within 30 seconds
- **SC-003**: OAuth flow completes in under 5 seconds
- **SC-004**: Session persistence works across browser restarts
- **SC-005**: Failed login attempts are properly rate-limited

## Clarifications

### Clarification 1

**Q**: Should OAuth users also be required to set a local password?
**A**: No. OAuth-only users should not need a local password. However, if they later want to add email/password login, they can set one via the profile page. **Affects**: FR-003

### Clarification 2

**Q**: What happens when a session expires while the user is actively working?
**A**: The system should show a modal prompting re-authentication, preserving the current page state. **Affects**: FR-004, SC-004
`);

  fs.writeFileSync(path.join(feature1Dir, 'tasks.md'), `# Tasks

## Phase 1: Foundation
- [x] T001 [US1] Set up auth module structure and database schema
- [x] T002 [US1] Implement password hashing with bcrypt
- [x] T003 [US1] Create login endpoint with validation

## Phase 2: Core Features
- [x] T004 [US1] Build login form UI component
- [x] T005 [US1] Add input validation and error handling
- [ ] T006 [US2] Design password reset flow and email templates
- [ ] T007 [US2] Implement reset token generation and validation
- [ ] T008 [US2] Send reset email via SendGrid

## Phase 3: OAuth & Sessions
- [ ] T009 [US3] Configure Google OAuth 2.0 client
- [ ] T010 [US3] Configure GitHub OAuth client
- [ ] T011 [US3] Implement OAuth callback handler
- [ ] T012 [US4] Add session persistence with Redis
- [ ] T013 [US4] Implement session refresh logic

## Phase 4: Security & Polish
- [ ] T014 [US1] Add rate limiting middleware
- [ ] T015 [US1] Add authentication event audit logging
`);

  const featuresDir1 = path.join(testsDir1, 'features');
  fs.mkdirSync(featuresDir1, { recursive: true });

  fs.writeFileSync(path.join(featuresDir1, 'acceptance.feature'), `Feature: Acceptance Tests

  @TS-001 @acceptance @P1 @FR-001 @SC-001
  Scenario: Email Login Authentication
    Given a registered user with email "test@example.com" and valid password
    When they submit the login form with correct credentials
    Then they receive a 200 response with a valid session token within 3 seconds

  @TS-003 @acceptance @P1 @FR-002 @SC-002
  Scenario: Password Reset Flow
    Given a registered user who has forgotten their password
    When they request a password reset for their email
    Then a reset email is sent within 30 seconds with a valid token
`);

  fs.writeFileSync(path.join(featuresDir1, 'contract.feature'), `Feature: Contract Tests

  @TS-004 @contract @P2 @FR-003 @SC-003
  Scenario: OAuth Google Login
    Given a user with a valid Google account
    When they initiate the Google OAuth flow
    Then the system exchanges the auth code for tokens and creates a session
`);

  fs.writeFileSync(path.join(featuresDir1, 'validation.feature'), `Feature: Validation Tests

  @TS-002 @validation @P1 @FR-001
  Scenario: Login Validation Errors
    Given a user with an invalid email format
    When they submit the login form
    Then they see a validation error "Invalid email format"

  @TS-005 @validation @P1 @FR-006
  Scenario: Rate Limiting
    Given an IP address that has made 5 failed login attempts in the last minute
    When they attempt a 6th login
    Then the request is rejected with a 429 status code
`);

  fs.writeFileSync(path.join(feature1Dir, 'context.json'), JSON.stringify({
    testify: {
      assertion_hash: 'abc123def456',
      generated_at: '2026-02-10T00:00:00Z',
      test_specs_file: 'specs/001-auth/tests/features/*.feature'
    }
  }));

  // Checklists
  fs.writeFileSync(path.join(checklistDir, 'security.md'), `# Security Checklist

## Authentication Security

- [x] CHK-001 (security) Password hashing uses bcrypt with cost >= 12
- [x] CHK-002 (security) Session tokens are cryptographically random
- [x] CHK-003 (security) HTTPS enforced for all auth endpoints
- [ ] CHK-004 (security) CSRF protection on login form
- [ ] CHK-005 (security) OAuth state parameter validated

## Data Protection

- [x] CHK-006 (security) Passwords never logged or stored in plaintext
- [x] CHK-007 (security) Rate limiting on sensitive endpoints
- [ ] CHK-008 (security) Account lockout after repeated failures
`);

  fs.writeFileSync(path.join(checklistDir, 'ux.md'), `# UX Checklist

## Login Experience

- [x] CHK-101 (ux) Login form has clear error messages
- [x] CHK-102 (ux) Password field has show/hide toggle
- [x] CHK-103 (ux) Remember me option available
- [x] CHK-104 (ux) OAuth buttons clearly labeled
- [ ] CHK-105 (ux) Loading state during authentication

## Accessibility

- [x] CHK-106 (a11y) All form fields have labels
- [x] CHK-107 (a11y) Error messages announced to screen readers
- [x] CHK-108 (a11y) Tab order is logical
- [x] CHK-109 (a11y) Focus management after login/error
`);

  fs.writeFileSync(path.join(checklistDir, 'api.md'), `# API Checklist

## Endpoints

- [x] CHK-201 (api) POST /auth/login returns consistent response shape
- [x] CHK-202 (api) POST /auth/reset returns 202 Accepted
- [x] CHK-203 (api) GET /auth/oauth/:provider redirects correctly
- [x] CHK-204 (api) All endpoints return proper error codes
- [x] CHK-205 (api) Response headers include security headers
`);

  // Plan.md with tech context and ASCII diagram
  fs.writeFileSync(path.join(feature1Dir, 'plan.md'), `# Technical Implementation Plan

## Technical Context

**Runtime**: Node.js 20 LTS
**Framework**: Express 5
**Database**: PostgreSQL 16
**ORM**: Prisma
**Auth Library**: Passport.js
**Session Store**: Redis
**Email**: SendGrid
**Testing**: Jest + Supertest

## Architecture Diagram

\`\`\`
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   Browser SPA   │────→│   API Gateway    │────→│   Auth Service  │
└─────────────────┘     └──────────────────┘     └─────────────────┘
                                                         │
                              ┌───────────────────────────┤
                              │                           │
                        ┌─────┴─────┐              ┌─────┴─────┐
                        │ PostgreSQL │              │   Redis    │
                        └───────────┘              └───────────┘
                                                         │
                                                   ┌─────┴─────┐
                                                   │  SendGrid  │
                                                   └───────────┘
\`\`\`

## File Structure

\`\`\`
auth-service/
├── src/
│   ├── routes/
│   │   ├── login.js
│   │   ├── reset.js
│   │   └── oauth.js
│   ├── middleware/
│   │   ├── rate-limit.js
│   │   └── session.js
│   ├── services/
│   │   ├── auth.js
│   │   ├── email.js
│   │   └── oauth.js
│   └── models/
│       ├── user.js
│       └── session.js
├── tests/
│   ├── login.test.js
│   ├── reset.test.js
│   └── oauth.test.js
└── package.json
\`\`\`

## Key Design Decisions

### KDD-1: Stateless JWT vs Server Sessions

We chose server-side sessions stored in Redis over stateless JWTs because:
- Sessions can be invalidated immediately (important for password reset)
- No token size concerns in cookies
- Redis provides built-in TTL for automatic expiry

### KDD-2: OAuth Strategy Pattern

Using Passport.js strategy pattern allows adding new OAuth providers without modifying core auth logic.

### KDD-3: Rate Limiting Architecture

Rate limiting is implemented at the middleware level using a sliding window algorithm backed by Redis, ensuring distributed rate limiting across multiple server instances.
`);

  // Research.md for plan view tooltips
  fs.writeFileSync(path.join(feature1Dir, 'research.md'), `# Research Decisions

## RD-001: Session Store Selection

**Options evaluated**: Redis, Memcached, PostgreSQL sessions, JWT
**Decision**: Redis
**Rationale**: Built-in TTL, pub/sub for session events, cluster support. Memcached lacks persistence. PostgreSQL adds query overhead. JWT can't be revoked.

## RD-002: Email Provider

**Options evaluated**: SendGrid, AWS SES, Mailgun, Postmark
**Decision**: SendGrid
**Rationale**: Best deliverability rates, template engine, webhook support for delivery tracking. AWS SES is cheaper but requires more setup.
`);

  // Analysis.md
  fs.writeFileSync(path.join(feature1Dir, 'analysis.md'), `# Specification Analysis Report

## Findings

| ID | Category | Severity | Location(s) | Summary | Recommendation |
|----|----------|----------|-------------|---------|----------------|
| A1 | Coverage Gap | CRITICAL | spec.md:FR-007 | FR-007 (audit logging) has no implementation task | Add task for audit logging |
| A2 | Inconsistency | HIGH | plan.md:KDD-1 | Plan mentions JWT but spec requires server sessions | Align plan with spec decision |
| A3 | Test Gap | MEDIUM | test-specs.md | No test for session expiry (FR-004) | Add TS-006 for session TTL |
| A4 | Coverage Gap | LOW | spec.md:SC-004 | SC-004 lacks specific test scenario | Add explicit browser restart test |

## Coverage Summary

| Requirement | Has Task? | Task IDs | Has Test? | Test IDs | Has Plan? | Plan Refs | Status |
|-------------|-----------|----------|-----------|----------|-----------|-----------|--------|
| FR-001 | Yes | T001, T002, T003, T004, T005 | Yes | TS-001, TS-002 | Yes | KDD-1 | Full |
| FR-002 | Yes | T006, T007, T008 | Yes | TS-003 | Yes | KDD-1 | Full |
| FR-003 | Yes | T009, T010, T011 | Yes | TS-004 | Yes | KDD-2 | Full |
| FR-004 | Yes | T012, T013 | No | — | Yes | KDD-1 | Partial |
| FR-005 | Yes | T002 | No | — | No | — | Partial |
| FR-006 | Yes | T014 | Yes | TS-005 | Yes | KDD-3 | Full |
| FR-007 | No | — | No | — | No | — | Missing |

## Constitution Alignment

| Principle | Status | Evidence |
|-----------|--------|----------|
| I. Test-First Development | ALIGNED | 5 test specifications cover core requirements |
| II. Real-Time Feedback | ALIGNED | Dashboard provides live updates |
| III. Specification Traceability | VIOLATION | FR-007 has no task or test |
| IV. Incremental Delivery | ALIGNED | Tasks organized in 4 phases |
| V. Documentation as Code | ALIGNED | All artifacts are markdown |

## Phase Separation Violations

None detected.

## Metrics

| Metric | Value |
|--------|-------|
| Total Requirements (FR + SC) | 12 |
| Total Tasks | 15 |
| Total Test Specifications | 5 |
| Requirement Coverage | 6/7 (86%) |
| Test Coverage | 71% |
| Critical Issues | 1 |
| High Issues | 1 |
| Medium Issues | 1 |
| Low Issues | 1 |
`);

  // Feature 2: 002-payments — minimal data
  fs.writeFileSync(path.join(feature2Dir, 'spec.md'), `# Feature Specification: Payment Processing

### User Story 1 - Process Payment (Priority: P1)

As a user, I want to pay for my subscription so that I can access premium features.

### User Story 2 - View Payment History (Priority: P2)

As a user, I want to view my payment history so that I can track my spending.

## Requirements

### Functional Requirements

- **FR-001**: System MUST process credit card payments via Stripe
- **FR-002**: System MUST store payment history with receipts

## Success Criteria

- **SC-001**: Payment processing completes in under 5 seconds
`);

  fs.writeFileSync(path.join(feature2Dir, 'tasks.md'), `# Tasks

- [ ] T001 [US1] Integrate Stripe SDK
- [ ] T002 [US1] Add payment form component
- [ ] T003 [US1] Implement payment webhook handler
- [ ] T004 [US2] Create payment history API endpoint
- [ ] T005 [US2] Build payment history UI
`);

  return testDir;
}

/**
 * Start a static dashboard server on a random port.
 * Runs the generator to produce dashboard.html, then serves it.
 * Returns { server, port, cleanup }.
 */
async function startServer(projectPath) {
  const { execSync } = require('child_process');
  const generatorPath = path.join(__dirname, '..', '..', '..', '.claude', 'skills', 'iikit-core', 'scripts', 'dashboard', 'src', 'generate-dashboard.js');

  // Run the generator to produce .specify/dashboard.html
  execSync(`"${process.execPath}" "${generatorPath}" "${projectPath}"`, {
    encoding: 'utf-8', timeout: 15000
  });

  let dashboardHtml = fs.readFileSync(
    path.join(projectPath, '.specify', 'dashboard.html'), 'utf-8'
  );
  // Strip meta-refresh and JS reload for test stability
  dashboardHtml = dashboardHtml.replace(/<meta\s+http-equiv="refresh"[^>]*>/g, '');
  dashboardHtml = dashboardHtml.replace(/<script>setInterval\(\s*\(\)\s*=>\s*location\.reload\(\)[^<]*<\/script>/g, '');

  // Serve with a simple static http server
  const server = http.createServer((req, res) => {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(dashboardHtml);
  });

  await new Promise(resolve => server.listen(0, resolve));
  const port = server.address().port;

  const cleanup = async () => {
    await new Promise(resolve => server.close(resolve));
    fs.rmSync(projectPath, { recursive: true, force: true });
  };
  return { server, port, cleanup };
}

module.exports = { createFixtureProject, startServer };
