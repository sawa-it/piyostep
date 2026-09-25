#!/usr/bin/env python3
"""Check SwiftUI View initialiser call sites against memberwise initialisers.

Swift synthesises a memberwise initialiser whose parameters follow declaration
order, skipping private stored properties that already have a value (`@State`,
`@Environment`, ...). Hand-authored call sites are easy to get wrong, so this
script verifies for every `struct X: View` in the project that each `X(...)`
call uses known argument labels **in declaration order**, and that every
property without a default value is supplied.

Usage: python3 Tools/view_init_check.py
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SEARCH_ROOTS = [ROOT / "PiyoStep", ROOT / "PiyoStepTests"]

WRAPPERS_WITH_DEFAULT = ("@State", "@Environment", "@FocusState", "@Namespace", "@GestureState")

struct_re = re.compile(r"^(?:public |private )?struct ([A-Za-z_][A-Za-z0-9_]*)\s*:\s*([^{]+)\{", re.M)
# Stored properties only: computed ones end the line with `{`.
property_re = re.compile(
    r"^\s{4}(@[A-Za-z]+(?:\.[A-Za-z]+)*(?:\([^)]*\))?\s+)?(?:private\s+|public\s+)?(let|var)\s+"
    r"([A-Za-z_][A-Za-z0-9_]*)\s*:\s*([^\n={]+?)(\s*=\s*([^\n]+))?\s*$",
    re.M,
)


def swift_files() -> list[Path]:
    files: list[Path] = []
    for root in SEARCH_ROOTS:
        if root.exists():
            files.extend(sorted(root.rglob("*.swift")))
    return files


def body_of(text: str, start: int) -> str:
    """Return the source between the struct's opening brace and its match."""
    depth = 0
    index = text.index("{", start)
    begin = index
    while index < len(text):
        if text[index] == "{":
            depth += 1
        elif text[index] == "}":
            depth -= 1
            if depth == 0:
                return text[begin + 1 : index]
        index += 1
    return text[begin + 1 :]


def collect_views() -> dict[str, list[tuple[str, bool]]]:
    """name -> [(label, has_default)] in declaration order."""
    views: dict[str, list[tuple[str, bool]]] = {}
    for path in swift_files():
        text = path.read_text(encoding="utf-8")
        for match in struct_re.finditer(text):
            name = match.group(1)
            conformances = match.group(2)
            if "View" not in conformances:
                continue
            body = body_of(text, match.start())
            parameters: list[tuple[str, bool]] = []
            for prop in property_re.finditer(body):
                wrapper = (prop.group(1) or "").strip()
                label = prop.group(3)
                type_text = prop.group(4).strip()
                default = prop.group(5)
                # `@FocusState.Binding` は `@FocusState` と違って自前で値を持たず、
                # 呼び出し側から渡してもらう必要がある。
                if wrapper.startswith(WRAPPERS_WITH_DEFAULT) and not wrapper.startswith(
                    tuple(f"{name}.Binding" for name in WRAPPERS_WITH_DEFAULT)
                ):
                    continue
                if "private" in prop.group(0) and default:
                    continue
                if wrapper.startswith("@ViewBuilder") or wrapper.startswith("@Binding") or wrapper.startswith("@Bindable"):
                    parameters.append((label, default is not None))
                    continue
                has_default = default is not None or type_text.endswith("?")
                parameters.append((label, has_default))
            views[name] = parameters
    return views


def check_call_sites(views: dict[str, list[tuple[str, bool]]]) -> list[str]:
    problems: list[str] = []
    for path in swift_files():
        text = path.read_text(encoding="utf-8")
        for name, parameters in views.items():
            labels = [label for label, _ in parameters]
            required = [label for label, has_default in parameters if not has_default]
            for call in re.finditer(rf"(?<![A-Za-z0-9_.]){name}\(", text):
                start = call.end()
                depth = 1
                index = start
                while index < len(text) and depth > 0:
                    if text[index] == "(":
                        depth += 1
                    elif text[index] == ")":
                        depth -= 1
                    index += 1
                arguments = text[start : index - 1]
                # top-level labels only
                used: list[str] = []
                depth = 0
                # `.case:` inside a ternary is not an argument label.
                for piece in re.finditer(r"[(){}\[\]]|(?<![.\w?])([A-Za-z_][A-Za-z0-9_]*)\s*:(?!:)", arguments):
                    token = piece.group(0)
                    if token in "({[":
                        depth += 1
                    elif token in ")}]":
                        depth -= 1
                    elif depth == 0 and piece.group(1):
                        used.append(piece.group(1))
                line = text[: call.start()].count("\n") + 1
                location = f"{path.relative_to(ROOT)}:{line}"

                unknown = [label for label in used if label not in labels]
                if unknown:
                    problems.append(f"{location}: {name}(...) に未知のラベル {unknown}")
                    continue
                positions = [labels.index(label) for label in used]
                if positions != sorted(positions):
                    problems.append(f"{location}: {name}(...) のラベル順が宣言順と違います {used}")
                # trailing closures make "missing" checks unreliable; only flag
                # when no trailing closure follows the call.
                following = text[index : index + 3]
                if "{" not in following:
                    missing = [label for label in required if label not in used]
                    if missing:
                        problems.append(f"{location}: {name}(...) に {missing} がありません")
    return problems


def main() -> int:
    views = collect_views()
    problems = check_call_sites(views)
    print(f"View: {len(views)} 個を検査しました")
    if problems:
        print(f"\n{len(problems)} 件:")
        for problem in sorted(set(problems)):
            print("  " + problem)
        return 1
    print("問題は見つかりませんでした")
    return 0


if __name__ == "__main__":
    sys.exit(main())
