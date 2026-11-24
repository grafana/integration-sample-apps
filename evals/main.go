// Command evals runs agent eval tasks against harness variants and compares
// their results. See README.md.
//
//	go -C evals run . [--variant NAME]... [--tasks a,b] [--trials N] [--jobs N] [--vm]
//	                  [--model ID] [--max-turns N] [--agent reference|noop]
//	                  [--source DIR] [--ref REF] [--keep]
//	go -C evals run . compare <a> [<b>] [--all] [--run RUN_ID]
package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"os"
	"os/signal"
	"syscall"
)

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	var err error
	if len(os.Args) > 1 && os.Args[1] == "compare" {
		err = compareCmd(os.Args[2:], os.Stdout)
	} else {
		err = runCmd(ctx, os.Args[1:])
	}
	if errors.Is(err, flag.ErrHelp) {
		return
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, "evals:", err)
		os.Exit(1)
	}
}
