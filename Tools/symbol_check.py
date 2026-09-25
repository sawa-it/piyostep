#!/usr/bin/env python3
"""Cross-check symbol references that a Swift compiler would catch.

Without a Swift toolchain we cannot type-check, but we *can* verify the classes
of mistake that are most likely in hand-authored sources:

  1. `A11yID.<member>` references resolve to a declared member.
  2. `PiyoTheme.<member>` references resolve to a declared member.
  3. Types used from the app target that live in PiyoCore are declared `public`.
  4. Every `Skill` / `Subject` enum case is handled by the exhaustive switches
     that must cover them (icon pickers, titles, generators).
  5. Accessibility identifiers used by UI tests exist in A11yID.

Usage: python3 Tools/symbol_check.py
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CORE = ROOT / "Packages/PiyoCore/Sources/PiyoCore"
APP = ROOT / "PiyoStep"
APP_TESTS = ROOT / "PiyoStepTests"
UI_TESTS = ROOT / "PiyoStepUITests"

problems: list[str] = []


def swift_files(*roots: Path) -> list[Path]:
    files: list[Path] = []
    for root in roots:
        if root.exists():
            files.extend(sorted(root.rglob("*.swift")))
    return files


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def members_of_enum(path: Path, enum_name: str) -> set[str]:
    text = read(path)
    match = re.search(rf"enum {enum_name} \{{(.*)", text, re.S)
    if not match:
        return set()
    body = match.group(1)
    names = set(re.findall(r"static (?:let|var) ([A-Za-z_][A-Za-z0-9_]*)", body))
    names |= set(re.findall(r"static func ([A-Za-z_][A-Za-z0-9_]*)", body))
    names |= set(re.findall(r"case ([a-z][A-Za-z0-9_]*)", body))
    return names


# --- 1 & 5: A11yID -----------------------------------------------------------

a11y_path = CORE / "UI/A11yID.swift"
a11y_members = members_of_enum(a11y_path, "A11yID")
if not a11y_members:
    problems.append("A11yID の定義が読み取れません")

for path in swift_files(APP, APP_TESTS, UI_TESTS):
    for member in re.findall(r"A11yID\.([A-Za-z_][A-Za-z0-9_]*)", read(path)):
        if member not in a11y_members:
            problems.append(f"{path.relative_to(ROOT)}: A11yID.{member} は未定義")

# --- 2: PiyoTheme ------------------------------------------------------------

theme_path = APP / "DesignSystem/PiyoTheme.swift"
theme_members = members_of_enum(theme_path, "PiyoTheme")
for path in swift_files(APP, APP_TESTS):
    for member in re.findall(r"PiyoTheme\.([A-Za-z_][A-Za-z0-9_]*)", read(path)):
        if member not in theme_members:
            problems.append(f"{path.relative_to(ROOT)}: PiyoTheme.{member} は未定義")

# --- 3: public-ness of core types used by the app ---------------------------

core_text = "\n".join(read(path) for path in swift_files(CORE))
core_types: dict[str, bool] = {}
for match in re.finditer(
    r"^\s*(public\s+)?(?:final\s+)?(struct|class|enum|protocol|actor)\s+([A-Za-z_][A-Za-z0-9_]*)",
    core_text,
    re.M,
):
    core_types[match.group(3)] = bool(match.group(1))

app_text = "\n".join(read(path) for path in swift_files(APP, APP_TESTS, UI_TESTS))
for name, is_public in core_types.items():
    if is_public:
        continue
    if re.search(rf"\b{name}\b", app_text):
        problems.append(f"PiyoCore の {name} は public ではないのにアプリ側で参照されています")

# --- 4: exhaustive switches over Skill / Subject -----------------------------

def enum_cases(path: Path, enum_name: str) -> list[str]:
    text = read(path)
    match = re.search(rf"enum {enum_name}[^{{]*\{{(.*?)\n\}}", text, re.S)
    if not match:
        return []
    return re.findall(r"^\s*case ([a-z][A-Za-z0-9_]*)", match.group(1), re.M)


subject_path = CORE / "Models/Subject.swift"
skills = enum_cases(subject_path, "Skill")
subjects = enum_cases(subject_path, "Subject")

if len(skills) < 5:
    problems.append("Skill の case が読み取れません")
if len(subjects) < 5:
    problems.append("Subject の case が読み取れません")

# Skill を switch する場所（default が無いもの）はすべての case を持つ必要がある
for path in swift_files(APP, CORE):
    text = read(path)
    for match in re.finditer(r"switch (?:self|skill|question\.skill) \{(.*?)\n(\s*)\}", text, re.S):
        body = match.group(1)
        if "default" in body:
            continue
        mentioned = set(re.findall(r"case ([^\n:]+):", body))
        flattened = set()
        for item in mentioned:
            for piece in item.split(","):
                flattened.add(piece.strip().lstrip("."))
        if not flattened & set(skills):
            continue
        missing = [skill for skill in skills if skill not in flattened]
        if missing:
            line = text[: match.start()].count("\n") + 1
            problems.append(
                f"{path.relative_to(ROOT)}:{line}: Skill の switch に {', '.join(missing)} がありません"
            )

# Subject を網羅する辞書・switch
for path in swift_files(APP):
    text = read(path)
    for match in re.finditer(r"switch subject \{(.*?)\n(\s*)\}", text, re.S):
        body = match.group(1)
        if "default" in body:
            continue
        flattened = set()
        for item in re.findall(r"case ([^\n:]+):", body):
            for piece in item.split(","):
                flattened.add(piece.strip().lstrip("."))
        if not flattened & set(subjects):
            continue
        missing = [name for name in subjects if name not in flattened]
        if missing:
            line = text[: match.start()].count("\n") + 1
            problems.append(
                f"{path.relative_to(ROOT)}:{line}: Subject の switch に {', '.join(missing)} がありません"
            )

# --- report ------------------------------------------------------------------

print(f"A11yID: {len(a11y_members)} 個, PiyoTheme: {len(theme_members)} 個")
print(f"PiyoCore の型: {len(core_types)} 個 (public: {sum(core_types.values())})")
print(f"Skill: {len(skills)} 個, Subject: {len(subjects)} 個")

if problems:
    print(f"\n{len(problems)} 件の問題:")
    for problem in sorted(set(problems)):
        print("  " + problem)
    sys.exit(1)

print("\n問題は見つかりませんでした")
