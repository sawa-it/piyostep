#!/usr/bin/env bash
#
# コマンドを実行し、失敗したらエラー行を GitHub Actions の annotation として出す。
#
# Actions のログ本体はブロブストレージにあり、環境によっては取得できない。
# annotation は REST API（check-runs/{id}/annotations）から読めるので、
# コンパイルエラーやテスト失敗をそこに載せておく。
#
#   ./Scripts/ci_step.sh "ラベル" コマンド [引数...]
#
set -uo pipefail

LABEL="$1"
shift

LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT

set -o pipefail
"$@" 2>&1 | tee "$LOG"
STATUS=${PIPESTATUS[0]}

if [[ $STATUS -eq 0 ]]; then
    exit 0
fi

emit() {
    # annotation は 1 行ずつ。長すぎる行は切り詰める。
    local line="${1:0:900}"
    # GitHub のワークフローコマンドを壊さないようにエスケープ
    line="${line//$'\r'/}"
    line="${line//%/%25}"
    printf '::error::[%s] %s\n' "$LABEL" "$line"
}

echo "::group::$LABEL の失敗内容"

# 1) コンパイルエラー・テスト失敗
FOUND=0
while IFS= read -r line; do
    emit "$line"
    FOUND=1
done < <(grep -E "error:|error: " "$LOG" | sed 's/^[[:space:]]*//' | sort -u | head -40)

# 2) XCTest の失敗サマリー
while IFS= read -r line; do
    emit "$line"
    FOUND=1
done < <(grep -E "^(Testing failed|.*failed \([0-9.]+ seconds\)|\*\* (TEST|BUILD) FAILED \*\*)" "$LOG" \
         | sed 's/^[[:space:]]*//' | sort -u | head -20)

# 3) 何も拾えなければ末尾をそのまま出す
if [[ $FOUND -eq 0 ]]; then
    while IFS= read -r line; do
        [[ -z "${line// /}" ]] && continue
        emit "$line"
    done < <(tail -30 "$LOG")
fi

echo "::endgroup::"
exit "$STATUS"
