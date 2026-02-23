const { computeAssertionHash, checkIntegrity } = require('../../.claude/skills/iikit-core/scripts/dashboard/src/integrity');

// TS-017: Integrity check detects hash mismatch (Gherkin format)
describe('computeAssertionHash', () => {
  test('computes SHA256 hash from Gherkin step lines', () => {
    const content = `Feature: Dashboard
  Scenario: Live task checkbox update
    Given a feature with tasks.md containing 10 unchecked tasks
    When an agent checks off a task
    Then the checkbox updates within 5 seconds
`;
    const hash = computeAssertionHash(content);
    expect(hash).toBeDefined();
    expect(typeof hash).toBe('string');
    expect(hash).toHaveLength(64); // SHA256 hex length
  });

  test('same content produces same hash', () => {
    const content = `    Given input A
    When action B
    Then result C
`;
    const hash1 = computeAssertionHash(content);
    const hash2 = computeAssertionHash(content);
    expect(hash1).toBe(hash2);
  });

  test('different content produces different hash', () => {
    const content1 = `    Given input A
    When action B
    Then result C
`;
    const content2 = `    Given input A
    When action B
    Then result D
`;
    const hash1 = computeAssertionHash(content1);
    const hash2 = computeAssertionHash(content2);
    expect(hash1).not.toBe(hash2);
  });

  test('whitespace normalization produces consistent hashes', () => {
    const content1 = `    Given  input   A
    When  action  B
    Then  result  C
`;
    const content2 = `    Given input A
    When action B
    Then result C
`;
    const hash1 = computeAssertionHash(content1);
    const hash2 = computeAssertionHash(content2);
    expect(hash1).toBe(hash2);
  });

  test('extracts And and But step keywords', () => {
    const content = `    Given input A
    And input B
    When action C
    But not action D
    Then result E
`;
    const hash = computeAssertionHash(content);
    expect(hash).toBeDefined();
    expect(hash).toHaveLength(64);
  });

  test('returns null for content with no assertions', () => {
    const hash = computeAssertionHash('Just some text with no assertions.');
    expect(hash).toBeNull();
  });

  test('returns null for null/empty input', () => {
    expect(computeAssertionHash(null)).toBeNull();
    expect(computeAssertionHash('')).toBeNull();
  });
});

describe('checkIntegrity', () => {
  test('returns valid when hashes match', () => {
    const result = checkIntegrity('abc123', 'abc123');
    expect(result).toEqual({
      status: 'valid',
      currentHash: 'abc123',
      storedHash: 'abc123'
    });
  });

  test('returns tampered when hashes differ', () => {
    const result = checkIntegrity('abc123', 'def456');
    expect(result).toEqual({
      status: 'tampered',
      currentHash: 'abc123',
      storedHash: 'def456'
    });
  });

  test('returns missing when stored hash is null', () => {
    const result = checkIntegrity('abc123', null);
    expect(result).toEqual({
      status: 'missing',
      currentHash: 'abc123',
      storedHash: null
    });
  });

  test('returns missing when current hash is null', () => {
    const result = checkIntegrity(null, 'abc123');
    expect(result).toEqual({
      status: 'missing',
      currentHash: null,
      storedHash: 'abc123'
    });
  });

  test('returns missing when both are null', () => {
    const result = checkIntegrity(null, null);
    expect(result).toEqual({
      status: 'missing',
      currentHash: null,
      storedHash: null
    });
  });
});
