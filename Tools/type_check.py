#!/usr/bin/env python3
"""Swift ツールチェーンが無い環境で、型エラーになりやすい箇所を機械的に洗い出す。

型推論はできないが、宣言と使用箇所を突き合わせれば次の 4 クラスは検出できる。

  1. enum の associated value のアリティ／ラベルの不一致
  2. 既知の型の「型名.静的メンバー」参照が未宣言
  3. protocol の requirement を満たしていない準拠
  4. 自前の型のイニシャライザ呼び出しの引数ラベル・順序・過不足

準備: pip install tree_sitter tree_sitter_swift
使い方: python3 Tools/type_check.py [root ...]
"""

from __future__ import annotations

import re
import sys
from dataclasses import dataclass, field
from pathlib import Path

try:
    import tree_sitter_swift
    from tree_sitter import Language, Parser
except ImportError:
    print("tree_sitter / tree_sitter_swift が必要です: pip install tree_sitter tree_sitter_swift")
    sys.exit(2)

ROOT = Path(__file__).resolve().parent.parent

# コンパイラが合成する／標準ライブラリ由来のメンバー。宣言が無くても正当。
SYNTHESISED_MEMBERS = {
    "init", "self", "Type", "allCases", "rawValue", "hashValue", "description",
    "debugDescription", "min", "max", "zero", "random", "some", "none", "id",
    "encode", "decode", "hash", "count", "first", "last", "isEmpty", "map",
    "filter", "contains", "sorted", "reduce", "keys", "values", "prefix",
    "suffix", "allSatisfy", "compactMap", "flatMap", "joined", "reversed",
    "indices", "startIndex", "endIndex", "shared", "current", "default",
}

# 同名の型が複数ある・外部ライブラリと衝突するなど、判定を諦める型。
SKIPPED_TYPES = {"Stage", "TimeField", "Hand"}

# SwiftUI 等が値を供給するため、合成メンバーワイズ初期化子に現れないラッパー。
SUPPLIED_WRAPPERS = (
    "@State", "@Environment", "@FocusState", "@Namespace", "@GestureState",
    "@AppStorage", "@SceneStorage", "@StateObject", "@ObservedObject",
    "@EnvironmentObject", "@ScaledMetric",
)


@dataclass
class TypeInfo:
    name: str
    kind: str                                   # struct / class / enum / protocol / actor / extension
    files: set[str] = field(default_factory=set)
    static_members: set[str] = field(default_factory=set)
    instance_members: set[str] = field(default_factory=set)
    enum_cases: dict[str, list[str | None]] = field(default_factory=dict)  # case -> payload ラベル列
    requirements: set[str] = field(default_factory=set)   # protocol 本体の requirement のみ
    methods: dict[str, list[list[tuple[str, bool]]]] = field(default_factory=dict)
    stored: list[tuple[str, bool]] = field(default_factory=list)  # memberwise init 用
    conformances: set[str] = field(default_factory=set)
    initialisers: list[list[tuple[str, bool]]] = field(default_factory=list)  # [(label, has_default)]
    nested: set[str] = field(default_factory=set)
    duplicated: bool = False


# --------------------------------------------------------------------------- 収集


def child(node, *types):
    for item in node.children:
        if item.type in types:
            return item
    return None


def text_of(node, source: bytes) -> str:
    return source[node.start_byte : node.end_byte].decode("utf-8", errors="replace")


def parse_parameters(node, source: bytes) -> list[tuple[str, bool]]:
    """function_declaration / init_declaration の引数ラベル列。

    tree-sitter-swift では既定値は `parameter` ノードの外に `= 値` として並ぶので、
    次の兄弟が `=` かどうかで既定値の有無を判定する。
    """
    parameters: list[tuple[str, bool]] = []
    children = node.children
    for index, item in enumerate(children):
        if item.type != "parameter":
            continue
        raw = text_of(item, source).strip()
        has_default = index + 1 < len(children) and children[index + 1].type == "="
        # `_ x: T` / `label name: T` / `name: T` / 可変長引数
        head = raw.split(":")[0].strip()
        parts = head.split()
        label = parts[0] if parts else ""
        if raw.endswith("...") or "..." in raw:
            has_default = True
        parameters.append((label, has_default))
    return parameters


