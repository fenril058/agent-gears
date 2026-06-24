// Package main implements mdidx, a faithful Go reimplementation of
// oubakiou/md2idx (MIT). It converts Markdown into {index, sections} JSON:
// `index` is a numbered table of contents, `sections` is the raw Markdown for
// each heading (sections[0] is any preamble before the first heading).
//
// This file is a line-for-line port of upstream src/md2idx.ts. Behaviour and
// output are kept byte-compatible; see mdidx_test.go for the ported test suite.
package main

import (
	"fmt"
	"regexp"
	"strings"
	"unicode"
)

type heading struct {
	depth  int
	text   string
	offset int
}

// result is the JSON output. Field order (index then sections) and the absence
// of HTML escaping (see main.go) match md2idx's JSON.stringify output.
type result struct {
	Index    string   `json:"index"`
	Sections []string `json:"sections"`
}

type fenceState struct {
	active bool
	char   byte
	length int
}

type scanState struct {
	fence                fenceState
	offset               int
	prevWasFenceBoundary bool
	paragraphStartOffset int
}

const noParagraph = -1

var inactiveFence = fenceState{}

var (
	fenceRe       = regexp.MustCompile("^ {0,3}(`{3,}|~{3,})")
	fenceCloseRe  = regexp.MustCompile("^ {0,3}(`{3,}|~{3,})\\s*$")
	atxRe         = regexp.MustCompile(`^ {0,3}(#{1,6})\s`)
	setextH1Re    = regexp.MustCompile(`^ {0,3}={1,}\s*$`)
	setextH2Re    = regexp.MustCompile(`^ {0,3}-{2,}\s*$`)
	indentCodeRe  = regexp.MustCompile(`^ {4,}\S`)
	blockStartRe  = regexp.MustCompile(`^ {0,3}(?:[-*+]|\d{1,9}[.)]) `)
	atxTrailingRe = regexp.MustCompile(`\s+#+\s*$`)
)

// inlineReplacers strips inline markup from heading text for the index.
// Order matters and mirrors stripInlineMarkup in md2idx.ts exactly.
var inlineReplacers = []struct {
	re   *regexp.Regexp
	repl string
}{
	{regexp.MustCompile(`!\[([^\]]*)\]\([^)]*\)`), "${1}"},
	{regexp.MustCompile(`\[([^\]]*)\]\([^)]*\)`), "${1}"},
	{regexp.MustCompile(`\[([^\]]*)\]\[[^\]]*\]`), "${1}"},
	{regexp.MustCompile("``([^`]*)``"), "${1}"},
	{regexp.MustCompile("`([^`]*)`"), "${1}"},
	{regexp.MustCompile(`\*{1,3}([^*]+)\*{1,3}`), "${1}"},
	{regexp.MustCompile(`_{1,3}([^_]+)_{1,3}`), "${1}"},
	{regexp.MustCompile(`~~([^~]+)~~`), "${1}"},
}

func stripInlineMarkup(s string) string {
	for _, r := range inlineReplacers {
		s = r.re.ReplaceAllString(s, r.repl)
	}
	return s
}

func stripAtxTrailing(line string) string {
	return atxTrailingRe.ReplaceAllString(line, "")
}

// trim helpers match JavaScript String.prototype.trim/trimStart/trimEnd, which
// strip Unicode whitespace.
func trimEnd(s string) string   { return strings.TrimRightFunc(s, unicode.IsSpace) }
func trimStart(s string) string { return strings.TrimLeftFunc(s, unicode.IsSpace) }
func trimBoth(s string) string  { return strings.TrimFunc(s, unicode.IsSpace) }

// updateFenceState returns the next fence state and whether it changed. In
// md2idx.ts the change is detected via reference inequality; we surface it as a
// boolean. A fence boundary line (an opening line, or a valid closing line)
// reports changed = true.
func updateFenceState(line string, f fenceState) (fenceState, bool) {
	open := fenceRe.FindStringSubmatch(line)
	if open == nil {
		return f, false
	}
	if !f.active {
		return fenceState{active: true, char: open[1][0], length: len(open[1])}, true
	}
	closing := fenceCloseRe.FindStringSubmatch(line)
	if closing != nil && strings.HasPrefix(trimStart(line), string(f.char)) && len(closing[1]) >= f.length {
		return inactiveFence, true
	}
	return f, false
}

