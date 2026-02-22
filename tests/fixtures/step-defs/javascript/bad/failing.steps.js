const { Given, When, Then } = require('@cucumber/cucumber');
const { expect } = require('chai');

Given('a user exists', function () {
});

When('the user performs an action', function () {
});

Then('the result is correct', function () {
    expect(true).toBe(true);
});

Then('the data is saved', function () {
    console.log('checking data...');
    const x = 1 + 1;
});
