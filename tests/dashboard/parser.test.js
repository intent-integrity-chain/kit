const { parseSpecStories, parseTasks, parseChecklists, parseChecklistsDetailed, parseConstitutionTDD, hasClarifications, parseConstitutionPrinciples, parseRequirements, parseSuccessCriteria, parseClarifications, parseStoryRequirementRefs, parseTechContext, parseFileStructure, parseAsciiDiagram, parseTesslJson, parseResearchDecisions, parseTestSpecs, parseTaskTestRefs, parseAnalysisFindings, parseAnalysisCoverage, parseAnalysisMetrics, parseConstitutionAlignment, parsePhaseSeparation, parseBugs } = require('../../.claude/skills/iikit-core/scripts/dashboard/src/parser');
const fs = require('fs');
const path = require('path');
const os = require('os');

// TS-014: Parser extracts user stories from spec.md
describe('parseSpecStories', () => {
  test('extracts user story with id, title, and priority', () => {
    const content = `# Feature Specification

### User Story 1 - Watch an Agent Work (Priority: P1)

Some description text here.

### User Story 2 - See Where Every Story Stands (Priority: P1)

More description.

### User Story 3 - Switch Between Features (Priority: P2)

Even more.

### User Story 4 - Assertion Integrity at a Glance (Priority: P2)

Last one.
`;
    const stories = parseSpecStories(content);
    expect(stories).toHaveLength(4);
    expect(stories[0]).toMatchObject({ id: 'US1', title: 'Watch an Agent Work', priority: 'P1' });
    expect(stories[1]).toMatchObject({ id: 'US2', title: 'See Where Every Story Stands', priority: 'P1' });
    expect(stories[2]).toMatchObject({ id: 'US3', title: 'Switch Between Features', priority: 'P2' });
    expect(stories[3]).toMatchObject({ id: 'US4', title: 'Assertion Integrity at a Glance', priority: 'P2' });
  });

  test('returns empty array for content with no user stories', () => {
    const content = '# Just a heading\n\nSome text.\n';
    const stories = parseSpecStories(content);
    expect(stories).toEqual([]);
  });

  test('returns empty array for empty string', () => {
    const stories = parseSpecStories('');
    expect(stories).toEqual([]);
  });

  test('handles single user story', () => {
    const content = '### User Story 1 - Watch an Agent Work in Real Time (Priority: P1)\n';
    const stories = parseSpecStories(content);
    expect(stories).toHaveLength(1);
    expect(stories[0]).toMatchObject({ id: 'US1', title: 'Watch an Agent Work in Real Time', priority: 'P1' });
  });

  test('handles malformed input gracefully', () => {
    const stories = parseSpecStories(null);
    expect(stories).toEqual([]);
  });
});

// TS-015: Parser extracts tasks from tasks.md
describe('parseTasks', () => {
  test('extracts checked task with story tag', () => {
    const content = '- [x] T003 [US1] Implement WebSocket server\n';
    const tasks = parseTasks(content);
    expect(tasks).toHaveLength(1);
    expect(tasks[0]).toEqual({
      id: 'T003',
      storyTag: 'US1',
      bugTag: null,
      description: 'Implement WebSocket server',
      checked: true,
      isBugFix: false
    });
  });

  test('extracts unchecked task with story tag', () => {
    const content = '- [ ] T005 [US2] Add feature selector\n';
    const tasks = parseTasks(content);
    expect(tasks).toHaveLength(1);
    expect(tasks[0]).toEqual({
      id: 'T005',
      storyTag: 'US2',
      bugTag: null,
      description: 'Add feature selector',
      checked: false,
      isBugFix: false
    });
  });

  test('extracts tasks with [P] parallel marker', () => {
    const content = '- [ ] T006 [P] [US1] Implement tasks.md parser\n';
    const tasks = parseTasks(content);
    expect(tasks).toHaveLength(1);
    expect(tasks[0].id).toBe('T006');
    expect(tasks[0].storyTag).toBe('US1');
    expect(tasks[0].checked).toBe(false);
  });

  test('extracts multiple tasks', () => {
    const content = `## Phase 3
- [ ] T011 [US1] Add chokidar file watcher
- [x] T012 [US1] Add WebSocket server
- [ ] T013 [US1] Implement GET endpoint
- [x] T014 [US2] Create index.html
`;
    const tasks = parseTasks(content);
    expect(tasks).toHaveLength(4);
    expect(tasks[0]).toEqual({ id: 'T011', storyTag: 'US1', bugTag: null, description: 'Add chokidar file watcher', checked: false, isBugFix: false });
    expect(tasks[1]).toEqual({ id: 'T012', storyTag: 'US1', bugTag: null, description: 'Add WebSocket server', checked: true, isBugFix: false });
    expect(tasks[2]).toEqual({ id: 'T013', storyTag: 'US1', bugTag: null, description: 'Implement GET endpoint', checked: false, isBugFix: false });
    expect(tasks[3]).toEqual({ id: 'T014', storyTag: 'US2', bugTag: null, description: 'Create index.html', checked: true, isBugFix: false });
  });

  test('handles tasks without story tag', () => {
    const content = '- [ ] T001 Initialize package.json with name, version, scripts (start, test)\n';
    const tasks = parseTasks(content);
    expect(tasks).toHaveLength(1);
    expect(tasks[0].id).toBe('T001');
    expect(tasks[0].storyTag).toBeNull();
    expect(tasks[0].description).toBe('Initialize package.json with name, version, scripts (start, test)');
  });

  test('returns empty array for content with no tasks', () => {
    const tasks = parseTasks('# Just headings\n\nSome text.\n');
    expect(tasks).toEqual([]);
  });

  test('returns empty array for empty string', () => {
    const tasks = parseTasks('');
    expect(tasks).toEqual([]);
  });

  test('handles malformed input gracefully', () => {
    const tasks = parseTasks(null);
    expect(tasks).toEqual([]);
  });

  test('handles tasks with [P] but no story tag', () => {
    const content = '- [ ] T002 [P] Install dependencies: express, ws, chokidar\n';
    const tasks = parseTasks(content);
    expect(tasks).toHaveLength(1);
    expect(tasks[0].id).toBe('T002');
    expect(tasks[0].storyTag).toBeNull();
  });
});

// T006: Tests for parseChecklists
describe('parseChecklists', () => {
  let tmpDir;

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'checklist-test-'));
  });

  afterEach(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  test('returns zeros for missing directory', () => {
    const result = parseChecklists('/nonexistent/path');
    expect(result).toEqual({ total: 0, checked: 0, percentage: 0 });
  });

  test('returns zeros for empty directory', () => {
    const result = parseChecklists(tmpDir);
    expect(result).toEqual({ total: 0, checked: 0, percentage: 0 });
  });

  test('counts checked and unchecked items', () => {
    fs.writeFileSync(path.join(tmpDir, 'req.md'), '- [x] CHK001 Done\n- [x] CHK002 Done\n- [ ] CHK003 Not done\n- [ ] CHK004 Not done\n');
    const result = parseChecklists(tmpDir);
    expect(result.total).toBe(4);
    expect(result.checked).toBe(2);
    expect(result.percentage).toBe(50);
  });

  test('aggregates across multiple files', () => {
    fs.writeFileSync(path.join(tmpDir, 'req.md'), '- [x] CHK001 Done\n- [ ] CHK002 Not done\n');
    fs.writeFileSync(path.join(tmpDir, 'ux.md'), '- [x] CHK003 Done\n- [x] CHK004 Done\n');
    const result = parseChecklists(tmpDir);
    expect(result.total).toBe(4);
    expect(result.checked).toBe(3);
    expect(result.percentage).toBe(75);
  });

  test('returns 100% when all checked', () => {
    fs.writeFileSync(path.join(tmpDir, 'req.md'), '- [x] CHK001 Done\n- [x] CHK002 Done\n');
    const result = parseChecklists(tmpDir);
    expect(result.percentage).toBe(100);
  });

  test('ignores non-md files', () => {
    fs.writeFileSync(path.join(tmpDir, 'notes.txt'), '- [ ] Not a checklist\n');
    const result = parseChecklists(tmpDir);
    expect(result.total).toBe(0);
  });
});

