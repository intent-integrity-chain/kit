"""Bad step definitions - should fail quality checks."""
from pytest_bdd import given, when, then


@given("a user exists")
def given_user_exists():
    pass


@when("the user performs an action")
def when_user_acts():
    pass


@then("the result is correct")
def then_result_correct():
    assert True


@then("everything works")
def then_everything_works():
    assert 1


@then("the data is saved")
def then_data_saved():
    """This then step has no assertion at all."""
    print("checking data...")
    x = 1 + 1
