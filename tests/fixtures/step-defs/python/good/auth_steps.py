"""Good step definitions for authentication - all should pass quality checks."""
from pytest_bdd import given, when, then


@given("a registered user")
def given_registered_user(db):
    """Set up a registered user in the test database."""
    db.create_user(username="testuser", password="secret123")


@when("the user logs in with valid credentials")
def when_user_logs_in(browser, db):
    """Simulate login with correct credentials."""
    browser.fill("username", "testuser")
    browser.fill("password", "secret123")
    browser.click("login")


@then("the user should see the dashboard")
def then_see_dashboard(browser):
    """Verify user lands on the dashboard."""
    assert browser.url.endswith("/dashboard")
    assert browser.find_element("welcome-message").is_visible()


@then("the session token should be valid")
def then_valid_session(browser, db):
    """Verify a valid session was created."""
    token = browser.get_cookie("session_token")
    assert token is not None
    assert db.validate_session(token)
