# Test Specifications: Test Feature

**Generated**: 2026-02-17

## From spec.md (Acceptance Tests)

### TS-001: Dashboard displays on load

**Source**: spec.md:User Story 1:scenario-1
**Type**: acceptance
**Priority**: P1

**Given**: a project with valid data
**When**: the dashboard loads
**Then**: all components render correctly

**Traceability**: FR-001, SC-001, US-001-scenario-1

---

### TS-002: Filtering works correctly

**Source**: spec.md:User Story 2:scenario-1
**Type**: acceptance
**Priority**: P2

**Given**: a dashboard with items
**When**: a filter is applied
**Then**: only matching items are shown

**Traceability**: FR-002, SC-002, US-002-scenario-1

---

### TS-003: Multi-requirement coverage

**Source**: spec.md:User Story 1:scenario-2
**Type**: acceptance
**Priority**: P1

**Given**: a feature with multiple requirements
**When**: the dashboard loads
**Then**: all requirements are represented

**Traceability**: FR-001, FR-002, SC-001, US-001-scenario-2

---

## From plan.md (Contract Tests)

### TS-004: API returns correct response

**Source**: plan.md:API Contract:GET /api/data
**Type**: contract
**Priority**: P1

**Given**: a valid feature
**When**: GET /api/data is called
**Then**: response contains expected shape

**Traceability**: FR-001, FR-003

---

### TS-005: WebSocket pushes updates

**Source**: plan.md:API Contract:WebSocket
**Type**: contract
**Priority**: P1

**Given**: a connected client
**When**: data changes on disk
**Then**: update message is sent

**Traceability**: FR-003, SC-002

---

## From data-model.md (Validation Tests)

### TS-006: Parser extracts IDs correctly

**Source**: data-model.md:parsing rules
**Type**: validation
**Priority**: P2

**Given**: well-formed markdown content
**When**: parser runs
**Then**: all IDs are extracted

**Traceability**: FR-001

---

### TS-007: Edge derivation handles orphans

**Source**: data-model.md:Edge:orphan handling
**Type**: validation
**Priority**: P2

**Given**: references to non-existent entities
**When**: edges are derived
**Then**: orphaned references are ignored

**Traceability**: FR-002, FR-005

---

### TS-008: Gap computation is correct

**Source**: data-model.md:GapReport
**Type**: validation
**Priority**: P2

**Given**: a set of nodes and edges
**When**: gaps are computed
**Then**: untested requirements and unimplemented tests are identified

**Traceability**: FR-004, SC-003