def payload_labels(raw: str) -> list[str | None]:
    """`(ClockTime, toleranceMinutes: Int)` -> [None, "toleranceMinutes"]"""
    inner = raw.strip()
    if inner.startswith("(") and inner.endswith(")"):
        inner = inner[1:-1]
    labels: list[str | None] = []
    depth = 0
    current = ""
    for character in inner:
        if character in "(<[":
            depth += 1
        elif character in ")>]":
            depth -= 1
        if character == "," and depth == 0:
            labels.append(_label_of(current))
            current = ""
        else:
            current += character
    if current.strip():
        labels.append(_label_of(current))
    return labels


def _label_of(piece: str) -> str | None:
    piece = piece.strip()
    match = re.match(r"([A-Za-z_][A-Za-z0-9_]*)\s*:", piece)
    return match.group(1) if match else None


def collect_body(node, source: bytes, info: TypeInfo, types: dict[str, TypeInfo], path: Path) -> None:
    body = child(node, "class_body", "enum_class_body", "protocol_body")
    if body is None:
        return
    # protocol 本体の宣言だけが「実装しなければならないもの」。
    # `extension P { ... }` はデフォルト実装なので requirement ではない。
    is_protocol_body = body.type == "protocol_body"
    for item in body.children:
        if item.type == "enum_entry":
            name_node = child(item, "simple_identifier")
            if name_node is None:
                continue
            case_name = text_of(name_node, source)
            parameters = child(item, "enum_type_parameters")
            info.enum_cases[case_name] = payload_labels(text_of(parameters, source)) if parameters else []
            info.static_members.add(case_name)
        elif item.type in ("function_declaration", "protocol_function_declaration"):
            name_node = child(item, "simple_identifier")
            if name_node is None:
                continue
            name = text_of(name_node, source)
            modifiers = child(item, "modifiers")
            is_static = modifiers is not None and re.search(r"\b(static|class)\b", text_of(modifiers, source))
            (info.static_members if is_static else info.instance_members).add(name)
            if is_protocol_body:
                info.requirements.add(name)
            info.methods.setdefault(name, []).append(parse_parameters(item, source))
        elif item.type == "init_declaration":
            info.initialisers.append(parse_parameters(item, source))
        elif item.type in ("property_declaration", "protocol_property_declaration"):
            raw = text_of(item, source)
            pattern = child(item, "pattern")
            if pattern is None:
                continue
            # protocol の pattern は `var name` の形。先頭のキーワードだけ落とす。
            # （`Completed` の中の `let` を消すような部分文字列置換は禁物）
            raw_pattern = re.sub(r"^\s*(?:var|let)\s+", "", text_of(pattern, source))
            identifier = re.match(r"\s*([A-Za-z_][A-Za-z0-9_]*)", raw_pattern)
            if identifier is None:
                continue
            name = identifier.group(1)
            is_static = bool(re.match(r"^\s*(?:public |private |internal |fileprivate |open )*(?:static|class)\b", raw))
            (info.static_members if is_static else info.instance_members).add(name)
            if is_protocol_body:
                info.requirements.add(name)

            # メンバーワイズ初期化子の組み立てに使う「格納プロパティ」を順番に控える
            if is_protocol_body or is_static or item.type != "property_declaration":
                continue
            if child(item, "computed_property") is not None:
                continue
            modifiers = child(item, "modifiers")
            modifier_text = text_of(modifiers, source) if modifiers is not None else ""
            if modifier_text.strip().startswith(SUPPLIED_WRAPPERS):
                continue
            has_default = any(sub.type == "=" for sub in item.children)
            is_private = "private" in modifier_text or "fileprivate" in modifier_text
            if is_private and has_default:
                continue
            info.stored.append((name, has_default))
        elif item.type == "class_declaration":
            nested = child(item, "type_identifier")
            if nested is not None:
                nested_name = text_of(nested, source)
                info.nested.add(nested_name)
                info.static_members.add(nested_name)
                register_type(item, source, types, path)
        elif item.type == "typealias_declaration":
            alias = child(item, "type_identifier")
            if alias is not None:
                info.static_members.add(text_of(alias, source))


