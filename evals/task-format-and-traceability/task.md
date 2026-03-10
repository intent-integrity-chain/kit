# Task Breakdown for an Inventory Management API

## Problem/Feature Description

A logistics company is building a REST API to manage warehouse inventory. The team has completed the feature spec and technical plan and now needs a detailed, dependency-ordered task list that developers can work from. The engineering manager wants the breakdown to clearly show which tasks can run in parallel (so the team can assign them to different engineers simultaneously), which belong to which user story, and how test scenarios map to implementation tasks.

The team recently had problems with task lists that used vague prose to reference test ranges (like "tests 5 through 10") which broke their automated traceability tooling. They need explicit, individually listed test IDs.

## Output Specification

Produce a `tasks.md` file organized into clear phases with all required metadata. Include a brief `tasks-report.md` summarizing the total task count, number of parallelizable tasks, and the phase structure used.

## Input Files

The following files are provided as inputs. Extract them before beginning.

=============== FILE: specs/002-inventory/spec.md ===============
# Feature Specification: Inventory Management API

## User Stories

### US-1: Add Inventory Item (Priority: P1)

As a warehouse manager, I want to add new items to the inventory so the system tracks what we have in stock.

**Functional Requirements:**
- FR-001: Items must have a SKU, name, quantity, and unit price.
- FR-002: SKUs must be unique across the inventory.
- FR-003: Item creation must be logged with a timestamp and user ID.

**Acceptance Scenarios:**
1. Given a warehouse manager, When they submit a valid new item, Then the item is saved and a 201 response is returned.
2. Given a duplicate SKU, When item creation is attempted, Then a 409 error is returned.

**Success Criteria:**
- SC-001: Item creation completes in under 200ms for 99% of requests.
- SC-002: All item creation events are logged with timestamp and user ID.

### US-2: Update Stock Quantity (Priority: P1)

As a warehouse worker, I want to update the quantity of an existing item so the system reflects current stock levels.

**Functional Requirements:**
- FR-004: Quantity updates must support absolute set and relative delta operations.
- FR-005: Quantity cannot be set below 0.
- FR-006: All quantity changes must be logged with before/after values.

**Acceptance Scenarios:**
1. Given an existing item, When quantity is updated to 50, Then quantity is 50 and a 200 response is returned.
2. Given an item with quantity 10, When a delta of -20 is applied, Then a 400 error is returned (negative stock not allowed).
3. Given a quantity update, When it succeeds, Then the change is logged with before and after values.

**Success Criteria:**
- SC-003: Quantity updates are idempotent when using absolute set operations.
- SC-004: Zero tolerance for quantity going below 0.

### US-3: Search Inventory (Priority: P2)

As a logistics analyst, I want to search inventory by SKU, name, or category so I can find items quickly.

**Functional Requirements:**
- FR-007: Search must support partial match on name and exact match on SKU.
- FR-008: Results must be paginated with a maximum of 50 items per page.

**Acceptance Scenarios:**
1. Given inventory with 200 items, When a search for name containing "bolt" is submitted, Then matching items are returned paginated.
2. Given a specific SKU, When an exact search is submitted, Then only that item is returned.

**Success Criteria:**
- SC-005: Search returns results in under 500ms for collections up to 100,000 items.

=============== FILE: specs/002-inventory/plan.md ===============
# Technical Plan: Inventory Management API

## Technical Context

- **Language/Version**: Python 3.11
- **Primary Framework**: FastAPI 0.104
- **Storage**: PostgreSQL 15 with SQLAlchemy 2.0 ORM
- **Testing**: pytest with pytest-asyncio, httpx for test client
- **Package Manager**: pip with pyproject.toml
- **Target Platform**: Linux/Docker

## Project Structure

```
src/
  models/item.py          # SQLAlchemy Item model
  schemas/item.py         # Pydantic request/response schemas
  services/inventory.py   # Business logic
  routers/inventory.py    # FastAPI route handlers
  database.py             # DB connection and session management
tests/
  features/               # BDD .feature files (already generated)
    add_item.feature
    update_quantity.feature
    search_inventory.feature
  step_definitions/       # To be created
  conftest.py             # Test fixtures
pyproject.toml
```

## Test Spec IDs

The following test spec IDs from the .feature files map to user stories:
- US-1 scenarios: TS-001, TS-002
- US-2 scenarios: TS-003, TS-004, TS-005
- US-3 scenarios: TS-006, TS-007
