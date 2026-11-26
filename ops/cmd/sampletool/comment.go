package main

import (
	"fmt"
	"io"
	"io/fs"
	"maps"
	"os"
	"path"
	"path/filepath"
	"regexp"
	"slices"
	"strings"
	"time"
)

// commentMarker starts the screenshot comment, which is how CI finds it among
// other comments by github-actions[bot].
const commentMarker = "<!-- sample-app-screenshots -->"

// commentLimit keeps the comment under GitHub's 65536-character limit.
const commentLimit = 65000

// The images are <app>/<dashboard>.png, or <app>/<ref>/<mixin>/<dashboard>.png
// for one listed from a mixin. The names come from the pull request, so others
// are left out of the comment.
var (
	urlImage   = regexp.MustCompile(`^([A-Za-z0-9][A-Za-z0-9_.-]*)/([A-Za-z0-9_-]+)\.png$`)
	mixinImage = regexp.MustCompile(`^([A-Za-z0-9][A-Za-z0-9_.-]*)/([A-Za-z0-9][A-Za-z0-9_.-]*)/([A-Za-z0-9][A-Za-z0-9_.-]*)/([A-Za-z0-9_-]+)\.png$`)
)

// screenshotGroup is a section of the comment: the dashboards of one mixin at
// one ref for an app, or the dashboards an app lists by URL.
type screenshotGroup struct {
	label  string
	images []string
}

// screenshotGroups returns the comment's sections for the images under dir:
// mixin dashboards by mixin, ref and app, then the ones listed by URL by app.
func screenshotGroups(dir string) ([]screenshotGroup, error) {
	mixins := map[[3]string][]string{}
	urls := map[string][]string{}
	err := filepath.WalkDir(dir, func(file string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return err
		}
		rel, err := filepath.Rel(dir, file)
		if err != nil {
			return err
		}
		image := filepath.ToSlash(rel)
		if m := mixinImage.FindStringSubmatch(image); m != nil {
			key := [3]string{m[3], m[2], m[1]} // mixin, ref, app
			mixins[key] = append(mixins[key], image)
		} else if m := urlImage.FindStringSubmatch(image); m != nil {
			urls[m[1]] = append(urls[m[1]], image)
		}
		return nil
	})
	if err != nil {
		return nil, err
	}

	var groups []screenshotGroup
	byName := func(a, b [3]string) int { return slices.Compare(a[:], b[:]) }
	for _, key := range slices.SortedFunc(maps.Keys(mixins), byName) {
		mixin, ref, app := key[0], key[1], key[2]
		if ref != "master" {
			mixin += "@" + ref
		}
		groups = append(groups, screenshotGroup{mixin + " · " + app + " sample-app", mixins[key]})
	}
	for _, app := range slices.Sorted(maps.Keys(urls)) {
		groups = append(groups, screenshotGroup{app + " sample-app", urls[app]})
	}
	return groups, nil
}

// screenshotRun is the run a comment is written for.
type screenshotRun struct {
	number, sha, url string
	// baseURL serves the images. Without it, the comment points to the run's artifacts.
	baseURL string
	time    time.Time
}

// screenshotComment returns the comment for a run's screenshots: the run's
// images, then the runs of the earlier comment, collapsed and newest first,
// while they fit. It returns "" when there are no images.
func screenshotComment(groups []screenshotGroup, run screenshotRun, earlier string) string {
	if len(groups) == 0 {
		return ""
	}
	current := run.section(run.images(groups))
	if len(current) > commentLimit {
		current = run.section(fmt.Sprintf("\nThis run captured too many screenshots to show here. They are in the artifacts of [this run](%s).\n", run.url))
	}
	return current + earlierRuns(earlier, commentLimit-len(current))
}

// section wraps the body of a run in the comment's heading and the run's summary.
func (r screenshotRun) section(body string) string {
	var b strings.Builder
	fmt.Fprintf(&b, "%s\n### Dashboard screenshots\n\n", commentMarker)
	fmt.Fprintf(&b, "<details open><summary>Run %s · commit %.7s · %s</summary>\n\n<blockquote>\n\n", r.number, r.sha, r.time.UTC().Format("02 Jan 15:04 UTC"))
	fmt.Fprintf(&b, "Rendered from the data each sample-app produced in [this run](%s), covering its last 5 minutes.\n", r.url)
	b.WriteString(body)
	closeDetails(&b)
	b.WriteString("\n")
	return b.String()
}

// images lists each group's images, collapsed under the group.
func (r screenshotRun) images(groups []screenshotGroup) string {
	if r.baseURL == "" {
		return fmt.Sprintf("\nThe images could not be stored for display here. They are in the artifacts of [this run](%s).\n", r.url)
	}
	var b strings.Builder
	for _, g := range groups {
		plural := "s"
		if len(g.images) == 1 {
			plural = ""
		}
		openDetails(&b, fmt.Sprintf("%s · %d dashboard%s", g.label, len(g.images), plural), false)
		for _, image := range g.images {
			name := strings.TrimSuffix(path.Base(image), ".png")
			openDetails(&b, name, true)
			fmt.Fprintf(&b, "![%s](%s/%s)\n", name, r.baseURL, image)
			closeDetails(&b)
		}
		closeDetails(&b)
	}
	return b.String()
}

func openDetails(b *strings.Builder, summary string, open bool) {
	attr := ""
	if open {
		attr = " open"
	}
	fmt.Fprintf(b, "\n<details%s><summary>%s</summary>\n\n<blockquote>\n\n", attr, summary)
}

func closeDetails(b *strings.Builder) { b.WriteString("\n</blockquote>\n</details>\n") }

// runSummary starts a run in the comment. Dashboard names have no spaces, so
// it can't match one of theirs.
var runSummary = regexp.MustCompile(`(?m)^<details(?: open)?><summary>Run `)

// earlierRuns returns the runs in an earlier comment, collapsed, newest first
// and dropping the oldest to stay within budget bytes.
func earlierRuns(comment string, budget int) string {
	starts := runSummary.FindAllStringIndex(comment, -1)
	var b strings.Builder
	for i, start := range starts {
		end := len(comment)
		if i+1 < len(starts) {
			end = starts[i+1][0]
		}
		run := strings.Replace(comment[start[0]:end], "<details open>", "<details>", 1)
		if b.Len()+len(run) > budget {
			break
		}
		b.WriteString(run)
	}
	return b.String()
}

type ciScreenshotCommentCmd struct {
	Dir       string `arg:"" type:"existingdir" help:"Directory of the downloaded screenshots-<app> artifacts."`
	RunNumber string `required:"" help:"Number of the workflow run."`
	SHA       string `required:"" help:"Commit the run tested."`
	RunURL    string `required:"" help:"Link to the run, whose artifacts hold the images."`
	BaseURL   string `help:"URL the images are served under. Without it, the comment points to the run's artifacts."`
	Earlier   string `type:"existingfile" help:"File holding the current comment, whose runs are carried over."`
}

func (c *ciScreenshotCommentCmd) Run() error {
	return c.write(os.Stdout, time.Now())
}

func (c *ciScreenshotCommentCmd) write(w io.Writer, now time.Time) error {
	groups, err := screenshotGroups(c.Dir)
	if err != nil {
		return err
	}
	var earlier []byte
	if c.Earlier != "" {
		if earlier, err = os.ReadFile(c.Earlier); err != nil {
			return err
		}
	}
	run := screenshotRun{number: c.RunNumber, sha: c.SHA, url: c.RunURL, baseURL: c.BaseURL, time: now}
	_, err = io.WriteString(w, screenshotComment(groups, run, string(earlier)))
	return err
}