def register_type(node, source: bytes, types: dict[str, TypeInfo], path: Path) -> None:
    name_node = child(node, "type_identifier")
    if name_node is None:
        return
    name = text_of(name_node, source)
    kind = "protocol" if node.type == "protocol_declaration" else "type"
    for keyword in ("enum", "struct", "class", "actor"):
        if child(node, keyword) is not None:
            kind = keyword
            break

    info = types.get(name)
    if info is None:
        info = TypeInfo(name=name, kind=kind)
        types[name] = info
    elif info.kind != kind and info.kind != "extension":
        info.duplicated = True
    info.files.add(str(path))

    for item in node.children:
        if item.type == "inheritance_specifier":
            info.conformances.add(text_of(item, source).split("<")[0].strip())
        if item.type == "inheritance_specifiers":
            for sub in item.children:
                if sub.type == "inheritance_specifier":
                    info.conformances.add(text_of(sub, source).split("<")[0].strip())

    collect_body(node, source, info, types, path)


def register_extension(node, source: bytes, types: dict[str, TypeInfo], path: Path) -> None:
    name_node = child(node, "user_type", "type_identifier")
    if name_node is None:
        return
    name = text_of(name_node, source).split(".")[0].split("<")[0].strip()
    info = types.setdefault(name, TypeInfo(name=name, kind="extension"))
    info.files.add(str(path))
    for item in node.children:
        if item.type in ("inheritance_specifier", "inheritance_specifiers"):
            for piece in re.split(r"[,\s]+", text_of(item, source)):
                piece = piece.split("<")[0].strip()
                if piece:
                    info.conformances.add(piece)
    collect_body(node, source, info, types, path)


def walk(node, source: bytes, types: dict[str, TypeInfo], path: Path) -> None:
    if node.type in ("class_declaration", "protocol_declaration"):
        # tree-sitter-swift は extension も class_declaration として返す
        if child(node, "extension") is not None:
            register_extension(node, source, types, path)
        else:
            register_type(node, source, types, path)
        return
    if node.type == "extension_declaration":
        register_extension(node, source, types, path)
        return
    for item in node.children:
        walk(item, source, types, path)


# --------------------------------------------------------------------------- 使用箇所


def top_level_arguments(text: str, start: int) -> tuple[list[str | None], int, int]:
    """`(` の次から始めて、トップレベルの引数ラベル列と引数個数、閉じ括弧の位置を返す。"""
    depth = 1
    index = start
    labels: list[str | None] = []
    current = ""
    while index < len(text) and depth > 0:
        character = text[index]
        if character in "([{":
            depth += 1
        elif character in ")]}":
            depth -= 1
            if depth == 0:
                break
        elif character == "," and depth == 1:
            labels.append(_label_of(current))
            current = ""
            index += 1
            continue
        if depth >= 1:
            current += character
        index += 1
    if current.strip():
        labels.append(_label_of(current))
    return labels, len(labels), index


def line_of(text: str, index: int) -> int:
    return text.count("\n", 0, index) + 1


# --------------------------------------------------------------------------- 検査


