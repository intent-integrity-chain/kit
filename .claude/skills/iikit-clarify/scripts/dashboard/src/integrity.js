'use strict';

const crypto = require('crypto');

/**
 * Extract Gherkin step lines (Given/When/Then/And/But) from .feature content,
 * normalize whitespace, and compute SHA256 hash.
 *
 * Order is preserved (deterministic ordering comes from sorted filenames — caller
 * concatenates all .feature file contents sorted by filename before calling).
 *
 * @param {string} content - Concatenated content of .feature files
 * @returns {string|null} SHA256 hex hash, or null if no assertions found
 */
function computeAssertionHash(content) {
  if (!content || typeof content !== 'string') return null;

  const lines = content.split('\n');
  const assertionLines = [];

  for (const line of lines) {
    if (/^\s*(Given|When|Then|And|But) /.test(line)) {
      // Normalize whitespace: collapse multiple spaces to single space
      const normalized = line.replace(/\s+/g, ' ').trim();
      assertionLines.push(normalized);
    }
  }

  if (assertionLines.length === 0) return null;

  const joined = assertionLines.join('\n');
  return crypto.createHash('sha256').update(joined, 'utf8').digest('hex');
}

/**
 * Compare current assertion hash against stored hash.
 *
 * @param {string|null} currentHash - Hash computed from current .feature files
 * @param {string|null} storedHash - Hash from context.json
 * @returns {{status: string, currentHash: string|null, storedHash: string|null}}
 */
function checkIntegrity(currentHash, storedHash) {
  if (!currentHash || !storedHash) {
    return {
      status: 'missing',
      currentHash: currentHash || null,
      storedHash: storedHash || null
    };
  }

  return {
    status: currentHash === storedHash ? 'valid' : 'tampered',
    currentHash,
    storedHash
  };
}

module.exports = { computeAssertionHash, checkIntegrity };
