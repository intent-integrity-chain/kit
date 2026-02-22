package steps

import (
	"github.com/cucumber/godog"
)

func InitializeScenario(s *godog.ScenarioContext) {
	s.Given(`a registered user`, aRegisteredUser)
	s.When(`the user logs in`, theUserLogsIn)
	s.Then(`the user should see the dashboard`, shouldSeeDashboard)
}

func aRegisteredUser(ctx context.Context) error {
	db.CreateUser("testuser", "secret123")
	return nil
}

func theUserLogsIn(ctx context.Context) error {
	response = app.Login("testuser", "secret123")
	return nil
}

func shouldSeeDashboard(ctx context.Context) error {
	if response.Status != 200 {
		return fmt.Errorf("expected 200, got %d", response.Status)
	}
	return nil
}
