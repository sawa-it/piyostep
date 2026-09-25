#!/usr/bin/env python3
"""Parse every Swift file with tree-sitter and report syntax errors.

This is a real grammar-based parse (not a type check), so it catches genuine
syntax errors when no Swift toolchain is available.

Setup:  pip install tree_sitter tree_sitter_swift
Usage:  python3 Tools/swift_parse_check.py [root ...]
"""

from __future__ import annotations

import sys
from pathlib import Path

try:
    import tree_sitter_swift
    from tree_sitter import Language, Parser
except ImportError:
    print("tree_sitter / tree_sitter_swift が必要です: pip install tree_sitter tree_sitter_swift")
    sys.exit(2)


def collect(roots: list[Path]) -> list[Path]:
    files: list[Path] = []
    for root in roots:
        if root.is_file() and root.suffix == ".swift":
            files.append(root)
        else:
            files.extend(sorted(root.rglob("*.swift")))
    return files


def walk_errors(node, source: bytes, findings: list[str], path: Path) -> None:
    if node.type == "ERROR" or node.is_missing:
        line = node.start_point[0] + 1
        column = node.start_point[1] + 1
        snippet = source[node.start_byte : min(node.end_byte, node.start_byte + 90)]
        text = snippet.decode("utf-8", errors="replace").replace("\n", "⏎")
        kind = "missing" if node.is_missing else "error"
        findings.append(f"{path}:{line}:{column}: {kind}: {text}")
        return
    if not node.has_error:
        return
    for child in node.children:
        walk_errors(child, source, findings, path)


def main(argv: list[str]) -> int:
    roots = [Path(a) for a in argv[1:]] or [Path(".")]
    files = collect(roots)
    if not files:
        print("swift ファイルが見つかりません")
        return 1

    parser = Parser(Language(tree_sitter_swift.language()))
    findings: list[str] = []

    for path in files:
        source = path.read_bytes()
        tree = parser.parse(source)
        if tree.root_node.has_error:
            walk_errors(tree.root_node, source, findings, path)

    print(f"{len(files)} ファイルを構文解析しました")
    if findings:
        print(f"\n{len(findings)} 件の構文エラー:")
        for finding in findings:
            print("  " + finding)
        return 1
    print("構文エラーはありません")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
