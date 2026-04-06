# TDD Pipeline with Constitution Enforcement: Appointment Scheduling API

## Problem/Feature Description

A healthcare clinic chain is building an appointment scheduling API. The team already has a completed specification and technical plan with 3 user stories and 10 functional requirements.

Your job is to produce BDD test specifications from the existing spec and plan, then generate the task breakdown. Both outputs must be complete — cover the full spec.

## Output Specification

Produce the following files in order:
1. `specs/010-appointments/tests/features/*.feature` — BDD test specifications
2. `specs/010-appointments/tasks.md` — dependency-ordered task breakdown

Also produce a brief `pipeline-report.md` summarizing the artifacts generated.

## Input Files

The following files are provided as inputs. Extract them before beginning.

=============== FILE: CONSTITUTION.md ===============
# Project Constitution v1.0.0

## Principles

### P1: Test-Driven Development
Test-first MUST be used for all features. Test specifications MUST be written and reviewed before any implementation task begins. Every implementation task MUST reference the TS-XXX test scenario(s) it satisfies. Modifying test assertions to make failing tests pass is PROHIBITED — fix the production code instead.

### P2: Patient Data Protection
All patient-identifiable information MUST be encrypted at rest and in transit. Appointment details MUST only be visible to the patient and the assigned provider. API endpoints handling patient data MUST require authentication.

### P3: Availability
The scheduling system MUST support concurrent booking without double-booking. Conflict detection MUST be atomic — no race conditions in slot allocation.

## Amendment Procedure

P1 and P2 are immutable. Other amendments require medical director sign-off.

=============== FILE: specs/010-appointments/spec.md ===============
# Feature Specification: Appointment Scheduling

## User Stories

### US-1: Book Appointment (Priority: P1)

As a patient, I want to book an appointment with a provider at an available time slot so I can receive care.

**Functional Requirements:**
- FR-001: Patients must select a provider, date, and time slot to book an appointment.
- FR-002: The system must check slot availability before confirming the booking.
- FR-003: Double-booking the same provider at the same time must be prevented.
- FR-004: A confirmation with appointment ID, provider name, date, and time must be returned on successful booking.

**Acceptance Scenarios:**
1. Given available slots for Dr. Smith on Monday, When a patient books the 10:00 AM slot, Then the appointment is confirmed and the slot is marked as taken.
2. Given the 10:00 AM slot is already booked, When another patient tries to book the same slot, Then a conflict error is returned.
3. Given two patients book the same slot simultaneously, When both requests are processed, Then exactly one succeeds and the other receives a conflict error.

**Success Criteria:**
- SC-001: Booking completes in under 500ms for 99% of requests.
- SC-002: Zero double-bookings under concurrent load of 50 simultaneous requests.

### US-2: Cancel Appointment (Priority: P1)

As a patient, I want to cancel an upcoming appointment so the slot becomes available for others.

**Functional Requirements:**
- FR-005: Patients can cancel appointments at least 24 hours before the scheduled time.
- FR-006: Cancelled appointments must free the slot for rebooking.
- FR-007: Cancellations within 24 hours must be rejected with a policy explanation.

**Acceptance Scenarios:**
1. Given an appointment 3 days from now, When the patient cancels, Then the appointment is cancelled and the slot is reopened.
2. Given an appointment 12 hours from now, When the patient tries to cancel, Then the cancellation is rejected with a 24-hour policy message.

**Success Criteria:**
- SC-003: Cancelled slots become available for rebooking within 5 seconds.

### US-3: View Provider Schedule (Priority: P2)

As a provider, I want to view my upcoming appointments so I can prepare for my day.

**Functional Requirements:**
- FR-008: Providers can view their schedule for a given date range.
- FR-009: The schedule must show patient name, appointment time, and appointment type.
- FR-010: Only the assigned provider can view their own schedule (no cross-provider access).

**Acceptance Scenarios:**
1. Given Dr. Smith has 5 appointments this week, When she views her schedule for this week, Then all 5 appointments are shown with patient names and times.
2. Given Dr. Jones tries to view Dr. Smith's schedule, When the request is made, Then a 403 forbidden error is returned.

**Success Criteria:**
- SC-004: Schedule queries return within 200ms for up to 500 appointments.

=============== FILE: specs/010-appointments/plan.md ===============
# Technical Plan: Appointment Scheduling

## Technical Context

- **Language/Version**: Go 1.22
- **Primary Framework**: Chi router v5
- **Storage**: PostgreSQL 16 with pgx driver
- **Testing**: Go testing package with testify assertions, testcontainers-go for integration tests
- **Target Platform**: Linux/Docker/Kubernetes
- **Authentication**: JWT-based with role claims (patient, provider, admin)

## Project Structure

```
cmd/
  server/main.go              # Application entrypoint
internal/
  models/appointment.go       # Appointment domain model
  models/slot.go               # TimeSlot domain model
  models/provider.go           # Provider domain model
  store/appointment_store.go   # PostgreSQL appointment repository
  store/slot_store.go          # PostgreSQL slot repository
  service/booking_service.go   # Booking business logic with conflict detection
  service/cancel_service.go    # Cancellation business logic with policy check
  service/schedule_service.go  # Provider schedule queries
  handler/booking_handler.go   # HTTP handlers for /appointments
  handler/schedule_handler.go  # HTTP handlers for /providers/:id/schedule
  middleware/auth.go           # JWT authentication and role authorization
  middleware/auth_test.go      # Auth middleware tests
tests/
  features/                    # BDD .feature files (to be generated)
    book_appointment.feature
    cancel_appointment.feature
    view_schedule.feature
  integration/
    booking_test.go
    cancel_test.go
    schedule_test.go
  testutil/
    fixtures.go                # Shared test fixtures and helpers
    db.go                      # Test database setup with testcontainers
go.mod
go.sum
```

## Data Model Summary

- **Appointment**: id (UUID), patientID, providerID, slotID (FK), status (confirmed/cancelled), createdAt, cancelledAt
- **TimeSlot**: id (UUID), providerID, startTime, endTime, isAvailable (boolean with DB-level locking)
- **Provider**: id (UUID), name, specialty, active

## Concurrency Strategy

Slot booking uses PostgreSQL SELECT FOR UPDATE to lock the slot row during the booking transaction, preventing double-booking at the database level.

=============== FILE: .specify/context.json ===============
{
  "tdd_determination": "mandatory",
  "active_feature": "010-appointments"
}
