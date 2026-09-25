#!/usr/bin/env python3
"""Fetch the free illustration set and write it into the asset catalog.

The app draws characters, example-word pictures, food, stamps and so on with
Microsoft's Fluent Emoji (MIT License, https://github.com/microsoft/fluentui-emoji).
This script downloads the "Color" SVG of every emoji listed in ``MANIFEST``,
rasterises it at @2x/@3x, and writes one image set per entry into
``PiyoStep/Resources/Assets.xcassets/Art``. It also composes the App Icon.

The rendered PNGs are committed, so the app builds without network access.
Run this again only when adding or changing an entry in ``MANIFEST``.

Usage:
    pip install resvg-py pillow
    python3 Tools/fetch_art_assets.py            # everything
    python3 Tools/fetch_art_assets.py chick bear # only these keys

Every image set is named ``art.<key>``; ``PiyoStep/DesignSystem/Art/ArtAsset.swift``
refers to them by that name and ``Tools/art_asset_check.py`` keeps both in sync.
"""

from __future__ import annotations

import io
import json
import sys
import urllib.parse
import urllib.request
from pathlib import Path

try:
    import resvg_py
    from PIL import Image, ImageDraw, ImageFilter
except ImportError:  # pragma: no cover - guidance only
    sys.exit("pip install resvg-py pillow を先に実行してください")

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "PiyoStep/Resources/Assets.xcassets"
ART_DIR = CATALOG / "Art"
ICON_DIR = CATALOG / "AppIcon.appiconset"
LICENSE_PATH = ROOT / "PiyoStep/Resources/Credits/FluentEmoji-LICENSE.txt"

# 固定したリビジョン。素材が差し替わって見た目が変わらないようにする。
UPSTREAM = "https://raw.githubusercontent.com/microsoft/fluentui-emoji/main"

# 描画するポイント数。通常は 128pt、キャラクターと主役級は 180pt で描く。
# iOS 17 が動く端末は @2x か @3x なので @1x は作らない。
BASE_POINTS = 128
LARGE_POINTS = 180
LARGE_KEYS = {
    "chick", "bear", "cat", "rabbit", "penguin", "trex",
    "gift", "trophy", "party_popper", "sparkles", "glowing_star",
}

