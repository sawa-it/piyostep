#!/usr/bin/env python3
"""Keep the illustration catalogue and the asset catalog in sync.

`PiyoStep/DesignSystem/Art/ArtAsset.swift` names every picture the app uses as
`ArtAsset("<key>")`, and `Tools/fetch_art_assets.py` writes one image set per
key into `Assets.xcassets/Art`. A key that exists on only one side would show up
as a blank image at runtime, which no compiler catches. This script fails when:

  1. Swift refers to a key that has no image set (or whose PNGs are missing).
  2. An image set exists that Swift never refers to (dead weight in the bundle).
  3. The fetch script's MANIFEST and the image sets disagree.
  4. The App Icon or the licence text is missing.

Usage: python3 Tools/art_asset_check.py
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SWIFT_CATALOG = ROOT / "PiyoStep/DesignSystem/Art/ArtAsset.swift"
FETCH_SCRIPT = ROOT / "Tools/fetch_art_assets.py"
ART_DIR = ROOT / "PiyoStep/Resources/Assets.xcassets/Art"
APP_ICON = ROOT / "PiyoStep/Resources/Assets.xcassets/AppIcon.appiconset"
LICENSE = ROOT / "PiyoStep/Resources/Credits/FluentEmoji-LICENSE.txt"

problems: list[str] = []

swift_keys = set(re.findall(r'ArtAsset\("([a-z0-9_]+)"\)', SWIFT_CATALOG.read_text()))

manifest_text = FETCH_SCRIPT.read_text()
manifest_body = re.search(r"MANIFEST: dict\[str, str\] = \{(.*?)\n\}", manifest_text, re.S)
manifest_keys = set(re.findall(r'^\s*"([a-z0-9_]+)":', manifest_body.group(1), re.M)) if manifest_body else set()

imageset_keys: set[str] = set()
for folder in sorted(ART_DIR.glob("art.*.imageset")) if ART_DIR.exists() else []:
    key = folder.name[len("art.") : -len(".imageset")]
    imageset_keys.add(key)
    contents_path = folder / "Contents.json"
    if not contents_path.exists():
        problems.append(f"{folder.name}: Contents.json がありません")
        continue
    contents = json.loads(contents_path.read_text())
    scales = set()
    for image in contents.get("images", []):
        filename = image.get("filename")
        if not filename:
            continue
        scales.add(image.get("scale"))
        if not (folder / filename).exists():
            problems.append(f"{folder.name}: {filename} がありません")
    for scale in ("2x", "3x"):
        if scale not in scales:
            problems.append(f"{folder.name}: @{scale} の画像がありません")

for key in sorted(swift_keys - imageset_keys):
    problems.append(f"ArtAsset(\"{key}\") に対応する画像 art.{key}.imageset がありません")
for key in sorted(imageset_keys - swift_keys):
    problems.append(f"art.{key}.imageset は Swift から参照されていません")
for key in sorted(manifest_keys ^ imageset_keys):
    problems.append(f"art.{key}: fetch_art_assets.py の MANIFEST と画像の有無が食い違っています")

if not (APP_ICON / "AppIcon.png").exists():
    problems.append("AppIcon.png がありません（Tools/fetch_art_assets.py を実行してください）")
if not LICENSE.exists():
    problems.append("FluentEmoji-LICENSE.txt がありません")

print(f"ArtAsset: {len(swift_keys)} 個, 画像: {len(imageset_keys)} 個, MANIFEST: {len(manifest_keys)} 個")
if problems:
    print("\n".join(problems))
    sys.exit(1)
print("問題は見つかりませんでした")
