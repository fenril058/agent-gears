package main

import (
	"reflect"
	"testing"
)

// These cases are ported verbatim from upstream src/md2idx.ts (the embedded
// vitest suite). They pin mdidx to md2idx's exact behaviour.

func eqIndex(t *testing.T, got result, want string) {
	t.Helper()
	if got.Index != want {
		t.Errorf("index = %q, want %q", got.Index, want)
	}
}

func eqSections(t *testing.T, got result, want []string) {
	t.Helper()
	if !reflect.DeepEqual(got.Sections, want) {
		t.Errorf("sections = %#v, want %#v", got.Sections, want)
	}
}

func TestBasic(t *testing.T) {
	t.Run("heading + body", func(t *testing.T) {
		r := convert("# Hello\n\nWorld\n\n## Sub\n\nBody")
		eqSections(t, r, []string{"# Hello\n\nWorld", "## Sub\n\nBody"})
		eqIndex(t, r, "# 0. Hello\n## 1. Sub")
	})

	t.Run("preamble before first heading", func(t *testing.T) {
		r := convert("Preamble text\n\n# Title\n\nBody")
		if r.Sections[0] != "Preamble text" {
			t.Errorf("sections[0] = %q", r.Sections[0])
		}
		if r.Sections[1] != "# Title\n\nBody" {
			t.Errorf("sections[1] = %q", r.Sections[1])
		}
		eqIndex(t, r, "0.\n# 1. Title")
	})

	t.Run("setext (=== and ---)", func(t *testing.T) {
		r := convert("Title\n===\n\nBody\n\nSub\n---\n\nMore")
		if len(r.Sections) != 2 {
			t.Fatalf("len = %d", len(r.Sections))
		}
		eqIndex(t, r, "# 0. Title\n## 1. Sub")
	})

	t.Run("level skip # then ###", func(t *testing.T) {
		r := convert("# Top\n\n### Skipped\n\nBody")
		eqIndex(t, r, "# 0. Top\n### 1. Skipped")
	})

	t.Run("headings with no body", func(t *testing.T) {
		r := convert("# One\n## Two\n## Three")
		eqSections(t, r, []string{"# One", "## Two", "## Three"})
	})

	t.Run("markdown without headings", func(t *testing.T) {
		r := convert("Just plain text.\n\nNo headings here.")
		eqSections(t, r, []string{"Just plain text.\n\nNo headings here."})
		eqIndex(t, r, "0.")
	})

	t.Run("empty string", func(t *testing.T) {
		r := convert("")
		eqSections(t, r, []string{})
		eqIndex(t, r, "")
	})
}

func TestCodeFence(t *testing.T) {
	t.Run("backtick fence # not a heading", func(t *testing.T) {
		r := convert("# Real\n\n```\n# Not a heading\n```\n\n## Also Real")
		if len(r.Sections) != 2 {
			t.Fatalf("len = %d", len(r.Sections))
		}
		if r.Sections[0] != "# Real\n\n```\n# Not a heading\n```" {
			t.Errorf("sections[0] = %q", r.Sections[0])
		}
		eqIndex(t, r, "# 0. Real\n## 1. Also Real")
	})

	t.Run("tilde fence # skipped", func(t *testing.T) {
		r := convert("# Top\n\n~~~\n# fake\n~~~\n\n## Bottom")
		if len(r.Sections) != 2 {
			t.Fatalf("len = %d", len(r.Sections))
		}
	})

	t.Run("indented fence recognised", func(t *testing.T) {
		r := convert("# Before\n\n   ```\n# Not heading\n   ```\n\n## After")
		if len(r.Sections) != 2 {
			t.Fatalf("len = %d", len(r.Sections))
		}
		eqIndex(t, r, "# 0. Before\n## 1. After")
	})

	t.Run("=== right after fence close is not setext", func(t *testing.T) {
		r := convert("# Top\n\n```\ncode\n```\n===\n\n## Bottom")
		if len(r.Sections) != 2 {
			t.Fatalf("len = %d", len(r.Sections))
		}
		eqIndex(t, r, "# 0. Top\n## 1. Bottom")
	})

	t.Run("unclosed fence: everything inside is non-heading", func(t *testing.T) {
		r := convert("# Before\n\n```\n# fake\n## also fake")
		if len(r.Sections) != 1 {
			t.Fatalf("len = %d", len(r.Sections))
		}
		eqIndex(t, r, "# 0. Before")
	})
}

