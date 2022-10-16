package models

import (
	"embed"
	"testing"

	"github.com/gobuffalo/buffalo"
	"github.com/gobuffalo/suite/v4"
)

type ModelSuite struct {
	*suite.Model
}

//go:embed basics.toml
var files embed.FS

func Test_ModelSuite(t *testing.T) {
	model, err := suite.NewModelWithFixtures(buffalo.NewFS(files, "fixtures"))
	if err != nil {
		t.Fatal(err)
	}

	as := &ModelSuite{
		Model: model,
	}
	suite.Run(t, as)
}
