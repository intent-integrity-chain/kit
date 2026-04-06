# Plan-to-Tasks Traceability: Event Ticketing Platform

## Problem/Feature Description

A startup is building an event ticketing platform. The team has already completed the feature specification and technical plan for their core ticketing feature. Now they need a task breakdown that developers can work from.

Your job is to generate `tasks.md` from the provided spec and plan artifacts.

## Output Specification

Produce the following files:
- `specs/006-event-tickets/tasks.md` — the dependency-ordered task breakdown
- `tasks-report.md` — summary of total tasks, parallelizable count, and phase structure

## Input Files

The following files are provided as inputs. Extract them before beginning.

=============== FILE: specs/006-event-tickets/spec.md ===============
# Feature Specification: Event Ticketing

## User Stories

### US-1: Create Event (Priority: P1)

As an event organizer, I want to create an event with ticket tiers so attendees can purchase tickets at different price points.

**Functional Requirements:**
- FR-001: Events must have a title, date, venue, and description.
- FR-002: Each event supports 1-5 ticket tiers with name, price, and quantity.
- FR-003: Event creation must validate that the event date is in the future.

**Acceptance Scenarios:**
1. Given an organizer, When they create an event with 2 ticket tiers, Then the event is saved with both tiers.
2. Given an event date in the past, When creation is attempted, Then a validation error is returned.

**Success Criteria:**
- SC-001: Event creation completes in under 300ms for 99% of requests.

### US-2: Purchase Ticket (Priority: P1)

As an attendee, I want to purchase a ticket for an event so I can attend.

**Functional Requirements:**
- FR-004: Ticket purchase must atomically decrement available quantity.
- FR-005: Purchase must fail if the tier is sold out.
- FR-006: A confirmation with a unique ticket code must be generated on purchase.
- FR-007: Purchase records must include buyer email, tier, timestamp, and amount paid.

**Acceptance Scenarios:**
1. Given an event with 10 tickets available, When a purchase is made, Then quantity drops to 9 and a ticket code is returned.
2. Given a sold-out tier, When a purchase is attempted, Then a 409 error is returned.
3. Given a successful purchase, When the buyer checks their email, Then a confirmation with the ticket code is delivered.

**Success Criteria:**
- SC-002: Concurrent purchases for the last ticket must not oversell (zero tolerance).
- SC-003: Confirmation emails sent within 60 seconds of purchase.

### US-3: View Event Listings (Priority: P2)

As an attendee, I want to browse upcoming events so I can find events I'm interested in.

**Functional Requirements:**
- FR-008: Listings must show title, date, venue, and cheapest available tier price.
- FR-009: Results must be paginated with 20 items per page, sorted by date ascending.
- FR-010: Sold-out events must still appear but be marked as sold out.

**Acceptance Scenarios:**
1. Given 50 upcoming events, When page 1 is requested, Then 20 events are returned sorted by date.
2. Given a sold-out event, When listings are viewed, Then the event appears with a sold-out badge.

**Success Criteria:**
- SC-004: Listings load in under 200ms for up to 10,000 events.

=============== FILE: specs/006-event-tickets/plan.md ===============
# Technical Plan: Event Ticketing

## Technical Context

- **Language/Version**: TypeScript 5.3
- **Primary Framework**: Express.js 4.18 with Zod validation
- **Storage**: PostgreSQL 16 with Prisma ORM
- **Testing**: Vitest with Supertest for API integration tests
- **Package Manager**: pnpm with package.json
- **Target Platform**: Linux/Docker
- **Email**: Resend SDK for transactional emails

## Project Structure

```
src/
  models/event.ts            # Prisma schema and types for Event
  models/ticket-tier.ts      # Prisma schema and types for TicketTier
  models/purchase.ts         # Prisma schema and types for Purchase
  schemas/event.ts           # Zod validation schemas for event endpoints
  schemas/purchase.ts        # Zod validation schemas for purchase endpoints
  services/event-service.ts  # Event creation and listing business logic
  services/purchase-service.ts # Ticket purchase with atomic quantity decrement
  services/email-service.ts  # Confirmation email dispatch via Resend
  routes/events.ts           # Express route handlers for /events
  routes/purchases.ts        # Express route handlers for /purchases
  middleware/error-handler.ts # Centralized error handling
  database.ts                # Prisma client initialization
tests/
  features/                  # BDD .feature files
    create_event.feature
    purchase_ticket.feature
    view_listings.feature
  integration/
    events.test.ts
    purchases.test.ts
    listings.test.ts
  conftest.ts                # Shared test fixtures
prisma/
  schema.prisma              # Database schema
package.json
```

## Data Model Summary

- **Event**: id, title, date, venue, description, createdAt
- **TicketTier**: id, eventId (FK), name, price, totalQuantity, availableQuantity
- **Purchase**: id, tierId (FK), buyerEmail, ticketCode (unique), amount, createdAt

=============== FILE: specs/006-event-tickets/tests/features/create_event.feature ===============
# DO NOT MODIFY SCENARIOS

@US-001
Feature: Create Event

  @TS-001 @FR-001 @FR-002 @SC-001 @US-001 @P1 @acceptance
  Scenario: Create event with multiple ticket tiers
    Given an authenticated event organizer
    When they create an event with title "Summer Fest" and 2 ticket tiers
    Then the event is saved with both tiers and a 201 response is returned

  @TS-002 @FR-003 @US-001 @P1 @validation
  Scenario: Reject event with past date
    Given an authenticated event organizer
    When they attempt to create an event with a date in the past
    Then a 400 validation error is returned

=============== FILE: specs/006-event-tickets/tests/features/purchase_ticket.feature ===============
# DO NOT MODIFY SCENARIOS

@US-002
Feature: Purchase Ticket

  @TS-003 @FR-004 @FR-006 @FR-007 @SC-001 @US-002 @P1 @acceptance
  Scenario: Successful ticket purchase
    Given an event "Summer Fest" with 10 General Admission tickets available
    When a buyer purchases 1 General Admission ticket
    Then available quantity drops to 9 and a unique ticket code is returned

  @TS-004 @FR-005 @US-002 @P1 @acceptance
  Scenario: Purchase from sold-out tier
    Given an event "Summer Fest" with 0 General Admission tickets available
    When a buyer attempts to purchase a General Admission ticket
    Then a 409 sold-out error is returned

  @TS-005 @FR-006 @SC-003 @US-002 @P1 @acceptance
  Scenario: Confirmation email sent after purchase
    Given a buyer has successfully purchased a ticket
    When the purchase is confirmed
    Then a confirmation email with the ticket code is sent within 60 seconds

=============== FILE: specs/006-event-tickets/tests/features/view_listings.feature ===============
# DO NOT MODIFY SCENARIOS

@US-003
Feature: View Event Listings

  @TS-006 @FR-008 @FR-009 @SC-004 @US-003 @P2 @acceptance
  Scenario: Browse paginated event listings
    Given 50 upcoming events exist in the system
    When page 1 of event listings is requested
    Then 20 events are returned sorted by date ascending with cheapest tier price

  @TS-007 @FR-010 @US-003 @P2 @acceptance
  Scenario: Sold-out events appear with badge
    Given an event where all ticket tiers have 0 available quantity
    When event listings are viewed
    Then the sold-out event appears with a sold-out indicator

=============== FILE: .specify/context.json ===============
{
  "tdd_determination": "optional",
  "active_feature": "006-event-tickets"
}
