package main

import (
	"context"
	"strings"
	"testing"

	"github.com/alecthomas/kong"
)

func TestParsesCommands(t *testing.T) {
	parser, err := kong.New(&cli{}, options(context.Background())...)
	if err != nil {
		t.Fatal(err)
	}
	for args, want := range map[string]string{
		"dbs down otherdbs":                        "unexpected argument",
		"apps test docker":                         "unexpected argument",
		"ci check docker linux-node":               "unexpected argument",
		"k3s up":                                   "<name>",
		"k3s down --cluster":                       "<name>",
		"ci check":                                 "<name>",
		"apps up":                                  "missing flags: --apps",
		"apps test --apps x --env k":               "--env must be one of",
		"dbs up --env local":                       "unknown flag --env",
		"frobnicate":                               "unexpected argument",
		"apps down --apps no-such":                 `no sample-app named "no-such"`,
		"apps down --apps mysql,docker":            "",
		"k3s down demo --cluster":                  "",
		"k3s up --cluster demo":                    "",
		"dbs up --dbs mine --grafana":              "",
		"apps screenshot --apps docker --dbs mine": "",
	} {
		_, err := parser.Parse(strings.Fields(args))
		if want == "" && err != nil || want != "" && (err == nil || !strings.Contains(err.Error(), want)) {
			t.Errorf("Parse(%q) = %v, want %q", args, err, want)
		}
	}
}
