Feature: Validation Tests

  @TS-006 @validation @P2 @FR-001
  Scenario: Parser extracts IDs correctly
    Given well-formed markdown content
    When parser runs
    Then all IDs are extracted

  @TS-007 @validation @P2 @FR-002 @FR-005
  Scenario: Edge derivation handles orphans
    Given references to non-existent entities
    When edges are derived
    Then orphaned references are ignored

  @TS-008 @validation @P2 @FR-004 @SC-003
  Scenario: Gap computation is correct
    Given a set of nodes and edges
    When gaps are computed
    Then untested requirements and unimplemented tests are identified
