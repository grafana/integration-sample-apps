package main

import (
	"context"
	"strings"
	"testing"
)

func TestRejectsWrongArguments(t *testing.T) {
	for args, want := range map[string]string{
		"dbs down otherdbs":          "unexpected argument",
		"apps test docker":           "unexpected argument",
		"k3s down demo --cluster":    "unexpected argument",
		"ci check docker linux-node": "unexpected argument",
		"k3s up":                     "needs a name",
		"k3s down --cluster":         "needs a name",
		"ci check":                   "needs a name",
	} {
		err := run(context.Background(), strings.Fields(args))
		if err == nil || !strings.Contains(err.Error(), want) {
			t.Errorf("run(%q) = %v, want an error mentioning %q", args, err, want)
		}
	}
}
