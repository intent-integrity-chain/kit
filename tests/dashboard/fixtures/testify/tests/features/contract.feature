Feature: Contract Tests

  @TS-004 @contract @P1 @FR-001 @FR-003
  Scenario: API returns correct response
    Given a valid feature
    When GET /api/data is called
    Then response contains expected shape

  @TS-005 @contract @P1 @FR-003 @SC-002
  Scenario: WebSocket pushes updates
    Given a connected client
    When data changes on disk
    Then update message is sent