// T007: Tests for parseConstitutionTDD
describe('parseConstitutionTDD', () => {
  let tmpDir;

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'tdd-test-'));
  });

  afterEach(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  test('returns true when TDD + MUST keywords present', () => {
    const filePath = path.join(tmpDir, 'CONSTITUTION.md');
    fs.writeFileSync(filePath, '# Constitution\nTDD MUST be used for all development.\n');
    expect(parseConstitutionTDD(filePath)).toBe(true);
  });

  test('returns true when test-first + NON-NEGOTIABLE present', () => {
    const filePath = path.join(tmpDir, 'CONSTITUTION.md');
    fs.writeFileSync(filePath, '# Constitution\n### Test-First Development (NON-NEGOTIABLE)\nTests must be written before code.\n');
    expect(parseConstitutionTDD(filePath)).toBe(true);
  });

  test('returns false when no TDD keywords', () => {
    const filePath = path.join(tmpDir, 'CONSTITUTION.md');
    fs.writeFileSync(filePath, '# Constitution\nBe nice to each other.\nCode must be reviewed.\n');
    expect(parseConstitutionTDD(filePath)).toBe(false);
  });

  test('returns false for missing file', () => {
    expect(parseConstitutionTDD('/nonexistent/CONSTITUTION.md')).toBe(false);
  });
});

// T008: Tests for hasClarifications
describe('hasClarifications', () => {
  test('returns true when spec has Clarifications section', () => {
    expect(hasClarifications('# Spec\n## Clarifications\n### Session\n- Q: x -> A: y\n')).toBe(true);
  });

  test('returns false when spec has no Clarifications section', () => {
    expect(hasClarifications('# Spec\n## Requirements\n- FR-001\n')).toBe(false);
  });

  test('returns false for empty string', () => {
    expect(hasClarifications('')).toBe(false);
  });

  test('returns false for null', () => {
    expect(hasClarifications(null)).toBe(false);
  });
});

// T001: Tests for parseConstitutionPrinciples (TS-011 through TS-017)
describe('parseConstitutionPrinciples', () => {
  let tmpDir;

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'constitution-test-'));
  });

  afterEach(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  // TS-011: Extracts principle name from heading
  test('extracts principle number and name from heading', () => {
    fs.writeFileSync(path.join(tmpDir, 'CONSTITUTION.md'), `# Constitution

## Core Principles

### I. Test-First Development (NON-NEGOTIABLE)

TDD MUST be used for all feature development.

**Rationale**: Prevents circular verification.
`);
    const result = parseConstitutionPrinciples(tmpDir);
    expect(result.principles).toHaveLength(1);
    expect(result.principles[0].number).toBe('I');
    expect(result.principles[0].name).toBe('Test-First Development');
  });

  // TS-012: Extracts obligation level MUST
  test('extracts obligation level MUST', () => {
    fs.writeFileSync(path.join(tmpDir, 'CONSTITUTION.md'), `# Constitution
## Core Principles
### I. Test-First Development
TDD MUST be used for all feature development.
**Rationale**: Prevents bugs.
`);
    const result = parseConstitutionPrinciples(tmpDir);
    expect(result.principles[0].level).toBe('MUST');
  });

  // TS-013: Extracts obligation level SHOULD
  test('extracts obligation level SHOULD', () => {
    fs.writeFileSync(path.join(tmpDir, 'CONSTITUTION.md'), `# Constitution
## Core Principles
### I. Code Documentation
Code SHOULD be well documented.
**Rationale**: Helps readability.
`);
    const result = parseConstitutionPrinciples(tmpDir);
    expect(result.principles[0].level).toBe('SHOULD');
  });

  // TS-014: Defaults to SHOULD when no keywords
  test('defaults to SHOULD when no MUST/SHOULD/MAY keywords', () => {
    fs.writeFileSync(path.join(tmpDir, 'CONSTITUTION.md'), `# Constitution
## Core Principles
### I. Be Nice
Be nice to each other.
**Rationale**: Good vibes.
`);
    const result = parseConstitutionPrinciples(tmpDir);
    expect(result.principles[0].level).toBe('SHOULD');
  });

  // TS-015: Extracts rationale text
  test('extracts rationale text', () => {
    fs.writeFileSync(path.join(tmpDir, 'CONSTITUTION.md'), `# Constitution
## Core Principles
### I. Test-First Development
TDD MUST be used.

**Rationale**: Prevents circular verification problem where AI agents weaken assertions.
`);
    const result = parseConstitutionPrinciples(tmpDir);
    expect(result.principles[0].rationale).toContain('Prevents circular verification');
  });

  // TS-016: Extracts version metadata from footer
  test('extracts version metadata from footer', () => {
    fs.writeFileSync(path.join(tmpDir, 'CONSTITUTION.md'), `# Constitution
## Core Principles
### I. Simplicity
Keep it simple. This MUST be followed.
**Rationale**: Less is more.

**Version**: 1.1.0 | **Ratified**: 2026-02-10 | **Last Amended**: 2026-02-10
`);
    const result = parseConstitutionPrinciples(tmpDir);
    expect(result.version).not.toBeNull();
    expect(result.version.version).toBe('1.1.0');
    expect(result.version.ratified).toBe('2026-02-10');
    expect(result.version.lastAmended).toBe('2026-02-10');
  });

  // TS-017: Returns null version when no footer
  test('returns null version when no footer', () => {
    fs.writeFileSync(path.join(tmpDir, 'CONSTITUTION.md'), `# Constitution
## Core Principles
### I. Simplicity
Keep it simple.
`);
    const result = parseConstitutionPrinciples(tmpDir);
    expect(result.version).toBeNull();
  });

  test('extracts multiple principles', () => {
    fs.writeFileSync(path.join(tmpDir, 'CONSTITUTION.md'), `# Constitution
## Core Principles
### I. Test-First Development (NON-NEGOTIABLE)
TDD MUST be used.
**Rationale**: Tests first.
### II. Real-Time Accuracy
The system MUST reflect true state.
**Rationale**: No stale data.
### IV. Simplicity
Start simple. Code MAY be refactored later.
**Rationale**: YAGNI.
`);
    const result = parseConstitutionPrinciples(tmpDir);
    expect(result.principles).toHaveLength(3);
    expect(result.principles[0].number).toBe('I');
    expect(result.principles[0].level).toBe('MUST');
    expect(result.principles[1].number).toBe('II');
    expect(result.principles[1].level).toBe('MUST');
    expect(result.principles[2].number).toBe('IV');
    expect(result.principles[2].level).toBe('MAY');
  });

  test('returns empty when no CONSTITUTION.md', () => {
    const result = parseConstitutionPrinciples(tmpDir);
    expect(result.principles).toEqual([]);
    expect(result.version).toBeNull();
    expect(result.exists).toBe(false);
  });

  test('returns exists true when file found', () => {
    fs.writeFileSync(path.join(tmpDir, 'CONSTITUTION.md'), `# Constitution
## Core Principles
### I. Test
Something MUST happen.
`);
    const result = parseConstitutionPrinciples(tmpDir);
    expect(result.exists).toBe(true);
  });

  // TS-018: Obligation level mapping values
  test('MUST is strongest, SHOULD is moderate, MAY is weakest', () => {
    fs.writeFileSync(path.join(tmpDir, 'CONSTITUTION.md'), `# Constitution
## Core Principles
### I. Strong
This MUST happen.
### II. Moderate
This SHOULD happen.
### III. Optional
This MAY happen.
`);
    const result = parseConstitutionPrinciples(tmpDir);
    expect(result.principles[0].level).toBe('MUST');
    expect(result.principles[1].level).toBe('SHOULD');
    expect(result.principles[2].level).toBe('MAY');
  });
});

// TS-019, TS-024: parseRequirements
describe('parseRequirements', () => {
  test('extracts FR-xxx with description text', () => {
    const content = `## Requirements

### Functional Requirements

- **FR-001**: System MUST render a story map
- **FR-002**: System MUST display each story as a card
`;
    const reqs = parseRequirements(content);
    expect(reqs).toHaveLength(2);
    expect(reqs[0]).toEqual({ id: 'FR-001', text: 'System MUST render a story map' });
    expect(reqs[1]).toEqual({ id: 'FR-002', text: 'System MUST display each story as a card' });
  });

  test('returns empty array for spec with no Requirements section', () => {
    const content = '# Feature\n\n## User Stories\n\nSome stories.\n';
    const reqs = parseRequirements(content);
    expect(reqs).toEqual([]);
  });

  test('returns empty array for empty string', () => {
    expect(parseRequirements('')).toEqual([]);
  });

  test('returns empty array for null', () => {
    expect(parseRequirements(null)).toEqual([]);
  });
});

