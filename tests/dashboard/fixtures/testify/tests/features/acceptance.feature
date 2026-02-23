Feature: Acceptance Tests

  @TS-001 @acceptance @P1 @FR-001 @SC-001
  Scenario: Dashboard displays on load
    Given a project with valid data
    When the dashboard loads
    Then all components render correctly

  @TS-002 @acceptance @P2 @FR-002 @SC-002
  Scenario: Filtering works correctly
    Given a dashboard with items
    When a filter is applied
    Then only matching items are shown

  @TS-003 @acceptance @P1 @FR-001 @FR-002 @SC-001
  Scenario: Multi-requirement coverage
    Given a feature with multiple requirements
    When the dashboard loads
    Then all requirements are represented
