#!/usr/bin/env python3
"""Mechanically extract merged context windows around cited line ranges.

Used by the spec-ambiguity-audit skill to check a cheap model's flagged
ambiguities against their surrounding text, without re-reading the whole
document. Ranges are sorted and overlapping/adjacent windows are merged
before extraction, so the same lines are never read twice.

Usage:
    extract_context.py <file> --margin 10 --range 62 --range 316-318 ...
    extract_context.py <file> --margin 10 --ranges-file ranges.txt

ranges.txt: one range per line, "N" or "N-M", optionally followed by a
label (e.g. the citation id) after a tab. Blank lines and '#' comments
are ignored.
"""

import argparse
import sys


def parse_range(token: str) -> tuple[int, int]:
    token = token.strip()
    if "-" in token:
        start_s, end_s = token.split("-", 1)
        start, end = int(start_s), int(end_s)
    else:
        start = end = int(token)
    if start < 1:
        raise ValueError(f"line numbers must be >= 1: {token!r}")
    if start > end:
        raise ValueError(f"range start must be <= end: {token!r}")
    return start, end


def merge_ranges(ranges: list[tuple[int, int, str]], margin: int, max_line: int):
    """Expand each (start, end, label) by margin, then merge overlaps.

    Returns a list of (window_start, window_end, [labels]).
    """
    expanded = []
    for start, end, label in ranges:
        w_start = max(1, start - margin)
        w_end = min(max_line, end + margin)
        expanded.append((w_start, w_end, label))

    expanded.sort(key=lambda r: (r[0], r[1]))

    merged = []
    for w_start, w_end, label in expanded:
        if merged and w_start <= merged[-1][1] + 1:
            prev_start, prev_end, labels = merged[-1]
            merged[-1] = (prev_start, max(prev_end, w_end), labels + [label])
        else:
            merged.append((w_start, w_end, [label]))
    return merged


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("file")
    parser.add_argument("--margin", type=int, default=10)
    parser.add_argument("--range", action="append", default=[], dest="ranges",
                         help='line or "start-end", repeatable')
    parser.add_argument("--ranges-file", help="file with one range per line")
    args = parser.parse_args()

    raw_ranges: list[tuple[int, int, str]] = []
    try:
        for token in args.ranges:
            start, end = parse_range(token)
            raw_ranges.append((start, end, token))

        if args.ranges_file:
            with open(args.ranges_file, encoding="utf-8") as f:
                for lineno, line in enumerate(f, 1):
                    line = line.rstrip("\n")
                    if not line or line.lstrip().startswith("#"):
                        continue
                    if "\t" in line:
                        token, label = line.split("\t", 1)
                    else:
                        token, label = line, line
                    try:
                        start, end = parse_range(token)
                    except ValueError as e:
                        raise ValueError(
                            f"{args.ranges_file}:{lineno}: {e}"
                        ) from None
                    raw_ranges.append((start, end, label))
    except ValueError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1

    if not raw_ranges:
        print("no ranges given", file=sys.stderr)
        return 1

    with open(args.file, encoding="utf-8") as f:
        lines = f.readlines()
    max_line = len(lines)

    if max_line == 0:
        print(f"error: {args.file} is empty", file=sys.stderr)
        return 1

    out_of_range = [token for start, _, token in raw_ranges if start > max_line]
    if out_of_range:
        print(
            f"error: range(s) beyond the file's {max_line} lines: "
            f"{', '.join(out_of_range)}",
            file=sys.stderr,
        )
        return 1

    merged = merge_ranges(raw_ranges, args.margin, max_line)

    total_extracted = 0
    total_file = max_line
    for w_start, w_end, labels in merged:
        print(f"=== 行 {w_start}-{w_end} (covers: {', '.join(labels)}) ===")
        for n in range(w_start, w_end + 1):
            print(f"{n:>6}\t{lines[n - 1].rstrip(chr(10))}")
        print()
        total_extracted += w_end - w_start + 1

    print(
        f"# extracted {total_extracted} lines across {len(merged)} window(s) "
        f"from a {total_file}-line file "
        f"({total_extracted / total_file:.0%} of the file)",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
