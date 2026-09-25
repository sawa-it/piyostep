#!/usr/bin/env python3
"""Lightweight static sanity checks for Swift sources.

This is *not* a compiler. It catches the class of mistakes that are easy to make
when Swift sources are authored without a toolchain available:

  * unbalanced (), [] and {} (comment- and string-literal aware)
  * unterminated string literals / block comments
  * multi-character Character literals inside `Set<Character>` literals
  * references to types that are never declared anywhere in the scanned tree
  * duplicate top-level type declarations

Usage: python3 Tools/swift_sanity.py [root ...]
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

PAIRS = {")": "(", "]": "[", "}": "{"}
OPENERS = set(PAIRS.values())


class Finding:
    def __init__(self, path: Path, line: int, message: str):
        self.path = path
        self.line = line
        self.message = message

    def __str__(self) -> str:
        return f"{self.path}:{self.line}: {self.message}"


def scan_balance(path: Path, text: str) -> list[Finding]:
    """Walk the source tracking comments and string literals."""
    findings: list[Finding] = []
    stack: list[tuple[str, int]] = []
    # interpolation stack: remembers the bracket depth when entering \( ... )
    i = 0
    line = 1
    n = len(text)
    in_line_comment = False
    block_comment_depth = 0
    in_string = False
    in_multiline_string = False
    string_start_line = 0

    while i < n:
        ch = text[i]
        nxt = text[i + 1] if i + 1 < n else ""

        if ch == "\n":
            line += 1
            in_line_comment = False
            if in_string and not in_multiline_string:
                findings.append(Finding(path, string_start_line, "unterminated string literal"))
                in_string = False
            i += 1
            continue

        if in_line_comment:
            i += 1
            continue

        if block_comment_depth > 0:
            if ch == "/" and nxt == "*":
                block_comment_depth += 1
                i += 2
                continue
            if ch == "*" and nxt == "/":
                block_comment_depth -= 1
                i += 2
                continue
            i += 1
            continue

        if in_string:
            if ch == "\\":
                if nxt == "(":
                    # string interpolation: push a marker so the ')' is matched
                    stack.append(("(", line))
                    in_string = False
                    # remember that this paren closes back into a string
                    stack[-1] = ("(#interp" + ("3" if in_multiline_string else "1"), line)
                    i += 2
                    continue
                i += 2
                continue
            if in_multiline_string:
                if text.startswith('"""', i):
                    in_string = False
                    in_multiline_string = False
                    i += 3
                    continue
            elif ch == '"':
                in_string = False
                i += 1
                continue
            i += 1
            continue

        # not in string / comment
        if ch == "/" and nxt == "/":
            in_line_comment = True
            i += 2
            continue
        if ch == "/" and nxt == "*":
            block_comment_depth = 1
            i += 2
            continue
        if text.startswith('"""', i):
            in_string = True
            in_multiline_string = True
            string_start_line = line
            i += 3
            continue
        if ch == '"':
            in_string = True
            in_multiline_string = False
            string_start_line = line
            i += 1
            continue

        if ch in OPENERS:
            stack.append((ch, line))
            i += 1
            continue
        if ch in PAIRS:
            if not stack:
                findings.append(Finding(path, line, f"unmatched closing '{ch}'"))
                i += 1
                continue
            top, top_line = stack.pop()
            if top.startswith("(#interp"):
                if ch != ")":
                    findings.append(
                        Finding(path, line, f"expected ')' to close string interpolation opened at line {top_line}")
                    )
                else:
                    in_string = True
                    in_multiline_string = top.endswith("3")
                    string_start_line = top_line
                i += 1
                continue
            if top != PAIRS[ch]:
                findings.append(
                    Finding(path, line, f"'{ch}' closes '{top}' opened at line {top_line}")
                )
            i += 1
            continue

        i += 1

    if block_comment_depth > 0:
        findings.append(Finding(path, line, "unterminated block comment"))
    if in_string:
        findings.append(Finding(path, string_start_line, "unterminated string literal"))
    for opener, opened_line in stack:
        findings.append(Finding(path, opened_line, f"unclosed '{opener}'"))
    return findings


CHAR_SET_RE = re.compile(r"Set<Character>\s*=\s*\[(.*?)\]", re.S)
STRING_ITEM_RE = re.compile(r'"((?:[^"\\]|\\.)*)"')


def scan_character_sets(path: Path, text: str) -> list[Finding]:
    findings: list[Finding] = []
    for match in CHAR_SET_RE.finditer(text):
        body = match.group(1)
        line = text[: match.start()].count("\n") + 1
        for item in STRING_ITEM_RE.finditer(body):
            raw = item.group(1)
            # crude unescape of the escapes we actually use
            value = raw.replace("\\n", "\n").replace("\\t", "\t").replace('\\"', '"')
            value = re.sub(r"\\u\{([0-9A-Fa-f]+)\}", lambda m: chr(int(m.group(1), 16)), value)
            if len(value) != 1:
                findings.append(
                    Finding(path, line, f"Set<Character> literal element {raw!r} is not a single Character")
                )
    return findings


# Only top-level declarations (column 0) — nested types may repeat names legitimately.
DECL_RE = re.compile(
    r"^(?:public |internal |private |fileprivate |open |final |indirect )*"
    r"(struct|class|enum|protocol|actor) ([A-Za-z_][A-Za-z0-9_]*)",
    re.M,
)
EXT_RE = re.compile(r"^\s*(?:public\s+)?extension\s+([A-Za-z_][A-Za-z0-9_]*)", re.M)


def collect_declarations(files: list[Path]) -> dict[str, list[Path]]:
    decls: dict[str, list[Path]] = {}
    for path in files:
        text = path.read_text(encoding="utf-8")
        for match in DECL_RE.finditer(text):
            decls.setdefault(match.group(2), []).append(path)
    return decls


def main(argv: list[str]) -> int:
    roots = [Path(a) for a in argv[1:]] or [Path(".")]
    files: list[Path] = []
    for root in roots:
        if root.is_file() and root.suffix == ".swift":
            files.append(root)
        else:
            files.extend(sorted(root.rglob("*.swift")))

    if not files:
        print("no swift files found")
        return 1

    findings: list[Finding] = []
    for path in files:
        text = path.read_text(encoding="utf-8")
        findings.extend(scan_balance(path, text))
        findings.extend(scan_character_sets(path, text))

    decls = collect_declarations(files)
    duplicates = {name: paths for name, paths in decls.items() if len(paths) > 1}
    for name, paths in sorted(duplicates.items()):
        findings.append(Finding(paths[0], 0, f"type '{name}' declared in {len(paths)} files: "
                                             + ", ".join(str(p) for p in paths)))

    print(f"scanned {len(files)} swift files ({sum(len(p.read_text(encoding='utf-8').splitlines()) for p in files)} lines)")
    if findings:
        print(f"\n{len(findings)} finding(s):")
        for finding in findings:
            print("  " + str(finding))
        return 1
    print("no findings")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
