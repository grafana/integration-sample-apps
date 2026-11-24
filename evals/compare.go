package main

import (
	"bufio"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"text/tabwriter"
)

// resultSet is the records of one variant or results file.
type resultSet struct {
	label   string
	files   []string
	records []record
}

// compareCmd prints the pass rate per task and overall, with cost, turns and
// permission denials, for one or two result sets.
func compareCmd(args []string, w io.Writer) error {
	flags := flag.NewFlagSet("compare", flag.ContinueOnError)
	all := flags.Bool("all", false, "merge every dated results file of a named variant")
	run := flags.String("run", "", "only records from this run")
	// Accept flags after the result sets too.
	var specs []string
	for len(args) > 0 {
		if err := flags.Parse(args); err != nil {
			return err
		}
		if flags.NArg() == 0 {
			break
		}
		specs = append(specs, flags.Arg(0))
		args = flags.Args()[1:]
	}
	if len(specs) == 0 || len(specs) > 2 {
		return errors.New("compare takes one or two variant names or .jsonl files")
	}
	var sets []resultSet
	for _, spec := range specs {
		s, err := loadResults(spec, *all, *run)
		if err != nil {
			return err
		}
		sets = append(sets, s)
	}

	var tasks []string
	for _, s := range sets {
		for _, r := range s.records {
			tasks = append(tasks, r.Task)
		}
	}
	slices.Sort(tasks)
	tasks = slices.Compact(tasks)

	for _, s := range sets {
		models, hashes := map[string]bool{}, map[string]bool{}
		for _, r := range s.records {
			models[r.Model], hashes[r.VariantHash] = true, true
		}
		var base []string
		for _, f := range s.files {
			base = append(base, filepath.Base(f))
		}
		fmt.Fprintf(w, "%s: %d trials from %s; model %s; harness %s; total cost $%.2f\n", s.label, len(s.records),
			strings.Join(base, ", "), strings.Join(sortedKeys(models), ", "), strings.Join(sortedKeys(hashes), ", "),
			statsOf(s.records).costTotal)
	}
	fmt.Fprintln(w)

	tw := tabwriter.NewWriter(w, 0, 0, 2, ' ', 0)
	header := "task"
	for _, s := range sets {
		header += "\t" + s.label + " pass\tcost\tturns\tdenied\tfailed graders"
	}
	fmt.Fprintln(tw, header)
	for _, t := range append(tasks, "overall") {
		row := t
		for _, s := range sets {
			recs := s.records
			if t != "overall" {
				recs = slices.DeleteFunc(slices.Clone(recs), func(r record) bool { return r.Task != t })
			}
			st := statsOf(recs)
			row += "\t" + st.pass() + "\t" + money(st.cost) + "\t" + num(st.turns) + "\t" + num(st.denied) + "\t" + st.topFails()
		}
		fmt.Fprintln(tw, row)
	}
	if err := tw.Flush(); err != nil {
		return err
	}
	fmt.Fprintln(w, "\ncost and turns are means per trial; denied is permission denials per trial.")
	for _, t := range tasks {
		for _, s := range sets {
			if n := countTask(s.records, t); n > 0 && n < 3 {
				fmt.Fprintf(w, "Fewer than 3 trials of %s in %s: single runs are noisy, don't read much into them.\n", t, s.label)
			}
		}
	}
	if len(sets) == 2 {
		a, b := statsOf(sets[0].records), statsOf(sets[1].records)
		if a.n > 0 && b.n > 0 {
			fmt.Fprintf(w, "Overall pass rate: %s %.0f%% vs %s %.0f%% (%+.0f points).\n",
				sets[0].label, a.rate()*100, sets[1].label, b.rate()*100, (b.rate()-a.rate())*100)
		}
	}
	return nil
}

// loadResults reads a .jsonl file, or a variant's latest dated results file
// in results/ (every one with all).
func loadResults(spec string, all bool, run string) (resultSet, error) {
	s := resultSet{label: spec, files: []string{spec}}
	if strings.HasSuffix(spec, ".jsonl") || strings.ContainsRune(spec, os.PathSeparator) {
		s.label = strings.TrimSuffix(filepath.Base(spec), ".jsonl")
	} else {
		files, _ := filepath.Glob(filepath.Join("results", "????-??-??-"+spec+".jsonl"))
		if len(files) == 0 {
			return s, fmt.Errorf("no results for variant %s in evals/results/", spec)
		}
		if !all {
			files = files[len(files)-1:]
		}
		s.files = files
	}
	for _, path := range s.files {
		f, err := os.Open(path)
		if err != nil {
			return s, err
		}
		sc := bufio.NewScanner(f)
		sc.Buffer(nil, 16<<20)
		for sc.Scan() {
			var r record
			if len(strings.TrimSpace(sc.Text())) == 0 {
				continue
			}
			if err := json.Unmarshal(sc.Bytes(), &r); err != nil {
				f.Close()
				return s, fmt.Errorf("%s: %w", path, err)
			}
			if run == "" || r.Run == run {
				s.records = append(s.records, r)
			}
		}
		f.Close()
		if err := sc.Err(); err != nil {
			return s, err
		}
	}
	return s, nil
}

type stats struct {
	n, passed           int
	cost, turns, denied *float64
	costTotal           float64
	fails               map[string]int
}

func statsOf(records []record) stats {
	s := stats{n: len(records), fails: map[string]int{}}
	var costs, turns []float64
	denied := 0
	for _, r := range records {
		if r.Pass {
			s.passed++
		}
		if r.CostUSD > 0 {
			costs = append(costs, r.CostUSD)
			s.costTotal += r.CostUSD
		}
		if r.Turns > 0 {
			turns = append(turns, float64(r.Turns))
		}
		denied += r.DeniedCount
		for name, g := range r.Graders {
			if !g.Pass {
				s.fails[name]++
			}
		}
		if r.Error != "" || r.IsError {
			s.fails["error"]++
		}
	}
	s.cost, s.turns = mean(costs), mean(turns)
	if s.n > 0 {
		d := float64(denied) / float64(s.n)
		s.denied = &d
	}
	return s
}

func mean(xs []float64) *float64 {
	if len(xs) == 0 {
		return nil
	}
	sum := 0.0
	for _, x := range xs {
		sum += x
	}
	m := sum / float64(len(xs))
	return &m
}

func (s stats) rate() float64 {
	if s.n == 0 {
		return 0
	}
	return float64(s.passed) / float64(s.n)
}

func (s stats) pass() string {
	if s.n == 0 {
		return "-"
	}
	return fmt.Sprintf("%d/%d %3.0f%%", s.passed, s.n, s.rate()*100)
}

// topFails names the three graders that failed most often.
func (s stats) topFails() string {
	names := sortedKeys(s.fails)
	slices.SortStableFunc(names, func(a, b string) int { return s.fails[b] - s.fails[a] })
	var out []string
	for _, n := range names[:min(3, len(names))] {
		out = append(out, fmt.Sprintf("%s×%d", n, s.fails[n]))
	}
	if len(out) == 0 {
		return "-"
	}
	return strings.Join(out, ", ")
}

func money(v *float64) string {
	if v == nil {
		return "-"
	}
	return fmt.Sprintf("$%.2f", *v)
}

func num(v *float64) string {
	if v == nil {
		return "-"
	}
	return fmt.Sprintf("%.1f", *v)
}

func countTask(records []record, t string) int {
	n := 0
	for _, r := range records {
		if r.Task == t {
			n++
		}
	}
	return n
}