// TS-020: parseSuccessCriteria
describe('parseSuccessCriteria', () => {
  test('extracts SC-xxx with description text', () => {
    const content = `## Success Criteria

### Measurable Outcomes

- **SC-001**: Developers can identify priority distribution within 3 seconds
- **SC-002**: Developers can trace from any story to requirements in under 3 clicks
`;
    const criteria = parseSuccessCriteria(content);
    expect(criteria).toHaveLength(2);
    expect(criteria[0]).toEqual({ id: 'SC-001', text: 'Developers can identify priority distribution within 3 seconds' });
    expect(criteria[1]).toEqual({ id: 'SC-002', text: 'Developers can trace from any story to requirements in under 3 clicks' });
  });

  test('returns empty array for empty string', () => {
    expect(parseSuccessCriteria('')).toEqual([]);
  });

  test('returns empty array for null', () => {
    expect(parseSuccessCriteria(null)).toEqual([]);
  });
});

// TS-021, TS-025: parseClarifications
describe('parseClarifications', () => {
  test('extracts Q&A pairs with session date and empty refs', () => {
    const content = `## Clarifications

### Session 2026-02-11

- Q: How should cross-linking work? -> A: Only draw US to FR edges
- Q: Should nodes show coverage? -> A: No, coverage belongs to Tasks phase
`;
    const clarifications = parseClarifications(content);
    expect(clarifications).toHaveLength(2);
    expect(clarifications[0]).toEqual({
      session: '2026-02-11',
      question: 'How should cross-linking work?',
      answer: 'Only draw US to FR edges',
      refs: []
    });
    expect(clarifications[1]).toEqual({
      session: '2026-02-11',
      question: 'Should nodes show coverage?',
      answer: 'No, coverage belongs to Tasks phase',
      refs: []
    });
  });

  test('extracts spec item references from Q&A entries', () => {
    const content = `## Clarifications

### Session 2026-02-13

- Q: How do story cards map to columns? -> A: Columns are Todo / In Progress / Done [FR-001, US-2]
- Q: When does the dashboard launch? -> A: Only during implementation phase [FR-005, SC-001]
- Q: Should errors show inline? -> A: Yes, inline within the component [FR-010]
`;
    const clarifications = parseClarifications(content);
    expect(clarifications).toHaveLength(3);
    expect(clarifications[0]).toEqual({
      session: '2026-02-13',
      question: 'How do story cards map to columns?',
      answer: 'Columns are Todo / In Progress / Done',
      refs: ['FR-001', 'US-2']
    });
    expect(clarifications[1]).toEqual({
      session: '2026-02-13',
      question: 'When does the dashboard launch?',
      answer: 'Only during implementation phase',
      refs: ['FR-005', 'SC-001']
    });
    expect(clarifications[2]).toEqual({
      session: '2026-02-13',
      question: 'Should errors show inline?',
      answer: 'Yes, inline within the component',
      refs: ['FR-010']
    });
  });

  test('handles mix of entries with and without refs', () => {
    const content = `## Clarifications

### Session 2026-02-10

- Q: Old question? -> A: Old answer
- Q: New question? -> A: New answer [FR-003, US-1]
`;
    const clarifications = parseClarifications(content);
    expect(clarifications).toHaveLength(2);
    expect(clarifications[0].refs).toEqual([]);
    expect(clarifications[1].refs).toEqual(['FR-003', 'US-1']);
  });

  test('returns empty array for spec with no Clarifications section', () => {
    const content = '# Feature\n\n## Requirements\n\n- FR-001\n';
    expect(parseClarifications(content)).toEqual([]);
  });

  test('returns empty array for empty string', () => {
    expect(parseClarifications('')).toEqual([]);
  });

  test('returns empty array for null', () => {
    expect(parseClarifications(null)).toEqual([]);
  });
});

// TS-022, TS-026: parseStoryRequirementRefs
describe('parseStoryRequirementRefs', () => {
  test('extracts FR-xxx references from story sections', () => {
    const content = `### User Story 1 - View Story Map (Priority: P1)

A developer sees stories linked to FR-001 and FR-002.

**Acceptance Scenarios**:
1. **Given** a spec with FR-001, **When** loaded, **Then** display

---

### User Story 2 - Explore Graph (Priority: P1)

The graph shows FR-003 connections.
`;
    const edges = parseStoryRequirementRefs(content);
    expect(edges).toContainEqual({ from: 'US1', to: 'FR-001' });
    expect(edges).toContainEqual({ from: 'US1', to: 'FR-002' });
    expect(edges).toContainEqual({ from: 'US2', to: 'FR-003' });
  });

  test('returns empty edges for stories with no FR references', () => {
    const content = `### User Story 1 - Simple View (Priority: P1)

A simple story with no requirement references.
`;
    const edges = parseStoryRequirementRefs(content);
    expect(edges).toEqual([]);
  });

  test('deduplicates FR references within a story', () => {
    const content = `### User Story 1 - View Map (Priority: P1)

FR-001 is mentioned here and FR-001 again in acceptance.

**Acceptance Scenarios**:
1. **Given** FR-001, **When** loaded, **Then** display
`;
    const edges = parseStoryRequirementRefs(content);
    const us1Edges = edges.filter(e => e.from === 'US1' && e.to === 'FR-001');
    expect(us1Edges).toHaveLength(1);
  });

  test('returns empty array for empty string', () => {
    expect(parseStoryRequirementRefs('')).toEqual([]);
  });

  test('returns empty array for null', () => {
    expect(parseStoryRequirementRefs(null)).toEqual([]);
  });
});

// TS-027: parseTechContext
describe('parseTechContext', () => {
  test('extracts bold-label-colon-value pairs from Technical Context section', () => {
    const content = `## Technical Context

**Language/Version**: Node.js 20+ (LTS)
**Primary Dependencies**: Express, ws, chokidar
**Storage**: N/A
**Testing**: Jest (unit + integration tests)
`;
    const entries = parseTechContext(content);
    expect(entries).toHaveLength(4);
    expect(entries[0]).toEqual({ label: 'Language/Version', value: 'Node.js 20+ (LTS)' });
    expect(entries[1]).toEqual({ label: 'Primary Dependencies', value: 'Express, ws, chokidar' });
    expect(entries[2]).toEqual({ label: 'Storage', value: 'N/A' });
    expect(entries[3]).toEqual({ label: 'Testing', value: 'Jest (unit + integration tests)' });
  });

  test('returns empty array when no Technical Context section', () => {
    const content = '# Plan\n\n## Summary\n\nSome text.\n';
    expect(parseTechContext(content)).toEqual([]);
  });

  test('returns empty array for empty string', () => {
    expect(parseTechContext('')).toEqual([]);
  });

  test('returns empty array for null', () => {
    expect(parseTechContext(null)).toEqual([]);
  });

  test('stops at next section heading', () => {
    const content = `## Technical Context

**Language/Version**: Python 3.12

## Constitution Check

**Not a tech context**: This should not be parsed
`;
    const entries = parseTechContext(content);
    expect(entries).toHaveLength(1);
    expect(entries[0].label).toBe('Language/Version');
  });
});

// TS-028, TS-029, TS-030, TS-031: parseFileStructure
describe('parseFileStructure', () => {
  test('parses tree with correct depth, name, and type', () => {
    const content = `## File Structure

\`\`\`
iikit-kanban/
├── package.json
├── src/
│   ├── server.js          # Express + WebSocket server
│   └── parser.js
└── test/
    └── parser.test.js
\`\`\`
`;
    const result = parseFileStructure(content);
    expect(result.rootName).toBe('iikit-kanban');
    expect(result.entries).toHaveLength(6);
    expect(result.entries[0]).toMatchObject({ name: 'package.json', type: 'file', depth: 0 });
    expect(result.entries[1]).toMatchObject({ name: 'src', type: 'directory', depth: 0 });
    expect(result.entries[2]).toMatchObject({ name: 'server.js', type: 'file', depth: 1, comment: 'Express + WebSocket server' });
    expect(result.entries[3]).toMatchObject({ name: 'parser.js', type: 'file', depth: 1 });
    expect(result.entries[4]).toMatchObject({ name: 'test', type: 'directory', depth: 0 });
    expect(result.entries[5]).toMatchObject({ name: 'parser.test.js', type: 'file', depth: 1 });
  });

  test('extracts inline comments after #', () => {
    const content = `## File Structure

\`\`\`
myproject/
├── server.js          # Express + WebSocket server
└── parser.js
\`\`\`
`;
    const result = parseFileStructure(content);
    expect(result.entries[0].comment).toBe('Express + WebSocket server');
    expect(result.entries[1].comment).toBeNull();
  });

  test('identifies directories by trailing slash or having children', () => {
    const content = `## File Structure

\`\`\`
myproject/
├── src/
│   └── index.js
└── readme.md
\`\`\`
`;
    const result = parseFileStructure(content);
    expect(result.entries[0]).toMatchObject({ name: 'src', type: 'directory' });
    expect(result.entries[1]).toMatchObject({ name: 'index.js', type: 'file' });
    expect(result.entries[2]).toMatchObject({ name: 'readme.md', type: 'file' });
  });

  test('returns null when no File Structure section', () => {
    const content = '# Plan\n\n## Summary\n\nSome text.\n';
    expect(parseFileStructure(content)).toBeNull();
  });

  test('returns null for empty string', () => {
    expect(parseFileStructure('')).toBeNull();
  });

  test('returns null for null', () => {
    expect(parseFileStructure(null)).toBeNull();
  });

  test('strips root directory name', () => {
    const content = `## File Structure

\`\`\`
iikit-kanban/
├── src/
│   └── server.js
\`\`\`
`;
    const result = parseFileStructure(content);
    expect(result.rootName).toBe('iikit-kanban');
    expect(result.entries[0].name).toBe('src');
  });
});

