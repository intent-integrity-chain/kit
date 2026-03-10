# Acceptance Test Suite for a User Notifications Feature

## Problem/Feature Description

A fintech startup is building a user notifications service that will alert customers about account events (new transactions, low balance, login from new device). The backend team has finished writing up the requirements in their specification format and now needs executable test scenarios before any implementation begins. They follow a test-first approach and need proper BDD-style test files that can be wired up to their testing framework.

The product owner has provided a completed specification file (see below) and wants the QA engineer to translate it into Gherkin `.feature` files that the dev team can use as their implementation contract. The files must be organized sensibly and follow the project's tagging conventions so they can be traced back to individual requirements.

## Output Specification

Produce one or more `.feature` files in a `tests/features/` directory. Each file should contain Gherkin scenarios derived from the acceptance criteria in the spec. Output a brief `generation-report.md` summarizing how many scenarios were generated, how they are organized, and any traceability notes.

## Input Files

The following files are provided as inputs. Extract them before beginning.

=============== FILE: specs/001-notifications/spec.md ===============
# Feature Specification: User Notifications

## Overview

Allow users to receive real-time and email notifications for important account events.

## User Stories

### US-1: Transaction Alerts (Priority: P1)

As a bank customer, I want to receive a notification when a transaction occurs on my account so I can monitor my finances in real time.

**Acceptance Scenarios:**

1. **Given** a user with notifications enabled, **When** a debit transaction over $10 occurs, **Then** the user receives an in-app notification within 5 seconds.
2. **Given** a user with email alerts enabled, **When** any transaction occurs, **Then** the user receives an email notification within 2 minutes.
3. **Given** a user with notifications disabled, **When** a transaction occurs, **Then** no notification is sent.

**Functional Requirements:**
- FR-001: The system must detect transactions and trigger notification dispatch within 5 seconds.
- FR-002: The system must support both in-app and email notification channels.
- FR-003: Users must be able to disable notifications globally.

**Success Criteria:**
- SC-001: 99% of triggered in-app notifications are delivered within 5 seconds under normal load.
- SC-002: Email notifications are delivered within 2 minutes in 95% of cases.

### US-2: Low Balance Alert (Priority: P2)

As a bank customer, I want to be alerted when my account balance falls below a threshold I configure so I can avoid overdrafts.

**Acceptance Scenarios:**

1. **Given** a user who has set a low-balance threshold of $100, **When** a transaction causes the balance to drop to $80, **Then** a low-balance alert is sent immediately.
2. **Given** a user who has not set a threshold, **When** the balance drops below $50 (system default), **Then** a low-balance alert is sent.
3. **Given** a user who already received a low-balance alert today, **When** another transaction drops the balance further, **Then** no duplicate alert is sent.

**Functional Requirements:**
- FR-004: Users must be able to configure a custom low-balance threshold.
- FR-005: A default threshold of $50 applies when none is configured.
- FR-006: Low-balance alerts must not be sent more than once per 24-hour period.

**Success Criteria:**
- SC-003: Low-balance alerts are sent within 10 seconds of the triggering transaction.
- SC-004: Zero duplicate low-balance alerts sent within a 24-hour window.

### US-3: Security Alerts (Priority: P1)

As a bank customer, I want to be notified immediately when a login occurs from an unrecognized device so I can take action if my account is compromised.

**Acceptance Scenarios:**

1. **Given** a user logging in from a new device, **When** the login is successful, **Then** a security alert is sent to the user's registered email and phone number.
2. **Given** a user who dismisses a security alert, **When** the same device logs in again within 7 days, **Then** no security alert is sent.

**Functional Requirements:**
- FR-007: New device detection must compare against the user's registered devices list.
- FR-008: Security alerts must be sent via both email and SMS simultaneously.
- FR-009: Users can whitelist devices to suppress future alerts.

**Success Criteria:**
- SC-005: Security alerts are delivered within 30 seconds of a new-device login event.