def check_enum_payloads(files: list[Path], types: dict[str, TypeInfo]) -> list[str]:
    """`.case(...)` の値の個数とラベルを、その case の宣言と突き合わせる。

    同じ case 名を持つ enum が複数あっても、**どの候補とも一致しない** ときだけ
    報告するので誤検知しない（そのぶん一部の誤りは見逃す）。
    値を取らない case は宣言側の候補に入れない（`Skill.clockSet` のような
    同名の単純 case に邪魔されないようにするため）。
    """
    problems: list[str] = []
    case_index: dict[str, list[tuple[str, list[str | None]]]] = {}
    for info in types.values():
        if info.name in SKIPPED_TYPES:
            continue
        for case_name, labels in info.enum_cases.items():
            if not labels:
                continue
            case_index.setdefault(case_name, []).append((info.name, labels))

    for path in files:
        text = path.read_text(encoding="utf-8")
        for match in re.finditer(r"(?<![A-Za-z0-9_])\.([a-z][A-Za-z0-9_]*)\(", text):
            case_name = match.group(1)
            entries = case_index.get(case_name)
            if not entries:
                continue
            labels, arity, _ = top_level_arguments(text, match.end())

            prefix = text[max(0, match.start() - 60) : match.start()]
            is_pattern = bool(re.search(r"\b(case|if case|guard case)\b[^\n]*$", prefix))

            def matches(expected: list[str | None]) -> bool:
                if arity != len(expected):
                    return False
                # パターンマッチではラベルを省略できる
                return is_pattern or labels == expected

            if any(matches(expected) for _, expected in entries):
                continue

            line = line_of(text, match.start())
            shapes = " / ".join(
                f"{name}({len(expected)}個{'' if not any(expected) else ' ' + str(expected)})"
                for name, expected in entries
            )
            problems.append(
                f"{relative(path)}:{line}: .{case_name}(...) が宣言と合いません "
                f"（渡された数: {arity}, ラベル: {[l for l in labels if l]} / 宣言: {shapes}）"
            )
    return problems


def check_static_members(files: list[Path], types: dict[str, TypeInfo]) -> list[str]:
    problems: list[str] = []
    for path in files:
        text = path.read_text(encoding="utf-8")
        for match in re.finditer(r"(?<![A-Za-z0-9_.\\])([A-Z][A-Za-z0-9_]*)\.([A-Za-z_][A-Za-z0-9_]*)", text):
            type_name, member = match.group(1), match.group(2)
            info = types.get(type_name)
            if info is None or info.duplicated or type_name in SKIPPED_TYPES:
                continue
            if info.kind in ("protocol", "extension"):
                continue
            if member in SYNTHESISED_MEMBERS or member in info.static_members:
                continue
            # enum の case は `.name` 形式でも参照されるので既に static_members に入っている
            line = line_of(text, match.start())
            problems.append(
                f"{relative(path)}:{line}: {type_name}.{member} は宣言されていません"
            )
    return problems


def check_protocol_conformance(types: dict[str, TypeInfo]) -> list[str]:
    problems: list[str] = []
    protocols = {name: info for name, info in types.items() if info.kind == "protocol"}
    for name, info in types.items():
        if info.kind in ("protocol", "extension"):
            continue
        satisfied = info.instance_members | info.static_members
        # extension で足されたメンバーも同じ TypeInfo に入っている
        for conformance in info.conformances:
            protocol = protocols.get(conformance)
            if protocol is None:
                continue
            # protocol extension のデフォルト実装は requirement ではない
            required = protocol.requirements
            missing = sorted(required - satisfied)
            if missing:
                problems.append(
                    f"{name} は {conformance} の {', '.join(missing)} を実装していません "
                    f"({', '.join(sorted(info.files))})"
                )
    return problems