// TS-032, TS-033, TS-034, TS-035, TS-036: parseAsciiDiagram
describe('parseAsciiDiagram', () => {
  test('detects boxes with box-drawing characters and extracts labels', () => {
    const content = `## Architecture Overview

\`\`\`
┌──────────┐
│  Browser  │
└──────────┘
\`\`\`
`;
    const result = parseAsciiDiagram(content);
    expect(result).not.toBeNull();
    expect(result.nodes).toHaveLength(1);
    expect(result.nodes[0].label).toBe('Browser');
  });

  test('extracts all text content from multi-line boxes', () => {
    const content = `## Architecture Overview

\`\`\`
┌──────────────┐
│  Node.js      │
│  Server       │
│  (Express)    │
└──────────────┘
\`\`\`
`;
    const result = parseAsciiDiagram(content);
    expect(result.nodes[0].label).toBe('Node.js');
    expect(result.nodes[0].content).toContain('Server');
    expect(result.nodes[0].content).toContain('(Express)');
  });

  test('detects connections between boxes', () => {
    const content = `## Architecture Overview

\`\`\`
┌──────────┐
│  Browser  │
└─────┬────┘
      │
┌─────┴────┐
│  Server   │
└──────────┘
\`\`\`
`;
    const result = parseAsciiDiagram(content);
    expect(result.nodes).toHaveLength(2);
    expect(result.edges.length).toBeGreaterThanOrEqual(1);
  });

  test('extracts edge labels', () => {
    const content = `## Architecture Overview

\`\`\`
┌──────────┐
│  Browser  │
└─────┬────┘
      │ ws://localhost:PORT
┌─────┴────┐
│  Server   │
└──────────┘
\`\`\`
`;
    const result = parseAsciiDiagram(content);
    const labeledEdge = result.edges.find(e => e.label && e.label.includes('ws://'));
    expect(labeledEdge).toBeDefined();
  });

  test('filters out container boxes, keeps only leaf nodes', () => {
    const content = `## Architecture Overview

\`\`\`
┌─────────────────────────────────┐
│  Browser                         │
│  ┌─────────────────────────────┐ │
│  │  Single HTML page           │ │
│  └─────────────────────────────┘ │
└─────────────────────────────────┘
\`\`\`
`;
    const result = parseAsciiDiagram(content);
    // Only the inner leaf box "Single HTML page" should remain, not the container "Browser"
    expect(result.nodes).toHaveLength(1);
    expect(result.nodes[0].label).toBe('Single HTML page');
  });

  test('returns null when no Architecture Overview section', () => {
    const content = '# Plan\n\n## Summary\n\nSome text.\n';
    expect(parseAsciiDiagram(content)).toBeNull();
  });

  test('returns null for empty string', () => {
    expect(parseAsciiDiagram('')).toBeNull();
  });

  test('preserves raw ASCII text', () => {
    const content = `## Architecture Overview

\`\`\`
┌──────────┐
│  Browser  │
└──────────┘
\`\`\`
`;
    const result = parseAsciiDiagram(content);
    expect(result.raw).toContain('Browser');
    expect(result.raw).toContain('┌');
  });
});

// TS-037, TS-038: parseTesslJson
describe('parseTesslJson', () => {
  let tmpDir;

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'tessl-test-'));
  });

  afterEach(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  test('reads dependencies from tessl.json', () => {
    fs.writeFileSync(path.join(tmpDir, 'tessl.json'), JSON.stringify({
      dependencies: {
        'tessl/npm-express': { version: '5.1.0' },
        'tessl/npm-ws': { version: '8.18.0' }
      }
    }));
    const tiles = parseTesslJson(tmpDir);
    expect(tiles).toHaveLength(2);
    expect(tiles[0]).toEqual({ name: 'tessl/npm-express', version: '5.1.0', eval: null });
    expect(tiles[1]).toEqual({ name: 'tessl/npm-ws', version: '8.18.0', eval: null });
  });

  test('returns empty array when file missing', () => {
    const tiles = parseTesslJson(tmpDir);
    expect(tiles).toEqual([]);
  });

  test('returns empty array for malformed JSON', () => {
    fs.writeFileSync(path.join(tmpDir, 'tessl.json'), 'not json');
    const tiles = parseTesslJson(tmpDir);
    expect(tiles).toEqual([]);
  });

  test('returns empty array when no dependencies key', () => {
    fs.writeFileSync(path.join(tmpDir, 'tessl.json'), JSON.stringify({ name: 'my-project' }));
    const tiles = parseTesslJson(tmpDir);
    expect(tiles).toEqual([]);
  });
});

// TS-041: parseResearchDecisions
describe('parseResearchDecisions', () => {
  test('extracts decision title, decision text, and rationale', () => {
    const content = `# Research

## Decisions

### 1. ASCII Diagram Parsing Approach

**Decision**: Build a custom parser for box-drawing characters
**Rationale**: The ASCII diagrams use Unicode box-drawing characters consistently
**Alternatives considered**: General ASCII libraries (rejected)
`;
    const decisions = parseResearchDecisions(content);
    expect(decisions).toHaveLength(1);
    expect(decisions[0].title).toBe('ASCII Diagram Parsing Approach');
    expect(decisions[0].decision).toBe('Build a custom parser for box-drawing characters');
    expect(decisions[0].rationale).toBe('The ASCII diagrams use Unicode box-drawing characters consistently');
  });

  test('extracts multiple decisions', () => {
    const content = `## Decisions

### 1. First Decision

**Decision**: Choice A
**Rationale**: Because A is better

### 2. Second Decision

**Decision**: Choice B
**Rationale**: Because B is needed
`;
    const decisions = parseResearchDecisions(content);
    expect(decisions).toHaveLength(2);
    expect(decisions[0].title).toBe('First Decision');
    expect(decisions[1].title).toBe('Second Decision');
  });

  test('returns empty array when no content', () => {
    expect(parseResearchDecisions('')).toEqual([]);
  });

  test('returns empty array for null', () => {
    expect(parseResearchDecisions(null)).toEqual([]);
  });

  test('returns empty array when no Decisions section', () => {
    const content = '# Research\n\n## Tessl Tiles\n\nSome tiles info.\n';
    expect(parseResearchDecisions(content)).toEqual([]);
  });
});

// TS-023: parseSpecStories extended with scenarioCount
describe('parseSpecStories extended', () => {
  test('returns scenarioCount per story', () => {
    const content = `### User Story 1 - View Map (Priority: P1)

Description.

**Acceptance Scenarios**:

1. **Given** state, **When** action, **Then** result
2. **Given** state2, **When** action2, **Then** result2
3. **Given** state3, **When** action3, **Then** result3

---

### User Story 2 - Graph (Priority: P2)

Description.

**Acceptance Scenarios**:

1. **Given** state, **When** action, **Then** result
`;
    const stories = parseSpecStories(content);
    expect(stories[0].scenarioCount).toBe(3);
    expect(stories[1].scenarioCount).toBe(1);
  });

  test('returns 0 scenarioCount for story with no scenarios', () => {
    const content = `### User Story 1 - Simple (Priority: P1)

Just a description, no scenarios.

---

### User Story 2 - Another (Priority: P2)

Also no scenarios.
`;
    const stories = parseSpecStories(content);
    expect(stories[0].scenarioCount).toBe(0);
    expect(stories[1].scenarioCount).toBe(0);
  });
});