func TestSetext(t *testing.T) {
	t.Run("multi-line paragraph joined", func(t *testing.T) {
		r := convert("Foo\nbar\n---\n\nBody")
		if len(r.Sections) != 1 {
			t.Fatalf("len = %d", len(r.Sections))
		}
		eqIndex(t, r, "## 0. Foo bar")
	})

	t.Run("indented setext underline recognised", func(t *testing.T) {
		r := convert("Title\n   ===\n\nBody")
		eqIndex(t, r, "# 0. Title")
	})
}

func TestInlineStripping(t *testing.T) {
	t.Run("link/code/emphasis to plain text", func(t *testing.T) {
		r := convert("# Hello `world` **bold** [link](url)\n\nBody")
		eqIndex(t, r, "# 0. Hello world bold link")
	})

	t.Run("double-backtick inline code stripped", func(t *testing.T) {
		r := convert("# Use ``code`` here\n\nBody")
		eqIndex(t, r, "# 0. Use code here")
	})

	t.Run("ATX trailing # removed", func(t *testing.T) {
		r := convert("# Title ##\n\nBody")
		eqIndex(t, r, "# 0. Title")
	})

	t.Run("trailing # without space stays", func(t *testing.T) {
		r := convert("# Title##\n\nBody")
		eqIndex(t, r, "# 0. Title##")
	})
}

func TestCommonMarkSubset(t *testing.T) {
	t.Run("1-3 leading spaces ATX recognised", func(t *testing.T) {
		r := convert("   # Indented\n\nBody")
		if len(r.Sections) != 1 {
			t.Fatalf("len = %d", len(r.Sections))
		}
		eqIndex(t, r, "# 0. Indented")
	})

	t.Run("4+ leading spaces is code, not heading", func(t *testing.T) {
		r := convert("    # Not a heading")
		eqSections(t, r, []string{"    # Not a heading"})
		eqIndex(t, r, "0.")
	})

	t.Run("# alone (no space) is not a heading", func(t *testing.T) {
		r := convert("#\n\nBody")
		eqSections(t, r, []string{"#\n\nBody"})
		eqIndex(t, r, "0.")
	})

	t.Run("CRLF handled", func(t *testing.T) {
		r := convert("# Title\r\n\r\nBody\r\n\r\n## Sub\r\n\r\nMore")
		eqSections(t, r, []string{"# Title\n\nBody", "## Sub\n\nMore"})
		eqIndex(t, r, "# 0. Title\n## 1. Sub")
	})

	t.Run("--- after 4-space indented line is not setext", func(t *testing.T) {
		r := convert("    code\n---\n\n## Real")
		if len(r.Sections) != 2 {
			t.Fatalf("len = %d", len(r.Sections))
		}
		eqIndex(t, r, "0.\n## 1. Real")
	})

	t.Run("--- right after list is not setext", func(t *testing.T) {
		r := convert("- one\n- two\n---\n\n# Next")
		if len(r.Sections) != 2 {
			t.Fatalf("len = %d", len(r.Sections))
		}
		eqIndex(t, r, "0.\n# 1. Next")
	})

	t.Run("=== after blockquote is not setext", func(t *testing.T) {
		r := convert("> quote\n===\n\n# Next")
		if len(r.Sections) != 2 {
			t.Fatalf("len = %d", len(r.Sections))
		}
		eqIndex(t, r, "0.\n# 1. Next")
	})
}
