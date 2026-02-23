module.exports = {
  testMatch: ['<rootDir>/*.test.js'],
  testPathIgnorePatterns: ['/visual/', '/node_modules/'],
  testTimeout: 30000,
  // template-loading.test.js renames source files temporarily — must not
  // conflict with other tests using the same generator files
  maxWorkers: 1,
};