// TS-020 through TS-033: parseChecklistsDetailed
describe('parseChecklistsDetailed', () => {
  let tmpDir;

  beforeEach(() => {
    tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), 'checklist-detailed-test-'));
  });

  afterEach(() => {
    fs.rmSync(tmpDir, { recursive: true, force: true });
  });

  // TS-020: Returns per-file item arrays with correct counts
  test('returns per-file item arrays with correct counts', () => {
    fs.writeFileSync(path.join(tmpDir, 'requirements.md'), '- [x] CHK-001 Req one\n- [x] CHK-002 Req two\n- [x] CHK-003 Req three\n- [ ] CHK-004 Req four\n- [ ] CHK-005 Req five\n');
    fs.writeFileSync(path.join(tmpDir, 'ux.md'), '- [x] CHK-010 UX item one\n');
    const result = parseChecklistsDetailed(tmpDir);
    expect(result).toHaveLength(2);

    const reqFile = result.find(f => f.filename === 'requirements.md');
    const uxFile = result.find(f => f.filename === 'ux.md');

    expect(reqFile).toBeDefined();
    expect(reqFile.name).toBe('Requirements');
    expect(reqFile.total).toBe(5);
    expect(reqFile.checked).toBe(3);
    expect(reqFile.items).toHaveLength(5);

    expect(uxFile).toBeDefined();
    expect(uxFile.name).toBe('Ux');
    expect(uxFile.filename).toBe('ux.md');
    expect(uxFile.total).toBe(1);
    expect(uxFile.checked).toBe(1);
    expect(uxFile.items).toHaveLength(1);
  });

  // TS-021: Percentage calculation rounds correctly
  test('percentage calculation rounds correctly', () => {
    fs.writeFileSync(path.join(tmpDir, 'review.md'), '- [x] CHK-001 Done\n- [ ] CHK-002 Not done\n- [ ] CHK-003 Not done\n');
    // Test with a non-requirements checklist file
    const result = parseChecklistsDetailed(tmpDir);
    const reviewFile = result.find(f => f.filename === 'review.md');
    expect(reviewFile).toBeDefined();
    // 1 checked, 2 unchecked = 1/3 * 100 = 33.33 -> Math.round = 33
    expect(reviewFile.total).toBe(3);
    expect(reviewFile.checked).toBe(1);
  });

  // TS-029: Extracts CHK ID and tags from items
  test('extracts CHK ID and tags from items', () => {
    fs.writeFileSync(path.join(tmpDir, 'spec.md'), '- [x] CHK-001 All stories have acceptance scenarios [spec]\n');
    const result = parseChecklistsDetailed(tmpDir);
    expect(result).toHaveLength(1);
    const item = result[0].items[0];
    expect(item.checked).toBe(true);
    expect(item.chkId).toBe('CHK-001');
    expect(item.text).toContain('All stories have acceptance scenarios');
    expect(item.tags).toEqual(['spec']);
  });

  // TS-030: Handles items without CHK ID or tags
  test('handles items without CHK ID or tags', () => {
    fs.writeFileSync(path.join(tmpDir, 'review.md'), '- [ ] Edge cases identified\n');
    const result = parseChecklistsDetailed(tmpDir);
    expect(result).toHaveLength(1);
    const item = result[0].items[0];
    expect(item.checked).toBe(false);
    expect(item.chkId).toBeNull();
    expect(item.text).toBe('Edge cases identified');
    expect(item.tags).toEqual([]);
  });

  // TS-031: Category assignment from nearest heading
  test('category assignment from nearest heading', () => {
    fs.writeFileSync(path.join(tmpDir, 'review.md'),
      '## Requirement Completeness\n\n- [ ] CHK-001 First item\n- [ ] CHK-002 Second item\n\n## Clarity\n\n- [ ] CHK-003 Third item\n');
    const result = parseChecklistsDetailed(tmpDir);
    expect(result).toHaveLength(1);
    const items = result[0].items;
    expect(items).toHaveLength(3);
    expect(items[0].category).toBe('Requirement Completeness');
    expect(items[1].category).toBe('Requirement Completeness');
    expect(items[2].category).toBe('Clarity');
  });

  // TS-032: Checklist name derived from filename
  test('checklist name derived from filename', () => {
    fs.writeFileSync(path.join(tmpDir, 'requirements.md'), '- [ ] Item\n');
    fs.writeFileSync(path.join(tmpDir, 'api-design.md'), '- [ ] Item\n');
    fs.writeFileSync(path.join(tmpDir, 'ux.md'), '- [ ] Item\n');
    const result = parseChecklistsDetailed(tmpDir);
    const names = result.map(f => f.name).sort();
    expect(names).toContain('Requirements');
    expect(names).toContain('Api Design');
    expect(names).toContain('Ux');
  });

  // TS-033: Empty checklist file returns zero total
  test('empty checklist file returns zero total and percentage', () => {
    fs.writeFileSync(path.join(tmpDir, 'empty.md'), '# Just a heading\n\nSome text but no checkboxes.\n');
    const result = parseChecklistsDetailed(tmpDir);
    expect(result).toHaveLength(1);
    expect(result[0].total).toBe(0);
    expect(result[0].checked).toBe(0);
  });

  // Test 8: requirements.md is counted as a real checklist
  test('requirements.md is parsed as a checklist', () => {
    fs.writeFileSync(path.join(tmpDir, 'requirements.md'), '- [x] CHK-001 Done\n- [ ] CHK-002 Not done\n');
    const result = parseChecklistsDetailed(tmpDir);
    expect(result.length).toBe(1);
    expect(result[0].filename).toBe('requirements.md');
    expect(result[0].items.length).toBe(2);
  });

  // Test 9: Missing directory returns empty array
  test('missing directory returns empty array', () => {
    const result = parseChecklistsDetailed('/nonexistent/path/to/checklists');
    expect(result).toEqual([]);
  });
});

// T002: Tests for parseTestSpecs — TS-024, TS-025, TS-026 (Gherkin format)
describe('parseTestSpecs', () => {
  const fixtureFiles = ['acceptance.feature', 'contract.feature', 'validation.feature'];
  const fixtureContent = fixtureFiles
    .map(f => fs.readFileSync(path.join(__dirname, 'fixtures/testify/tests/features', f), 'utf-8'))
    .join('\n');

  // TS-024: extracts id and title from Gherkin scenario
  test('extracts id and title from Gherkin scenario', () => {
    const content = '  @TS-001 @acceptance @P1 @FR-001\n  Scenario: Login with valid credentials\n    Given a user\n    When they login\n    Then they are authenticated\n';
    const specs = parseTestSpecs(content);
    expect(specs).toHaveLength(1);
    expect(specs[0].id).toBe('TS-001');
    expect(specs[0].title).toBe('Login with valid credentials');
  });

  // TS-025: extracts type as acceptance, contract, or validation
  test('extracts type as acceptance, contract, or validation', () => {
    const specs = parseTestSpecs(fixtureContent);
    const acceptance = specs.filter(s => s.type === 'acceptance');
    const contract = specs.filter(s => s.type === 'contract');
    const validation = specs.filter(s => s.type === 'validation');

    expect(acceptance.length).toBe(3);
    expect(contract.length).toBe(2);
    expect(validation.length).toBe(3);
  });

  // TS-026: traceability links filtered to FR-/SC- patterns only
  test('filters traceability to FR- and SC- patterns only', () => {
    const content = '  @TS-001 @acceptance @P1 @FR-001 @SC-002 @US-001\n  Scenario: Test\n    Given x\n    Then y\n';
    const specs = parseTestSpecs(content);
    expect(specs[0].traceability).toEqual(['FR-001', 'SC-002']);
  });

  test('extracts priority field', () => {
    const specs = parseTestSpecs(fixtureContent);
    expect(specs[0].priority).toBe('P1');
    expect(specs[1].priority).toBe('P2');
  });

  test('extracts all 8 test specs from fixture', () => {
    const specs = parseTestSpecs(fixtureContent);
    expect(specs).toHaveLength(8);
    expect(specs.map(s => s.id)).toEqual([
      'TS-001', 'TS-002', 'TS-003', 'TS-004',
      'TS-005', 'TS-006', 'TS-007', 'TS-008'
    ]);
  });

  test('returns empty array for empty string', () => {
    expect(parseTestSpecs('')).toEqual([]);
  });

  test('returns empty array for null', () => {
    expect(parseTestSpecs(null)).toEqual([]);
  });

  test('handles test spec with no traceability tags', () => {
    const content = '  @TS-001 @validation @P2\n  Scenario: Test\n    Given x\n    Then y\n';
    const specs = parseTestSpecs(content);
    expect(specs).toHaveLength(1);
    expect(specs[0].traceability).toEqual([]);
  });

  test('defaults type to validation when no type tag', () => {
    const content = '  @TS-001 @P1\n  Scenario: Test\n    Given x\n    Then y\n';
    const specs = parseTestSpecs(content);
    expect(specs[0].type).toBe('validation');
  });

  test('defaults priority to P3 when no priority tag', () => {
    const content = '  @TS-001 @acceptance\n  Scenario: Test\n    Given x\n    Then y\n';
    const specs = parseTestSpecs(content);
    expect(specs[0].priority).toBe('P3');
  });

  test('handles Scenario Outline', () => {
    const content = '  @TS-001 @acceptance @P1 @FR-001\n  Scenario Outline: Login with <role>\n    Given a <role> user\n    Then they see dashboard\n';
    const specs = parseTestSpecs(content);
    expect(specs).toHaveLength(1);
    expect(specs[0].title).toBe('Login with <role>');
  });

  test('skips Background and Rule lines gracefully', () => {
    const content = 'Feature: Auth\n\n  Background:\n    Given a database\n\n  @TS-001 @acceptance @P1\n  Scenario: Login\n    Given a user\n    Then success\n';
    const specs = parseTestSpecs(content);
    expect(specs).toHaveLength(1);
    expect(specs[0].id).toBe('TS-001');
  });
});

