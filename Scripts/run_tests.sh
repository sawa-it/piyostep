#!/usr/bin/env bash
#
# ぴよステップのビルドとテストをまとめて実行する。
#
#   ./Scripts/run_tests.sh              すべて（PiyoCore → ビルド → Unit → UI）
#   ./Scripts/run_tests.sh core         PiyoCore のテストだけ（Xcode 不要）
#   ./Scripts/run_tests.sh build        アプリ本体のビルドだけ
#   ./Scripts/run_tests.sh unit         アプリ層の Unit Test だけ
#   ./Scripts/run_tests.sh ui           UI Test だけ
#
# 使うシミュレータは自動で選びます。指定したいときは環境変数で:
#   PIYO_DESTINATION='platform=iOS Simulator,name=iPhone 16' ./Scripts/run_tests.sh
#
set -euo pipefail

cd "$(dirname "$0")/.."

STAGE="${1:-all}"
PROJECT="PiyoStep.xcodeproj"
SCHEME="PiyoStep"

log() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

require() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "エラー: $1 が見つかりません。$2" >&2
        exit 1
    fi
}

run_core_tests() {
    require swift "Swift 5.9 以降のツールチェーンが必要です（macOS なら Xcode に同梱）。"
    log "PiyoCore（ドメインロジック）の Unit Test"
    swift test --package-path Packages/PiyoCore
}

# 利用できる iPhone シミュレータのうち、いちばん新しい iOS ランタイムのものを選ぶ。
resolve_destination() {
    if [[ -n "${PIYO_DESTINATION:-}" ]]; then
        printf '%s' "$PIYO_DESTINATION"
        return
    fi
    xcrun simctl list devices available --json | python3 -c '
import json, sys

data = json.load(sys.stdin)["devices"]
best = None
for runtime, devices in data.items():
    if "iOS" not in runtime:
        continue
    for device in devices:
        if not device.get("isAvailable"):
            continue
        if not device["name"].startswith("iPhone"):
            continue
        key = (runtime, device["name"])
        if best is None or key > best[0]:
            best = (key, device["udid"])

if best is None:
    sys.exit("利用できる iPhone シミュレータが見つかりません。Xcode の Settings → Platforms から iOS シミュレータを入れてください。")
print(f"platform=iOS Simulator,id={best[1]}")
'
}

xcode_run() {
    local action="$1"; shift
    xcodebuild "$action" \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination "$DESTINATION" \
        CODE_SIGNING_ALLOWED=NO \
        "$@"
}

if [[ "$STAGE" == "core" ]]; then
    run_core_tests
    exit 0
fi

require xcodebuild "macOS 上の Xcode 16 以降が必要です（Linux では実行できません）。"

log "Xcode"
xcodebuild -version

DESTINATION="$(resolve_destination)"
log "使用するシミュレータ: $DESTINATION"

case "$STAGE" in
    all)
        run_core_tests
        log "アプリ本体のビルド"
        xcode_run build
        log "アプリ層の Unit Test"
        xcode_run test -only-testing:PiyoStepTests
        log "UI Test"
        xcode_run test -only-testing:PiyoStepUITests
        ;;
    build)
        log "アプリ本体のビルド"
        xcode_run build
        ;;
    unit)
        log "アプリ層の Unit Test"
        xcode_run test -only-testing:PiyoStepTests
        ;;
    ui)
        log "UI Test"
        xcode_run test -only-testing:PiyoStepUITests
        ;;
    *)
        echo "不明な引数: $STAGE（all / core / build / unit / ui）" >&2
        exit 2
        ;;
esac

log "完了"
