# Gherkin Feature File Reference

## Transformation Examples

**From spec.md — Acceptance Tests**:

Input (spec.md):
```
### User Story 1 - Login (Priority: P1)
**Acceptance Scenarios**:
1. **Given** a registered user, **When** they enter valid credentials, **Then** they are logged in.
```

Output (.feature file):
```gherkin
@US-001
Feature: Login
  User login functionality

  @TS-001 @FR-001 @P1 @acceptance
  Scenario: Login with valid credentials
    Given a registered user
    When they enter valid credentials
    Then they are logged in
```

**From plan.md — Contract Tests**:
```gherkin
  @TS-010 @FR-005 @P1 @contract
  Scenario: Create user endpoint returns 201
    Given a valid user creation request
    When POST /api/users is called
    Then the response status is 201
    And the response body contains the user ID
```

**From data-model.md — Validation Tests**:
```gherkin
  @TS-020 @FR-008 @P2 @validation
  Scenario: Email must be unique
    Given an existing user with email "test@example.com"
    When a new user is created with the same email
    Then a validation error is returned with message "Email already exists"
```

## Advanced Gherkin Constructs

Use these constructs where appropriate — they improve readability and reduce duplication.

### Background

Use when **3 or more** scenarios in the same Feature share identical Given steps:
```gherkin
Feature: Dashboard
  Background:
    Given a logged in admin user
    And the dashboard is loaded

  Scenario: View metrics
    When they click "Metrics"
    Then the metrics panel is displayed

  Scenario: View users
    When they click "Users"
    Then the user list is displayed
```

### Scenario Outline + Examples

Use when scenarios differ **only by input/output data**:
```gherkin
  @TS-005 @FR-003 @P1 @acceptance
  Scenario Outline: Login with various credential types
    Given a user with <credential_type> credentials
    When they enter "<username>" and "<password>"
    Then the login result is "<result>"

    Examples:
      | credential_type | username | password | result  |
      | valid           | alice    | pass123  | success |
      | invalid         | alice    | wrong    | failure |
      | locked          | bob      | pass123  | locked  |
```

### Rule

Use when scenarios cluster around **distinct business rules** (Gherkin v6+):
```gherkin
Feature: Account Management

  Rule: Users can only delete their own accounts
    @TS-015 @FR-010 @P1 @acceptance
    Scenario: Owner deletes account
      Given a user viewing their own account
      When they click delete
      Then the account is removed

    @TS-016 @FR-010 @P1 @acceptance
    Scenario: Non-owner cannot delete account
      Given a user viewing another user's account
      When they attempt to delete it
      Then access is denied

  Rule: Deleted accounts are recoverable for 30 days
    @TS-017 @FR-011 @P2 @acceptance
    Scenario: Recover recently deleted account
      Given an account deleted 5 days ago
      When recovery is requested
      Then the account is restored
```

## Syntax Validation Rules

After generating each `.feature` file, validate:
- Every `Scenario Outline:` MUST have a corresponding `Examples:` table
- Every `Feature:` MUST have at least one `Scenario:` or `Scenario Outline:`
- Step keywords (`Given`, `When`, `Then`, `And`, `But`) MUST be followed by a space and step text
- Tags MUST be on the line immediately before the element they annotate
- If a syntax error is detected, fix it before proceeding. Report any fixes made.