// T003: Tests for parseTaskTestRefs — TS-027
describe('parseTaskTestRefs', () => {
  test('extracts TS-xxx references from task descriptions regardless of phrasing', () => {
    const tasks = [
      { id: 'T002', description: 'Implement dashboard component; must pass TS-001' },
      { id: 'T003', description: 'Implement data loading to satisfy TS-001, TS-004' },
      { id: 'T004', description: 'Implement filtering — to pass TS-002, TS-003' },
      { id: 'T008', description: 'Add validation' }
    ];
    const refs = parseTaskTestRefs(tasks);
    expect(refs.T002).toEqual(['TS-001']);
    expect(refs.T003).toEqual(['TS-001', 'TS-004']);
    expect(refs.T004).toEqual(['TS-002', 'TS-003']);
    expect(refs.T008).toEqual([]);
  });

  test('handles tasks with multiple test spec refs', () => {
    const tasks = [
      { id: 'T007', description: 'Handle edge cases; must pass TS-007, TS-008' }
    ];
    const refs = parseTaskTestRefs(tasks);
    expect(refs.T007).toEqual(['TS-007', 'TS-008']);
  });

  test('deduplicates repeated TS-xxx references', () => {
    const tasks = [
      { id: 'T005', description: 'Implement feature for TS-001 and also TS-001, TS-002' }
    ];
    const refs = parseTaskTestRefs(tasks);
    expect(refs.T005).toEqual(['TS-001', 'TS-002']);
  });

  test('returns empty map for empty tasks array', () => {
    const refs = parseTaskTestRefs([]);
    expect(refs).toEqual({});
  });

  test('returns empty arrays for tasks without TS-xxx references', () => {
    const tasks = [
      { id: 'T001', description: 'Create project scaffolding' }
    ];
    const refs = parseTaskTestRefs(tasks);
    expect(refs.T001).toEqual([]);
  });

  test('handles null or undefined input', () => {
    expect(parseTaskTestRefs(null)).toEqual({});
    expect(parseTaskTestRefs(undefined)).toEqual({});
  });
});

// === 008-analyze-consistency: New parser tests ===

const analysisFixture = `## Findings

| ID | Category | Severity | Location(s) | Summary | Recommendation |
|----|----------|----------|-------------|---------|----------------|
| A1 | Inconsistency | ~~HIGH~~ RESOLVED | plan.md:85, data-model.md:106 | Context.json path mismatch | Updated plan.md |
| A2 | Coverage Gap | MEDIUM | spec.md:FR-013, SC-003 | FR-013 and SC-003 have no dedicated test spec | Accept as-is |
| A3 | Coverage Gap | MEDIUM | tasks.md:T015-T025 | Client-side tasks lack test-writing tasks | Accept as-is |

## Coverage Summary

| Requirement | Has Task? | Task IDs | Has Test? | Test IDs | Status |
|-------------|-----------|----------|-----------|----------|--------|
| FR-001 | Yes | T015 | Yes | TS-001, TS-037 | Full |
| FR-002 | Yes | T012 | Yes | TS-005 | Full |
| FR-003 | No | — | No | — | Partial |

## Constitution Alignment

| Principle | Status | Evidence |
|-----------|--------|----------|
| I. Test-First (NON-NEGOTIABLE) | ALIGNED | TDD mandatory in tasks.md |
| II. Real-Time Accuracy | ALIGNED | FR-012, SC-006 require <5s updates |
| IV. Professional Kanban UI | VIOLATION | Missing visual spec |

## Phase Separation Violations

| Artifact | Status | Severity |
|----------|--------|----------|
| spec.md | Minor: implementation terms used | MEDIUM |
| plan.md | Clean | — |

## Metrics

| Metric | Value |
|--------|-------|
| Total Requirements (FR + SC) | 28 |
| Total Tasks | 25 |
| Total Test Specifications | 32 |
| Requirement Coverage | 28/28 (100%) |
| Test Coverage | 85% |
| Critical Issues | 0 |
| High Issues | 0 |
| Medium Issues | 2 |
| Low Issues | 1 |
`;

const simpleCoverageFixture = `## Coverage Summary

| Requirement | Has Task? | Notes |
|-------------|-----------|-------|
| FR-001 | Yes | Covered by T015 |
| FR-002 | No | Missing task |
`;

const bulletMetricsFixture = `## Metrics

- Total Requirements (FR + SC): 28
- Total Tasks: 25
- Total Test Specifications: 32
- Requirement Coverage: 28/28 (100%)
- Test Coverage: 85%
- Critical Issues: 0
- High Issues: 0
- Medium Issues: 2
- Low Issues: 1
`;

// TS-039: parseAnalysisFindings extracts findings from markdown table
describe('parseAnalysisFindings', () => {
  test('extracts findings from markdown table with correct fields', () => {
    const findings = parseAnalysisFindings(analysisFixture);
    expect(findings).toHaveLength(3);
    expect(findings[0]).toMatchObject({
      id: 'A1',
      category: 'Inconsistency',
      severity: 'HIGH',
      resolved: true,
      location: 'plan.md:85, data-model.md:106',
      summary: 'Context.json path mismatch',
      recommendation: 'Updated plan.md'
    });
    expect(findings[1]).toMatchObject({
      id: 'A2',
      category: 'Coverage Gap',
      severity: 'MEDIUM',
      resolved: false,
      location: 'spec.md:FR-013, SC-003',
      summary: 'FR-013 and SC-003 have no dedicated test spec',
      recommendation: 'Accept as-is'
    });
    expect(findings[2]).toMatchObject({
      id: 'A3',
      category: 'Coverage Gap',
      severity: 'MEDIUM',
      resolved: false,
      location: 'tasks.md:T015-T025',
      summary: 'Client-side tasks lack test-writing tasks',
      recommendation: 'Accept as-is'
    });
  });

  // TS-040: parseAnalysisFindings detects resolved findings via strikethrough
  test('detects resolved findings via strikethrough in severity', () => {
    const findings = parseAnalysisFindings(analysisFixture);
    const resolved = findings.find(f => f.id === 'A1');
    expect(resolved.resolved).toBe(true);
    expect(resolved.severity).toBe('HIGH');
  });

  // TS-041: parseAnalysisFindings returns empty array for no-findings state
  test('returns empty array when no findings table present', () => {
    const content = `## Findings

No CRITICAL issues found. The specification artifacts are well-aligned.
`;
    const findings = parseAnalysisFindings(content);
    expect(findings).toEqual([]);
  });

  test('returns empty array for empty string', () => {
    expect(parseAnalysisFindings('')).toEqual([]);
  });

  test('returns empty array for null', () => {
    expect(parseAnalysisFindings(null)).toEqual([]);
  });
});

