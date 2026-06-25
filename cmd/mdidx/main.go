package main

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"strings"
)

const usage = "Usage: mdidx [file] [--pretty] [--help]\n"

func readInput(filePath string) (string, error) {
	if filePath != "" {
		b, err := os.ReadFile(filePath)
		return string(b), err
	}
	b, err := io.ReadAll(os.Stdin)
	return string(b), err
}

func parseCliArgs(args []string) (flags, positionals []string) {
	flags = []string{}
	positionals = []string{}

	sep := -1
	for i, a := range args {
		if a == "--" {
			sep = i
			break
		}
	}

	classify := func(part []string) {
		for _, a := range part {
			if strings.HasPrefix(a, "-") {
				flags = append(flags, a)
			} else {
				positionals = append(positionals, a)
			}
		}
	}

	if sep != -1 {
		classify(args[:sep])
		positionals = append(positionals, args[sep+1:]...)
		return
	}
	classify(args)
	return
}

func main() {
	flags, positionals := parseCliArgs(os.Args[1:])

	known := map[string]bool{"--pretty": true, "--help": true, "-h": true}
	hasHelp := false
	unknown := ""
	for _, f := range flags {
		if f == "--help" || f == "-h" {
			hasHelp = true
		}
		if !known[f] && unknown == "" {
			unknown = f
		}
	}
	hasError := unknown != "" || len(positionals) > 1

	if hasHelp || hasError {
		fmt.Fprint(os.Stderr, usage)
		if hasError {
			os.Exit(1)
		}
		os.Exit(0)
	}

	pretty := false
	for _, f := range flags {
		if f == "--pretty" {
			pretty = true
		}
	}
	filePath := ""
	if len(positionals) > 0 {
		filePath = positionals[0]
	}

	input, err := readInput(filePath)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}

	enc := json.NewEncoder(os.Stdout)
	enc.SetEscapeHTML(false) // match JSON.stringify: do not escape < > &
	if pretty {
		enc.SetIndent("", "  ")
	}
	if err := enc.Encode(convert(input)); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
