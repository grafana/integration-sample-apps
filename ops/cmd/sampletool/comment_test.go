package main

import (
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"
)

func TestScreenshotGroups(t *testing.T) {
	dir := t.TempDir()
	for _, file := range []string{
		"docker/master/docker-mixin/overview.png",
		"docker/master/docker-mixin/containers.png",
		"docker/feat-x/docker-mixin/overview.png",
		"mysql/mysql-overview.png",
		// Left out: not a PNG, a name the comment can't hold, a path of the wrong depth
		"mysql/notes.txt",
		"mysql/bad name.png",
		"mysql/extra/overview.png",
	} {
		path := filepath.Join(dir, file)
		if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(path, nil, 0o644); err != nil {
			t.Fatal(err)
		}
	}

	groups, err := screenshotGroups(dir)
	if err != nil {
		t.Fatal(err)
	}
	want := []screenshotGroup{
		{"docker-mixin@feat-x · docker sample-app", []string{"docker/feat-x/docker-mixin/overview.png"}},
		{"docker-mixin · docker sample-app", []string{"docker/master/docker-mixin/containers.png", "docker/master/docker-mixin/overview.png"}},
		{"mysql sample-app", []string{"mysql/mysql-overview.png"}},
	}
	if !reflect.DeepEqual(groups, want) {
		t.Errorf("screenshotGroups() = %v, want %v", groups, want)
	}
}

func TestScreenshotComment(t *testing.T) {
	run := screenshotRun{number: "8", sha: "0123456789abcdef", url: "https://run", baseURL: "https://raw", time: time.Date(2026, 11, 26, 9, 5, 0, 0, time.UTC)}
	groups := []screenshotGroup{{"mysql sample-app", []string{"mysql/mysql-overview.png"}}}

	if got := screenshotComment(nil, run, ""); got != "" {
		t.Errorf("with no images, got %q, want no comment", got)
	}

	got := screenshotComment(groups, run, "")
	for _, want := range []string{
		commentMarker + "\n",
		"<details open><summary>Run 8 · commit 0123456 · 26 Nov 09:05 UTC</summary>",
		"<details><summary>mysql sample-app · 1 dashboard</summary>",
		"![mysql-overview](https://raw/mysql/mysql-overview.png)",
	} {
		if !strings.Contains(got, want) {
			t.Errorf("comment has no %q:\n%s", want, got)
		}
	}

	noBase := run
	noBase.baseURL = ""
	if got := screenshotComment(groups, noBase, ""); !strings.Contains(got, "could not be stored") || strings.Contains(got, "![") {
		t.Errorf("without a base URL, got %s", got)
	}

	many := []screenshotGroup{{"mysql sample-app", make([]string, commentLimit/50)}}
	if got := screenshotComment(many, run, ""); !strings.Contains(got, "too many screenshots") || len(got) > commentLimit {
		t.Errorf("with too many images, got %d bytes: %.300s", len(got), got)
	}
}

func TestEarlierRuns(t *testing.T) {
	comment := commentMarker + "\n### Dashboard screenshots\n\n" +
		"<details open><summary>Run 3</summary>\nnewest\n</details>\n" +
		"<details><summary>Run 2</summary>\nmiddle\n</details>\n" +
		"<details><summary>Run 1</summary>\noldest\n</details>\n"
	run3 := "<details><summary>Run 3</summary>\nnewest\n</details>\n"
	run2 := "<details><summary>Run 2</summary>\nmiddle\n</details>\n"

	if got, want := earlierRuns(comment, 1000), run3+run2+"<details><summary>Run 1</summary>\noldest\n</details>\n"; got != want {
		t.Errorf("with room for every run, got %q, want %q", got, want)
	}
	if got, want := earlierRuns(comment, len(run3+run2)), run3+run2; got != want {
		t.Errorf("with room for two runs, got %q, want %q", got, want)
	}
	if got := earlierRuns("", 1000); got != "" {
		t.Errorf("with no earlier comment, got %q", got)
	}
}