def check_initialisers(files: list[Path], types: dict[str, TypeInfo]) -> list[str]:
    problems: list[str] = []
    candidates: dict[str, TypeInfo] = {}
    for name, info in types.items():
        if info.duplicated or name in SKIPPED_TYPES:
            continue
        if info.initialisers:
            candidates[name] = info
        elif info.kind == "struct" and info.stored:
            # 明示的な init が無い struct はメンバーワイズ初期化子が合成される
            synthesised = TypeInfo(name=name, kind=info.kind)
            synthesised.initialisers = [list(info.stored)]
            candidates[name] = synthesised
    for path in files:
        text = path.read_text(encoding="utf-8")
        for name, info in candidates.items():
            for match in re.finditer(rf"(?<![A-Za-z0-9_.]){name}\(", text):
                labels, _, end = top_level_arguments(text, match.end())
                # trailing closure があると省略引数の判定ができない
                trailing = text[end : end + 3]
                for parameters in info.initialisers:
                    known = [label for label, _ in parameters]
                    used = [label for label in labels if label]
                    if any(label not in known for label in used):
                        continue
                    positions = [known.index(label) for label in used]
                    if positions != sorted(positions):
                        continue
                    if "{" not in trailing:
                        required = [
                            label for label, has_default in parameters
                            if not has_default and label not in ("", "_")
                        ]
                        if any(label not in used for label in required):
                            continue
                    break
                else:
                    line = line_of(text, match.start())
                    problems.append(
                        f"{relative(path)}:{line}: {name}(...) がどのイニシャライザとも一致しません "
                        f"（渡されたラベル: {[l for l in labels if l]}）"
                    )
    return problems


def variable_types(text: str) -> dict[str, str]:
    """ファイル内の「変数名 -> 自前の型名」。曖昧なものは落とす。"""
    found: dict[str, set[str]] = {}

    def record(name: str, type_name: str) -> None:
        found.setdefault(name, set()).add(type_name)

    # let/var name: Type  （配列・Optional・ジェネリクスは対象外）
    for match in re.finditer(
        r"\b(?:let|var)\s+([a-z_][A-Za-z0-9_]*)\s*:\s*([A-Z][A-Za-z0-9_]*)\s*(?![?<\[.])",
        text,
    ):
        record(match.group(1), match.group(2))
    # @Environment(T.self) private var name
    for match in re.finditer(
        r"@Environment\(([A-Z][A-Za-z0-9_]*)\.self\)\s*(?:private\s+)?var\s+([a-z_][A-Za-z0-9_]*)",
        text,
    ):
        record(match.group(2), match.group(1))
    # 関数・イニシャライザの引数 name: Type
    for match in re.finditer(
        r"[(,]\s*(?:[a-z_][A-Za-z0-9_]*\s+)?([a-z_][A-Za-z0-9_]*)\s*:\s*([A-Z][A-Za-z0-9_]*)\s*(?![?<\[.])",
        text,
    ):
        record(match.group(1), match.group(2))

    return {name: next(iter(kinds)) for name, kinds in found.items() if len(kinds) == 1}


def check_method_calls(files: list[Path], types: dict[str, TypeInfo]) -> list[str]:
    """レシーバの型が型注釈から確定できる呼び出しだけ、引数ラベルを照合する。

    `foo.bar(...)` の `foo` がそのファイルで 1 つの自前型にしか結び付かないときだけ
    検査するので、標準ライブラリの同名メソッドと取り違えない。
    """
    problems: list[str] = []
    for path in files:
        text = path.read_text(encoding="utf-8")
        bindings = variable_types(text)
        if not bindings:
            continue
        for match in re.finditer(
            r"(?<![A-Za-z0-9_.\\])([A-Za-z_][A-Za-z0-9_]*)\.([a-z_][A-Za-z0-9_]*)\(", text
        ):
            receiver, name = match.group(1), match.group(2)
            if receiver[:1].isupper():
                # `TypeName.staticMethod(...)`
                type_name = receiver if receiver in types else None
                if type_name is not None and name not in types[type_name].static_members:
                    type_name = None
            else:
                type_name = bindings.get(receiver)
            if type_name is None:
                continue
            info = types.get(type_name)
            if info is None or info.duplicated or type_name in SKIPPED_TYPES:
                continue
            overloads = info.methods.get(name)
            if overloads is None or len(overloads) != 1:
                continue
            # enum の case と同名なら、case 生成かもしれないので判定しない
            if name in info.enum_cases:
                continue

            parameters = overloads[0]
            known = [label for label, _ in parameters]
            labels, arity, end = top_level_arguments(text, match.end())
            used = [label for label in labels if label]
            location = f"{relative(path)}:{line_of(text, match.start())}"

            unknown = [label for label in used if label not in known]
            if unknown:
                problems.append(f"{location}: {type_name}.{name}(...) に未知のラベル {unknown}")
                continue
            positions = [known.index(label) for label in used]
            if positions != sorted(positions):
                problems.append(f"{location}: {type_name}.{name}(...) のラベル順が宣言順と違います {used}")
                continue
            if "{" in text[end : end + 3]:
                continue
            required = [
                label for label, has_default in parameters
                if not has_default and label not in ("", "_")
            ]
            missing = [label for label in required if label not in used]
            if missing:
                problems.append(f"{location}: {type_name}.{name}(...) に {missing} がありません")
            # ラベル無しで渡せる引数の上限（既定値の有無は関係ない）
            wildcards = len([label for label, _ in parameters if label in ("", "_")])
            if arity - len(used) > wildcards:
                problems.append(
                    f"{location}: {type_name}.{name}(...) のラベル無し引数が多すぎます"
                )
    return problems


