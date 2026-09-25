#!/usr/bin/env python3
"""Check that `switch` statements over project enums are exhaustive.

An inexhaustive switch is a hard compile error in Swift, and it is the mistake
most likely to slip through hand-authored code. This walks the tree-sitter
parse tree, finds every switch without a `default` / `_` case, works out which
project enum its `.case` patterns belong to, and reports missing cases.

Setup:  pip install tree_sitter tree_sitter_swift
Usage:  python3 Tools/switch_exhaustive_check.py [root ...]
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

try:
    import tree_sitter_swift
    from tree_sitter import Language, Parser
except ImportError:
    print("tree_sitter / tree_sitter_swift が必要です: pip install tree_sitter tree_sitter_swift")
    sys.exit(2)

ROOT = Path(__file__).resolve().parent.parent

# 同じ case 名を持つ列挙が複数ある場合は判定できないので除外する。
AMBIGUOUS_SKIP = {"none"}

enum_header_re = re.compile(
    r"(?:^|\n)[ \t]*(?:public |private |internal |indirect )*enum ([A-Za-z_][A-Za-z0-9_]*)"
)


def collect_files(roots: list[Path]) -> list[Path]:
    files: list[Path] = []
    for root in roots:
        if root.is_file() and root.suffix == ".swift":
            files.append(root)
        else:
            files.extend(sorted(root.rglob("*.swift")))
    return files


def enum_bodies(text: str) -> dict[str, set[str]]:
    """Map enum name -> declared case names.

    Only `case` lines at the enum's own brace depth count: `case` inside a
    nested switch is a pattern, not a declaration. Associated-value payloads and
    raw values are stripped before splitting on commas.
    """
    enums: dict[str, set[str]] = {}
    for match in enum_header_re.finditer(text):
        name = match.group(1)
        brace = text.find("{", match.end())
        if brace == -1:
            continue
        depth = 0
        index = brace
        while index < len(text):
            if text[index] == "{":
                depth += 1
            elif text[index] == "}":
                depth -= 1
                if depth == 0:
                    break
            index += 1
        body = text[brace + 1 : index]

        cases: set[str] = set()
        level = 0
        for line in body.splitlines():
            stripped = line.strip()
            if level == 0 and stripped.startswith("case "):
                payload = stripped[len("case "):]
                payload = re.sub(r"\([^()]*\)", "", payload)   # 連想値を落とす
                payload = payload.split("=")[0]                # 生の値を落とす
                payload = payload.split("//")[0]
                for piece in payload.split(","):
                    identifier = re.match(r"([a-z_][A-Za-z0-9_]*)\s*$", piece.strip())
                    if identifier:
                        cases.add(identifier.group(1))
            level += line.count("{") - line.count("}")

        if not cases:
            continue
        if name in enums and enums[name] != cases:
            # 同名の入れ子型がある場合は判定できない
            enums[name] = set()
        else:
            enums[name] = cases
    return enums


def switch_nodes(node, out: list) -> None:
    if node.type == "switch_statement":
        out.append(node)
    for child in node.children:
        switch_nodes(child, out)


def relative(path: Path) -> str:
    try:
        return str(path.resolve().relative_to(ROOT))
    except ValueError:
        return str(path)


def main(argv: list[str]) -> int:
    roots = [Path(a).resolve() for a in argv[1:]] or [ROOT]
    files = collect_files(roots)

    all_enums: dict[str, set[str]] = {}
    for path in files:
        for name, cases in enum_bodies(path.read_text(encoding="utf-8")).items():
            if name in all_enums and all_enums[name] != cases:
                all_enums[name] = set()   # 同名の列挙が複数あるので判定しない
            else:
                all_enums[name] = cases

    parser = Parser(Language(tree_sitter_swift.language()))
    problems: list[str] = []
    checked = 0

    for path in files:
        source = path.read_bytes()
        tree = parser.parse(source)
        switches: list = []
        switch_nodes(tree.root_node, switches)

        for node in switches:
            text = source[node.start_byte : node.end_byte].decode("utf-8", errors="replace")
            # `default:` があるものは網羅を気にしなくてよい
            if re.search(r"^\s*default\s*:", text, re.M):
                continue
            if re.search(r"^\s*case\s+_[\s,:]", text, re.M):
                continue

            used: set[str] = set()
            for case_line in re.finditer(r"^\s*case\s+([^\n]+?):", text, re.M):
                for piece in case_line.group(1).split(","):
                    piece = piece.strip()
                    dotted = re.match(r"\.([a-z_][A-Za-z0-9_]*)", piece)
                    if dotted:
                        used.add(dotted.group(1))
            used -= AMBIGUOUS_SKIP
            if not used:
                continue

            candidates = [
                name for name, cases in all_enums.items()
                if cases and used <= cases
            ]
            # ちょうど 1 つの列挙にだけ当てはまるときに限り判定する
            exact = [name for name in candidates if all_enums[name] == used]
            if exact:
                checked += 1
                continue
            if len(candidates) != 1:
                continue

            name = candidates[0]
            missing = sorted(all_enums[name] - used)
            checked += 1
            if missing:
                line = source[: node.start_byte].decode("utf-8", errors="replace").count("\n") + 1
                problems.append(
                    f"{relative(path)}:{line}: {name} の switch に "
                    f"{', '.join(missing)} がありません"
                )

    print(f"{len(files)} ファイル / 判定できた switch {checked} 件 / 列挙 {len(all_enums)} 種")
    if problems:
        print(f"\n{len(problems)} 件:")
        for problem in sorted(set(problems)):
            print("  " + problem)
        return 1
    print("網羅されていない switch はありません")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
