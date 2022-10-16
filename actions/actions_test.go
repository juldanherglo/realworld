package actions

import (
	"embed"
	"testing"

	"github.com/gobuffalo/buffalo"
	"github.com/gobuffalo/suite/v4"
)

type ActionSuite struct {
	*suite.Action
}

//go:embed basics.toml
var files embed.FS

func Test_ActionSuite(t *testing.T) {
	action, err := suite.NewActionWithFixtures(App(), buffalo.NewFS(files, "Test_ActionSuite"))
	if err != nil {
		t.Fatal(err)
	}

	as := &ActionSuite{
		Action: action,
	}
	suite.Run(t, as)
}
