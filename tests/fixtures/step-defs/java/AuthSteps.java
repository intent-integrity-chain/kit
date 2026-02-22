package com.example.steps;

import io.cucumber.java.en.Given;
import io.cucumber.java.en.When;
import io.cucumber.java.en.Then;
import static org.junit.Assert.*;

public class AuthSteps {

    @Given("a registered user")
    public void aRegisteredUser() {
        User user = new User("testuser", "secret123");
        db.save(user);
    }

    @When("the user logs in with valid credentials")
    public void theUserLogsIn() {
        response = app.login("testuser", "secret123");
    }

    @Then("the user should see the dashboard")
    public void shouldSeeDashboard() {
        assertEquals(200, response.getStatus());
        assertTrue(response.getBody().contains("dashboard"));
    }
}