def check_property_access(files: list[Path], types: dict[str, TypeInfo]) -> list[str]:
    """レシーバの型が型注釈から確定できるプロパティアクセスを検査する。"""
    problems: list[str] = []
    for path in files:
        text = path.read_text(encoding="utf-8")
        bindings = variable_types(text)
        if not bindings:
            continue
        for match in re.finditer(
            r"(?<![A-Za-z0-9_.\\])([a-z_][A-Za-z0-9_]*)\??\.([a-z_][A-Za-z0-9_]*)(?![A-Za-z0-9_(])", text
        ):
            receiver, member = match.group(1), match.group(2)
            type_name = bindings.get(receiver)
            if type_name is None:
                continue
            info = types.get(type_name)
            if info is None or info.duplicated or type_name in SKIPPED_TYPES:
                continue
            if member in SYNTHESISED_MEMBERS:
                continue
            if member in info.instance_members or member in info.static_members:
                continue
            if member in info.methods or member in info.enum_cases:
                continue
            problems.append(
                f"{relative(path)}:{line_of(text, match.start())}: "
                f"{type_name}.{member} は宣言されていません"
            )
    return problems


def relative(path: Path) -> str:
    try:
        return str(path.resolve().relative_to(ROOT))
    except ValueError:
        return str(path)


# --------------------------------------------------------------------------- main


def main(argv: list[str]) -> int:
    roots = [Path(a).resolve() for a in argv[1:]] or [ROOT]
    files: list[Path] = []
    for root in roots:
        if root.is_file() and root.suffix == ".swift":
            files.append(root)
        else:
            files.extend(sorted(root.rglob("*.swift")))
    files = [f for f in files if f.name != "Package.swift"]

    parser = Parser(Language(tree_sitter_swift.language()))
    types: dict[str, TypeInfo] = {}
    for path in files:
        source = path.read_bytes()
        walk(parser.parse(source).root_node, source, types, path)

    sections = [
        ("enum の associated value", check_enum_payloads(files, types)),
        ("静的メンバー参照", check_static_members(files, types)),
        ("protocol 準拠", check_protocol_conformance(types)),
        ("イニシャライザ呼び出し", check_initialisers(files, types)),
        ("メソッド呼び出し", check_method_calls(files, types)),
        ("プロパティ参照", check_property_access(files, types)),
    ]

    enum_count = sum(1 for info in types.values() if info.enum_cases)
    protocol_count = sum(1 for info in types.values() if info.kind == "protocol")
    print(
        f"{len(files)} ファイル / 型 {len(types)} 種 "
        f"(enum {enum_count} / protocol {protocol_count})"
    )

    total = 0
    for title, problems in sections:
        unique = sorted(set(problems))
        print(f"\n【{title}】 {len(unique)} 件")
        for problem in unique:
            print("  " + problem)
        total += len(unique)

    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