func tryAtxHeading(line string, offset int) (heading, bool) {
	m := atxRe.FindStringSubmatch(line)
	if m == nil {
		return heading{}, false
	}
	depth := len(m[1])
	rawText := line[len(m[0]):]
	text := stripInlineMarkup(trimBoth(stripAtxTrailing(rawText)))
	return heading{depth: depth, offset: offset, text: text}, true
}

func setextDepth(line string) int {
	if setextH1Re.MatchString(line) {
		return 1
	}
	if setextH2Re.MatchString(line) {
		return 2
	}
	return 0
}

func trySetextFromState(st scanState, line, markdown string) (heading, bool) {
	if st.paragraphStartOffset == noParagraph || st.prevWasFenceBoundary {
		return heading{}, false
	}
	depth := setextDepth(line)
	if depth == 0 {
		return heading{}, false
	}
	rawText := trimEnd(markdown[st.paragraphStartOffset:st.offset])
	parts := strings.Split(rawText, "\n")
	for i, p := range parts {
		parts[i] = trimBoth(p)
	}
	text := stripInlineMarkup(strings.Join(parts, " "))
	return heading{depth: depth, offset: st.paragraphStartOffset, text: text}, true
}

func isIndentedCode(line string) bool {
	return indentCodeRe.MatchString(line)
}

func isBlockStart(line string) bool {
	return blockStartRe.MatchString(line) || strings.HasPrefix(trimStart(line), ">")
}

func findHeading(st scanState, line, markdown string) (heading, bool) {
	if h, ok := tryAtxHeading(line, st.offset); ok {
		return h, true
	}
	return trySetextFromState(st, line, markdown)
}

func processLine(st scanState, line string, fence fenceState, fenceChanged bool, nextOffset int, markdown string, headings *[]heading) scanState {
	if fence.active || fenceChanged {
		return scanState{fence: fence, offset: nextOffset, paragraphStartOffset: noParagraph, prevWasFenceBoundary: true}
	}

	if trimBoth(line) == "" || isIndentedCode(line) || isBlockStart(line) {
		return scanState{fence: fence, offset: nextOffset, paragraphStartOffset: noParagraph, prevWasFenceBoundary: false}
	}

	if h, ok := findHeading(st, line, markdown); ok {
		*headings = append(*headings, h)
		return scanState{fence: fence, offset: nextOffset, paragraphStartOffset: noParagraph, prevWasFenceBoundary: false}
	}

	// extendParagraph: keep (or start) the current paragraph span.
	ps := st.paragraphStartOffset
	if ps == noParagraph {
		ps = st.offset
	}
	return scanState{fence: fence, offset: nextOffset, paragraphStartOffset: ps, prevWasFenceBoundary: false}
}

func parseHeadings(markdown string) []heading {
	lines := strings.Split(markdown, "\n")
	headings := []heading{}
	st := scanState{fence: inactiveFence, offset: 0, paragraphStartOffset: noParagraph, prevWasFenceBoundary: false}
	for _, line := range lines {
		fence, changed := updateFenceState(line, st.fence)
		nextOffset := st.offset + len(line) + 1
		st = processLine(st, line, fence, changed, nextOffset, markdown, &headings)
	}
	return headings
}

func normalizeCrlf(s string) string {
	s = strings.ReplaceAll(s, "\r\n", "\n")
	return strings.ReplaceAll(s, "\r", "\n")
}

// convert is md2idx's core: Markdown in, {index, sections} out.
func convert(markdown string) result {
	normalized := normalizeCrlf(markdown)
	headings := parseHeadings(normalized)

	firstOffset := len(normalized)
	if len(headings) > 0 {
		firstOffset = headings[0].offset
	}

	preIndex := []string{}
	preSections := []string{}
	if firstOffset > 0 {
		if pre := trimEnd(normalized[:firstOffset]); pre != "" {
			preIndex = []string{"0."}
			preSections = []string{pre}
		}
	}

	headingSections := make([]string, len(headings))
	for i, h := range headings {
		end := len(normalized)
		if i+1 < len(headings) {
			end = headings[i+1].offset
		}
		headingSections[i] = trimEnd(normalized[h.offset:end])
	}

	headingIndex := make([]string, len(headings))
	for i, h := range headings {
		marker := strings.Repeat("#", h.depth)
		sectionIdx := i + len(preSections)
		headingIndex[i] = fmt.Sprintf("%s %d. %s", marker, sectionIdx, h.text)
	}

	indexLines := append(append([]string{}, preIndex...), headingIndex...)
	sections := append(append([]string{}, preSections...), headingSections...)

	return result{
		Index:    strings.Join(indexLines, "\n"),
		Sections: sections,
	}
}