# key -> Fluent Emoji のフォルダ名（CLDR 名）。
MANIFEST: dict[str, str] = {
    # なかま（キャラクター）
    "chick": "Front-facing baby chick",
    "bear": "Bear",
    "cat": "Cat face",
    "rabbit": "Rabbit face",
    "penguin": "Penguin",
    "trex": "T-rex",
    # きせかえ
    "cap": "Billed cap",
    "ribbon": "Ribbon",
    "crown": "Crown",
    "glasses": "Glasses",
    "scarf": "Scarf",
    # おさら・もよう
    "plate": "Fork and knife with plate",
    "cherry_blossom": "Cherry blossom",
    "star": "Star",
    "rainbow": "Rainbow",
    # はいけい
    "sun_cloud": "Sun behind small cloud",
    "tree": "Deciduous tree",
    "wave": "Water wave",
    "planet": "Ringed planet",
    "rocket": "Rocket",
    "moon": "Crescent moon",
    "sun": "Sun",
    "snowflake": "Snowflake",
    # スタンプ・ごほうび
    "glowing_star": "Glowing star",
    "sparkling_heart": "Sparkling heart",
    "medal": "Sports medal",
    "trophy": "Trophy",
    "gift": "Wrapped gift",
    "sparkles": "Sparkles",
    "sparkle": "Sparkle",
    "party_popper": "Party popper",
    "confetti_ball": "Confetti ball",
    "balloon": "Balloon",
    "hundred": "Hundred points",
    # キャラクターの気持ち
    "thought_balloon": "Thought balloon",
    "zzz": "Zzz",
    "question": "Red question mark",
    "two_hearts": "Two hearts",
    "musical_notes": "Musical notes",
    "ear": "Ear",
    # たべもの
    "rice_ball": "Rice ball",
    "pancakes": "Pancakes",
    "fish": "Fish",
    "carrot": "Carrot",
    "pot": "Pot of food",
    "rice": "Cooked rice",
    "bread": "Bread",
    "watermelon": "Watermelon",
    "eggplant": "Eggplant",
    "tangerine": "Tangerine",
    "peach": "Peach",
    "broccoli": "Broccoli",
    "apple": "Red apple",
    "ice_cream": "Soft ice cream",
    "shortcake": "Shortcake",
    "cheese": "Cheese wedge",
    "noodle": "Steaming bowl",
    "milk": "Glass of milk",
    "lemon": "Lemon",
    "tomato": "Tomato",
    "rice_cracker": "Rice cracker",
    "egg": "Egg",
    "grapes": "Grapes",
    "juice": "Cup with straw",
    "candy": "Candy",
    "ice": "Ice",
    "shrimp": "Shrimp",
    "beans": "Beans",
    # どうぶつ・むし
    "duck": "Duck",
    "dog": "Dog face",
    "horse": "Horse face",
    "giraffe": "Giraffe",
    "bug": "Bug",
    "zebra": "Zebra",
    "butterfly": "Butterfly",
    "snake": "Snake",
    "lady_beetle": "Lady beetle",
    "lion": "Lion",
    "crocodile": "Crocodile",
    "turtle": "Turtle",
    "koala": "Koala",
    "chicken": "Chicken",
    "octopus": "Octopus",
    "bird": "Bird",
    "pig": "Pig face",
    "teddy": "Teddy bear",
    "cricket": "Cricket",
    "honeybee": "Honeybee",
    "snail": "Snail",
    "frog": "Frog",
    "sunflower": "Sunflower",
    # ひと
    "woman": "Woman",
    "man": "Man",
    "princess": "Princess",
    "nose": "Nose",
    "child": "Child",
    # もの
    "pencil": "Pencil",
    "umbrella": "Umbrella",
    "sled": "Sled",
    "drum": "Drum",
    "gloves": "Gloves",
    "clock": "Alarm clock",
    "bus": "Bus",
    "tulip": "Tulip",
    "airplane": "Airplane",
    "ship": "Ship",
    "tshirt": "T-shirt",
    "house": "House",
    "locomotive": "Locomotive",
    "candle": "Candle",
    "running_shoe": "Running shoe",
    "couch": "Couch and lamp",
    "christmas_tree": "Christmas tree",
    "television": "Television",
    "knife": "Kitchen knife",
    "notebook": "Notebook",
    "scissors": "Scissors",
    "helicopter": "Helicopter",
    "microphone": "Microphone",
    "sailboat": "Sailboat",
    "magnifier": "Magnifying glass tilted left",
    "key": "Key",
    "package": "Package",
    "soccer_ball": "Soccer ball",
    "top_hat": "Top hat",
    "minibus": "Minibus",
    "droplet": "Droplet",
    "automobile": "Automobile",
    "red_heart": "Red heart",
    "blue_heart": "Blue heart",
    "green_heart": "Green heart",
    "yellow_heart": "Yellow heart",
    # 画面のアイコン
    "books": "Books",
    "open_book": "Open book",
    "bookmark_tabs": "Bookmark tabs",
    "input_numbers": "Input numbers",
    "input_latin": "Input latin uppercase",
    "globe": "Globe showing asia-australia",
    "light_bulb": "Light bulb",
    "speaker": "Speaker high volume",
    "locked": "Locked",
    "flag": "Chequered flag",
    "stopwatch": "Stopwatch",
    "timer": "Timer clock",
    "framed_picture": "Framed picture",
    "crayon": "Crayon",
}

# Fluent 側で肌の色の既定値を持つもの（Default フォルダの下にある）。
SKIN_TONE_KEYS = {"ear", "woman", "man", "princess", "nose", "child"}


def fluent_urls(name: str, key: str) -> list[str]:
    file_stem = name.lower().replace(" ", "_").replace("’", "")
    folder = urllib.parse.quote(name)
    plain = f"{UPSTREAM}/assets/{folder}/Color/{file_stem}_color.svg"
    default = f"{UPSTREAM}/assets/{folder}/Default/Color/{file_stem}_color_default.svg"
    return [default, plain] if key in SKIN_TONE_KEYS else [plain, default]


