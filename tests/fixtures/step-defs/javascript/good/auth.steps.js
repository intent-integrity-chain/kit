const { Given, When, Then } = require('@cucumber/cucumber');
const { expect } = require('chai');

Given('a registered user', function () {
    this.user = { username: 'testuser', password: 'secret123' };
    this.db.createUser(this.user);
});

When('the user logs in with valid credentials', function () {
    this.response = this.app.login(this.user.username, this.user.password);
});

Then('the user should see the dashboard', function () {
    expect(this.response.status).to.equal(200);
    expect(this.response.body).to.include('dashboard');
});

Then('the session token should be valid', function () {
    const token = this.response.headers['set-cookie'];
    expect(token).to.not.be.undefined;
    expect(this.db.validateSession(token)).to.be.true;
});