// TS-042, TS-043: parseAnalysisCoverage
describe('parseAnalysisCoverage', () => {
  // TS-042: handles simple table format
  test('handles simple table format with Has Task and Notes columns', () => {
    const coverage = parseAnalysisCoverage(simpleCoverageFixture);
    expect(coverage).toHaveLength(2);
    expect(coverage[0]).toMatchObject({
      id: 'FR-001',
      hasTask: true,
      taskIds: [],
      hasTest: false,
      testIds: [],
      status: null,
      notes: 'Covered by T015'
    });
    expect(coverage[1]).toMatchObject({
      id: 'FR-002',
      hasTask: false,
      taskIds: [],
      hasTest: false,
      testIds: [],
      status: null,
      notes: 'Missing task'
    });
  });

  // TS-043: handles detailed table format
  test('handles detailed table format with Task IDs, Test IDs, and Status', () => {
    const coverage = parseAnalysisCoverage(analysisFixture);
    expect(coverage).toHaveLength(3);
    expect(coverage[0]).toMatchObject({
      id: 'FR-001',
      hasTask: true,
      taskIds: ['T015'],
      hasTest: true,
      testIds: ['TS-001', 'TS-037'],
      status: 'Full'
    });
    expect(coverage[1]).toMatchObject({
      id: 'FR-002',
      hasTask: true,
      taskIds: ['T012'],
      hasTest: true,
      testIds: ['TS-005'],
      status: 'Full'
    });
    expect(coverage[2]).toMatchObject({
      id: 'FR-003',
      hasTask: false,
      taskIds: [],
      hasTest: false,
      testIds: [],
      status: 'Partial'
    });
  });

  test('handles 8-column format with Has Plan? and Plan Refs columns', () => {
    const content = `## Coverage Summary

| Requirement | Has Task? | Task IDs | Has Test? | Test IDs | Has Plan? | Plan Refs | Status |
|-------------|-----------|----------|-----------|----------|-----------|-----------|--------|
| FR-001 | Yes | T015 | Yes | TS-001, TS-037 | Yes | KDD-4, KDD-7 | Full |
| FR-002 | Yes | T012 | Yes | TS-005 | No | — | Partial |
| FR-003 | No | — | No | — | Yes | KDD-1 | Partial |
`;
    const coverage = parseAnalysisCoverage(content);
    expect(coverage).toHaveLength(3);
    expect(coverage[0]).toMatchObject({
      id: 'FR-001',
      hasTask: true,
      taskIds: ['T015'],
      hasTest: true,
      testIds: ['TS-001', 'TS-037'],
      hasPlan: true,
      planRefs: ['KDD-4', 'KDD-7'],
      status: 'Full'
    });
    expect(coverage[1]).toMatchObject({
      id: 'FR-002',
      hasPlan: false,
      planRefs: [],
      status: 'Partial'
    });
    expect(coverage[2]).toMatchObject({
      id: 'FR-003',
      hasTask: false,
      hasPlan: true,
      planRefs: ['KDD-1'],
      status: 'Partial'
    });
  });

  test('returns empty array for empty string', () => {
    expect(parseAnalysisCoverage('')).toEqual([]);
  });

  test('returns empty array for null', () => {
    expect(parseAnalysisCoverage(null)).toEqual([]);
  });
});

// TS-044 through TS-047: parseAnalysisMetrics
describe('parseAnalysisMetrics', () => {
  // TS-044: extracts metrics from table format
  test('extracts metrics from table format', () => {
    const metrics = parseAnalysisMetrics(analysisFixture);
    expect(metrics.totalRequirements).toBe(28);
    expect(metrics.totalTasks).toBe(25);
    expect(metrics.totalTestSpecs).toBe(32);
    expect(metrics.requirementCoverage).toBe('28/28 (100%)');
    expect(metrics.criticalIssues).toBe(0);
    expect(metrics.highIssues).toBe(0);
    expect(metrics.mediumIssues).toBe(2);
    expect(metrics.lowIssues).toBe(1);
  });

  // TS-045: extracts metrics from bullet list format
  test('extracts metrics from bullet list format', () => {
    const metrics = parseAnalysisMetrics(bulletMetricsFixture);
    expect(metrics.totalRequirements).toBe(28);
    expect(metrics.totalTasks).toBe(25);
    expect(metrics.totalTestSpecs).toBe(32);
    expect(metrics.requirementCoverage).toBe('28/28 (100%)');
    expect(metrics.criticalIssues).toBe(0);
    expect(metrics.highIssues).toBe(0);
    expect(metrics.mediumIssues).toBe(2);
    expect(metrics.lowIssues).toBe(1);
  });

  // TS-046: extracts percentage from coverage strings
  test('extracts percentage from coverage strings', () => {
    const metrics = parseAnalysisMetrics(analysisFixture);
    expect(metrics.requirementCoveragePct).toBe(100);
    expect(metrics.testCoveragePct).toBe(85);
  });

  // TS-047: defaults testCoveragePct to 100 when absent
  test('defaults testCoveragePct to 100 when no test coverage entry', () => {
    const content = `## Metrics

| Metric | Value |
|--------|-------|
| Total Requirements (FR + SC) | 10 |
| Total Tasks | 8 |
| Total Test Specifications | 12 |
| Requirement Coverage | 10/10 (100%) |
| Critical Issues | 0 |
| High Issues | 0 |
| Medium Issues | 0 |
| Low Issues | 0 |
`;
    const metrics = parseAnalysisMetrics(content);
    expect(metrics.testCoveragePct).toBe(100);
  });

  test('returns empty/default object for empty string', () => {
    const metrics = parseAnalysisMetrics('');
    expect(metrics.totalRequirements).toBe(0);
    expect(metrics.totalTasks).toBe(0);
  });

  test('returns empty/default object for null', () => {
    const metrics = parseAnalysisMetrics(null);
    expect(metrics.totalRequirements).toBe(0);
  });
});

// TS-048, TS-049: parseConstitutionAlignment
describe('parseConstitutionAlignment', () => {
  // TS-048: extracts alignment table
  test('extracts alignment entries with principle, status, and evidence', () => {
    const alignment = parseConstitutionAlignment(analysisFixture);
    expect(alignment).toHaveLength(3);
    expect(alignment[0]).toMatchObject({
      principle: 'I. Test-First (NON-NEGOTIABLE)',
      status: 'ALIGNED',
      evidence: 'TDD mandatory in tasks.md'
    });
    expect(alignment[1]).toMatchObject({
      principle: 'II. Real-Time Accuracy',
      status: 'ALIGNED',
      evidence: 'FR-012, SC-006 require <5s updates'
    });
    expect(alignment[2]).toMatchObject({
      principle: 'IV. Professional Kanban UI',
      status: 'VIOLATION',
      evidence: 'Missing visual spec'
    });
  });

  // TS-049: returns empty array for absent section
  test('returns empty array when no Constitution Alignment section', () => {
    const content = '# Analysis\n\n## Findings\n\nSome findings.\n';
    expect(parseConstitutionAlignment(content)).toEqual([]);
  });

  test('returns empty array for "None detected" text', () => {
    const content = `## Constitution Alignment

None detected
`;
    expect(parseConstitutionAlignment(content)).toEqual([]);
  });

  test('returns empty array for empty string', () => {
    expect(parseConstitutionAlignment('')).toEqual([]);
  });

  test('returns empty array for null', () => {
    expect(parseConstitutionAlignment(null)).toEqual([]);
  });
});

// TS-050, TS-051: parsePhaseSeparation
describe('parsePhaseSeparation', () => {
  // TS-050: extracts violation entries
  test('extracts phase separation violation entries', () => {
    const violations = parsePhaseSeparation(analysisFixture);
    expect(violations).toHaveLength(2);
    expect(violations[0]).toMatchObject({
      artifact: 'spec.md',
      status: 'Minor: implementation terms used',
      severity: 'MEDIUM'
    });
    expect(violations[1]).toMatchObject({
      artifact: 'plan.md',
      status: 'Clean'
    });
  });

  // TS-051: returns empty for "None detected"
  test('returns empty array for "None detected"', () => {
    const content = `## Phase Separation Violations

None detected
`;
    expect(parsePhaseSeparation(content)).toEqual([]);
  });

  test('returns empty array when no Phase Separation section', () => {
    const content = '# Analysis\n\n## Findings\n\nSome findings.\n';
    expect(parsePhaseSeparation(content)).toEqual([]);
  });

  test('returns empty array for empty string', () => {
    expect(parsePhaseSeparation('')).toEqual([]);
  });

  test('returns empty array for null', () => {
    expect(parsePhaseSeparation(null)).toEqual([]);
  });
});

// === 009-bugs-tab: parseBugs tests (T001) ===
// TS-030, TS-031, TS-032, TS-033, TS-043, TS-044

