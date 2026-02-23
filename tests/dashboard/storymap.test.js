'use strict';

const path = require('path');
const fs = require('fs');
const os = require('os');
const { computeStoryMapState } = require('../../.claude/skills/iikit-core/scripts/dashboard/src/storymap');

// TS-027: computeStoryMapState assembles complete state
describe('computeStoryMapState', () => {
  let tmpDir;

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'storymap-test-'));
    const featureDir = path.join(tmpDir, 'specs', '001-test');
    fs.mkdirSync(featureDir, { recursive: true });

    fs.writeFileSync(path.join(featureDir, 'spec.md'), `# Feature Specification: Test

## User Scenarios & Testing

### User Story 1 - View Map (Priority: P1)

Stories linked to FR-001 and FR-002.

**Acceptance Scenarios**:

1. **Given** state, **When** action, **Then** result
2. **Given** state2, **When** action2, **Then** result2

---

### User Story 2 - Explore Graph (Priority: P2)

Shows FR-003 connections.

**Acceptance Scenarios**:

1. **Given** state, **When** action, **Then** result

---

## Requirements

### Functional Requirements

- **FR-001**: System MUST render a story map
- **FR-002**: System MUST display cards
- **FR-003**: System MUST render graph

## Success Criteria

### Measurable Outcomes

- **SC-001**: Developers can identify priorities within 3 seconds

## Clarifications

### Session 2026-02-11

- Q: How should linking work? -> A: Only draw US to FR edges
`);
  });

  afterEach(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  test('returns complete state with stories, requirements, criteria, clarifications, and edges', () => {
    const state = computeStoryMapState(tmpDir, '001-test');

    expect(state.stories).toHaveLength(2);
    expect(state.stories[0].id).toBe('US1');
    expect(state.stories[0].priority).toBe('P1');
    expect(state.stories[0].scenarioCount).toBe(2);
    expect(state.stories[1].id).toBe('US2');
    expect(state.stories[1].scenarioCount).toBe(1);

    expect(state.requirements).toHaveLength(3);
    expect(state.requirements[0].id).toBe('FR-001');

    expect(state.successCriteria).toHaveLength(1);
    expect(state.successCriteria[0].id).toBe('SC-001');

    expect(state.clarifications).toHaveLength(1);
    expect(state.clarifications[0].question).toBe('How should linking work?');

    expect(state.edges).toContainEqual({ from: 'US1', to: 'FR-001' });
    expect(state.edges).toContainEqual({ from: 'US1', to: 'FR-002' });
    expect(state.edges).toContainEqual({ from: 'US2', to: 'FR-003' });
  });

  test('returns empty state when spec.md does not exist', () => {
    const state = computeStoryMapState(tmpDir, '999-nonexistent');
    expect(state.stories).toEqual([]);
    expect(state.requirements).toEqual([]);
    expect(state.edges).toEqual([]);
  });

  test('returns empty arrays when spec.md is empty', () => {
    const featureDir = path.join(tmpDir, 'specs', '002-empty');
    fs.mkdirSync(featureDir, { recursive: true });
    fs.writeFileSync(path.join(featureDir, 'spec.md'), '');

    const state = computeStoryMapState(tmpDir, '002-empty');
    expect(state.stories).toEqual([]);
    expect(state.requirements).toEqual([]);
    expect(state.successCriteria).toEqual([]);
    expect(state.clarifications).toEqual([]);
    expect(state.edges).toEqual([]);
  });

  test('includes clarificationCount on stories', () => {
    const state = computeStoryMapState(tmpDir, '001-test');
    // 1 clarification in the spec — global count on all stories
    expect(state.stories[0].clarificationCount).toBe(1);
    expect(state.stories[1].clarificationCount).toBe(1);
  });
});