def fetch(url: str) -> bytes | None:
    try:
        with urllib.request.urlopen(url, timeout=30) as response:
            return response.read()
    except Exception:
        return None


def fetch_svg(key: str, name: str) -> str:
    for url in fluent_urls(name, key):
        data = fetch(url)
        if data:
            return data.decode("utf-8")
    raise SystemExit(f"{key}: Fluent Emoji「{name}」が見つかりません")


def render(svg: str, size: int) -> Image.Image:
    png = resvg_py.svg_to_bytes(svg_string=svg, width=size, height=size)
    return Image.open(io.BytesIO(png)).convert("RGBA")


def write_imageset(key: str, svg: str) -> None:
    points = LARGE_POINTS if key in LARGE_KEYS else BASE_POINTS
    folder = ART_DIR / f"art.{key}.imageset"
    folder.mkdir(parents=True, exist_ok=True)
    images = []
    for scale in (2, 3):
        filename = f"{key}@{scale}x.png"
        render(svg, points * scale).save(folder / filename, optimize=True)
        images.append({"filename": filename, "idiom": "universal", "scale": f"{scale}x"})
    contents = {"images": images, "info": {"author": "xcode", "version": 1}}
    (folder / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")


def write_app_icon(chick_svg: str) -> None:
    """あたたかいオレンジの背景に、ぴよちゃんを大きく置く。"""
    size = 1024
    icon = Image.new("RGBA", (size, size), (255, 158, 74, 255))
    # 上を明るく、下を濃くする縦のグラデーション。
    gradient = Image.new("RGBA", (1, size))
    top, bottom = (255, 205, 92), (255, 132, 64)
    for y in range(size):
        t = y / (size - 1)
        gradient.putpixel((0, y), tuple(int(top[i] * (1 - t) + bottom[i] * t) for i in range(3)) + (255,))
    icon.alpha_composite(gradient.resize((size, size)))
    # やわらかい光の丸。
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((size * 0.12, size * 0.02, size * 0.88, size * 0.62), fill=(255, 255, 255, 90))
    icon.alpha_composite(glow.filter(ImageFilter.GaussianBlur(size * 0.12)))
    # 足元の影。
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse((size * 0.24, size * 0.76, size * 0.76, size * 0.90), fill=(150, 70, 20, 110))
    icon.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(size * 0.03)))
    chick = render(chick_svg, int(size * 0.74))
    icon.alpha_composite(chick, (int((size - chick.width) / 2), int(size * 0.13)))
    ICON_DIR.mkdir(parents=True, exist_ok=True)
    icon.convert("RGB").save(ICON_DIR / "AppIcon.png", optimize=True)
    contents = {
        "images": [{"filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
        "info": {"author": "xcode", "version": 1},
    }
    (ICON_DIR / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")


def write_license() -> None:
    text = fetch(f"{UPSTREAM}/LICENSE")
    if not text:
        raise SystemExit("LICENSE を取得できません")
    LICENSE_PATH.parent.mkdir(parents=True, exist_ok=True)
    header = (
        "Fluent Emoji by Microsoft\n"
        "https://github.com/microsoft/fluentui-emoji\n"
        "このアプリのイラスト（キャラクター・ことばの絵・たべもの・スタンプなど）は\n"
        "Fluent Emoji の Color 版を PNG に描き出して使っています。\n\n"
    )
    LICENSE_PATH.write_text(header + text.decode("utf-8").strip() + "\n")


def main(argv: list[str]) -> int:
    keys = argv or list(MANIFEST)
    unknown = [key for key in keys if key not in MANIFEST]
    if unknown:
        raise SystemExit(f"MANIFEST に無いキー: {', '.join(unknown)}")
    ART_DIR.mkdir(parents=True, exist_ok=True)
    (ART_DIR / "Contents.json").write_text(
        json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n"
    )
    for index, key in enumerate(keys, start=1):
        svg = fetch_svg(key, MANIFEST[key])
        write_imageset(key, svg)
        print(f"[{index}/{len(keys)}] art.{key} <- {MANIFEST[key]}")
    if "chick" in keys:
        write_app_icon(fetch_svg("chick", MANIFEST["chick"]))
        print("AppIcon.png")
    write_license()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