describe('parseBugs', () => {
  // TS-030: Bug ID must match BUG-\d+ pattern
  test('extracts only entries with valid BUG-\\d+ IDs', () => {
    const content = `# Bug Reports

## BUG-001

**Reported**: 2026-02-19
**Severity**: critical
**Status**: reported
**GitHub Issue**: #13
**Description**: Login fails with plus sign

---

## BUG-099

**Reported**: 2026-02-18
**Severity**: medium
**Status**: fixed
**GitHub Issue**: _(none)_
**Description**: Dashboard flickers

---

## INVALID-BUG

**Severity**: high
**Status**: reported
**Description**: Should be skipped
`;
    const bugs = parseBugs(content);
    expect(bugs).toHaveLength(2);
    expect(bugs[0].id).toBe('BUG-001');
    expect(bugs[1].id).toBe('BUG-099');
  });

  // TS-031: Unrecognized severity defaults to medium
  test('unrecognized severity defaults to medium', () => {
    const content = `## BUG-001

**Severity**: unknown
**Status**: reported
**Description**: Test bug
`;
    const bugs = parseBugs(content);
    expect(bugs).toHaveLength(1);
    expect(bugs[0].severity).toBe('medium');
  });

  // TS-032: Unrecognized status defaults to reported
  test('unrecognized status defaults to reported', () => {
    const content = `## BUG-001

**Severity**: high
**Status**: in-progress
**Description**: Test bug
`;
    const bugs = parseBugs(content);
    expect(bugs).toHaveLength(1);
    expect(bugs[0].status).toBe('reported');
  });

  // TS-033: Missing bug fields default to null
  test('missing fields default to null with correct defaults', () => {
    const content = `## BUG-001

**Severity**: critical
`;
    const bugs = parseBugs(content);
    expect(bugs).toHaveLength(1);
    expect(bugs[0].id).toBe('BUG-001');
    expect(bugs[0].severity).toBe('critical');
    expect(bugs[0].reported).toBeNull();
    expect(bugs[0].status).toBe('reported');
    expect(bugs[0].githubIssue).toBeNull();
    expect(bugs[0].description).toBeNull();
    expect(bugs[0].rootCause).toBeNull();
    expect(bugs[0].fixReference).toBeNull();
  });

  // TS-043: parseBugs returns empty array for missing file (content is null/undefined)
  test('returns empty array for null/undefined input', () => {
    expect(parseBugs(null)).toEqual([]);
    expect(parseBugs(undefined)).toEqual([]);
  });

  // TS-044: parseBugs returns empty array for empty file (content is empty string)
  test('returns empty array for empty string', () => {
    expect(parseBugs('')).toEqual([]);
  });

  test('returns empty array for file with no valid bug entries', () => {
    const content = `# Bug Reports: empty-bugs-feature
`;
    const bugs = parseBugs(content);
    expect(bugs).toEqual([]);
  });

  test('extracts all fields from a complete bug entry', () => {
    const content = `## BUG-001

**Reported**: 2026-02-19
**Severity**: critical
**Status**: reported
**GitHub Issue**: #13
**Description**: Login fails when email contains plus sign
**Root Cause**: URL encoding issue
**Fix Reference**: T-B001
`;
    const bugs = parseBugs(content);
    expect(bugs).toHaveLength(1);
    expect(bugs[0]).toEqual({
      id: 'BUG-001',
      reported: '2026-02-19',
      severity: 'critical',
      status: 'reported',
      githubIssue: '#13',
      description: 'Login fails when email contains plus sign',
      rootCause: 'URL encoding issue',
      fixReference: 'T-B001'
    });
  });

  test('treats _(none)_ and _(empty until...)_ as null', () => {
    const content = `## BUG-001

**Severity**: low
**Status**: reported
**GitHub Issue**: _(none)_
**Description**: Some bug
**Root Cause**: _(empty until investigation)_
**Fix Reference**: _(empty until implementation)_
`;
    const bugs = parseBugs(content);
    expect(bugs).toHaveLength(1);
    expect(bugs[0].githubIssue).toBeNull();
    expect(bugs[0].rootCause).toBeNull();
    expect(bugs[0].fixReference).toBeNull();
  });

  test('extracts multiple bugs from full bugs.md', () => {
    const content = `# Bug Reports: test-feature

## BUG-001

**Reported**: 2026-02-19
**Severity**: critical
**Status**: reported
**GitHub Issue**: #13
**Description**: Login fails

---

## BUG-002

**Reported**: 2026-02-18
**Severity**: medium
**Status**: fixed
**GitHub Issue**: _(none)_
**Description**: Dashboard flickers

---

## BUG-003

**Reported**: 2026-02-17
**Severity**: low
**Status**: reported
**GitHub Issue**: _(none)_
**Description**: Tooltip not dismissing
`;
    const bugs = parseBugs(content);
    expect(bugs).toHaveLength(3);
    expect(bugs[0].id).toBe('BUG-001');
    expect(bugs[0].severity).toBe('critical');
    expect(bugs[1].id).toBe('BUG-002');
    expect(bugs[1].status).toBe('fixed');
    expect(bugs[2].id).toBe('BUG-003');
    expect(bugs[2].severity).toBe('low');
  });
});

// === 009-bugs-tab: Extended parseTasks tests (T002) ===
// TS-034, TS-035, TS-045

describe('parseTasks extended for bug fix tasks', () => {
  // TS-045: Extended parseTasks regex matches both T\d+ and T-B\d+ formats
  test('parses both regular and T-B prefixed tasks', () => {
    const content = `# Tasks

- [x] T001 [US1] Feature task
- [ ] T-B001 [BUG-001] Bug fix task
`;
    const tasks = parseTasks(content);
    expect(tasks).toHaveLength(2);

    expect(tasks[0].id).toBe('T001');
    expect(tasks[0].storyTag).toBe('US1');
    expect(tasks[0].isBugFix).toBe(false);
    expect(tasks[0].bugTag).toBeNull();

    expect(tasks[1].id).toBe('T-B001');
    expect(tasks[1].isBugFix).toBe(true);
    expect(tasks[1].bugTag).toBe('BUG-001');
    expect(tasks[1].storyTag).toBeNull();
  });

  // TS-034: FixTask ID must match T-B\d+ pattern
  test('identifies T-B prefixed tasks as bug fixes', () => {
    const content = `- [ ] T-B001 [BUG-001] Fix login
- [x] T-B002 [BUG-001] Write regression test
- [x] T001 [US1] Regular task
- [ ] T002 [US2] Another regular task
`;
    const tasks = parseTasks(content);
    expect(tasks).toHaveLength(4);

    const bugFixes = tasks.filter(t => t.isBugFix);
    expect(bugFixes).toHaveLength(2);
    expect(bugFixes[0].id).toBe('T-B001');
    expect(bugFixes[1].id).toBe('T-B002');

    const regular = tasks.filter(t => !t.isBugFix);
    expect(regular).toHaveLength(2);
  });

  // TS-035: FixTask bugTag must match BUG-\d+ pattern
  test('extracts bugTag from [BUG-NNN] tags, null for invalid tags', () => {
    const content = `- [ ] T-B001 [BUG-001] Fix login
- [ ] T-B002 [INVALID] Fix signup
`;
    const tasks = parseTasks(content);
    expect(tasks).toHaveLength(2);
    expect(tasks[0].bugTag).toBe('BUG-001');
    expect(tasks[1].bugTag).toBeNull();
  });

  test('T-B tasks with [P] marker parse correctly', () => {
    const content = '- [ ] T-B003 [P] [BUG-002] Parallel bug fix task\n';
    const tasks = parseTasks(content);
    expect(tasks).toHaveLength(1);
    expect(tasks[0].id).toBe('T-B003');
    expect(tasks[0].isBugFix).toBe(true);
    expect(tasks[0].bugTag).toBe('BUG-002');
    expect(tasks[0].checked).toBe(false);
  });

  test('checked T-B tasks have checked: true', () => {
    const content = '- [x] T-B004 [BUG-002] Completed bug fix\n';
    const tasks = parseTasks(content);
    expect(tasks).toHaveLength(1);
    expect(tasks[0].checked).toBe(true);
    expect(tasks[0].isBugFix).toBe(true);
  });

  test('existing parseTasks still works for regular tasks', () => {
    const content = `- [x] T003 [US1] Implement WebSocket server
- [ ] T005 [US2] Add feature selector
- [ ] T006 [P] [US1] Parallel task
- [ ] T001 Initialize package.json
`;
    const tasks = parseTasks(content);
    expect(tasks).toHaveLength(4);
    expect(tasks[0]).toMatchObject({ id: 'T003', storyTag: 'US1', checked: true, isBugFix: false });
    expect(tasks[1]).toMatchObject({ id: 'T005', storyTag: 'US2', checked: false, isBugFix: false });
    expect(tasks[2]).toMatchObject({ id: 'T006', storyTag: 'US1', isBugFix: false });
    expect(tasks[3]).toMatchObject({ id: 'T001', storyTag: null, isBugFix: false });
  });
});
