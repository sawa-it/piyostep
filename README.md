# ぴよステップ（PiyoStep）

3〜6歳の日本人の未就学児向け iOS 学習アプリ。
**「子どもが自分から毎日さわりたくなること」** を最優先に設計しています。

- とけい（時刻を読む／針を合わせる）
- ひらがな・カタカナ（読み・なぞり書き・自由書き・ことばあわせ）
- すうじ（かぞえる・数字を読む・一/十/百の位）
- アルファベット・超基本英単語
- **キャラクターと競争するご飯タイマー**
- 音声入力での回答（日本語／英語）
- ずかん・スタンプ・きせかえのアンロック
- 保護者向けの習熟度ダッシュボードと設定（ペアレンタルゲート付き）

設計の詳細は [`docs/DESIGN.md`](docs/DESIGN.md) にまとめています。

---

## 構成

```
PiyoStep.xcodeproj          Xcode 16 形式（フォルダ同期グループ）
project.yml                 XcodeGen 用スペック（プロジェクト再生成用の予備）
Packages/PiyoCore/          ★ 純粋ロジック（Foundation のみ・UI/OS 非依存）
  Sources/PiyoCore/         出題・判定・習熟度・難易度・チャレンジ選定・ご飯タイマー
  Tests/PiyoCoreTests/      Unit Test（Xcode が無くても `swift test` で実行可能）
PiyoStep/                   アプリ本体（SwiftUI）
  App/                      エントリポイント・DI コンテナ・起動引数
  DesignSystem/             色・タイポ・大ボタン・コード描画のイラスト・演出
  Services/                 Speech / AVFoundation / SwiftData / StoreKit / 広告
  ViewModels/               画面ごとの ViewModel
  Features/                 画面
PiyoStepTests/              アプリ層の Unit Test（モック注入）
PiyoStepUITests/            XCUITest（主要導線）
Tools/                      Swift ツールチェーンが無い環境向けの静的チェック
```

### イラストについて

画像アセットを一切持たず、キャラクター・動物・食べ物・お皿・時計はすべて
SwiftUI の `Shape` / `Path` によるコード描画と SF Symbols で表現しています。
リポジトリがテキストだけで完結し、差分レビューも容易です。

---

## ビルドと実行

### 必要なもの

- Xcode 16 以降（iOS 17.0 以上）
- 実機での音声入力テストには、マイクと音声認識の許可が必要です

### Xcode で開く

```bash
open PiyoStep.xcodeproj
```

`PiyoStep` スキームを選び、iPhone シミュレータで実行してください。

### コマンドラインから

```bash
# アプリ本体のビルド
xcodebuild build \
  -project PiyoStep.xcodeproj \
  -scheme PiyoStep \
  -destination 'platform=iOS Simulator,name=iPhone 16'

# Unit Test + UI Test
xcodebuild test \
  -project PiyoStep.xcodeproj \
  -scheme PiyoStep \
  -destination 'platform=iOS Simulator,name=iPhone 16'

# ドメインロジックだけなら Xcode 無しでも実行できます
cd Packages/PiyoCore && swift test
```

---

## テスト

| 層 | 場所 | 内容 |
| --- | --- | --- |
| ドメインロジック | `Packages/PiyoCore/Tests/PiyoCoreTests` | 問題生成・正誤判定・音声認識結果の正規化・習熟度・難易度自動調整・今日のチャレンジ選定・ご飯タイマー進行・アンロック条件・設定の保存/読込 |
| ViewModel・サービス | `PiyoStepTests` | セッション進行、音声回答（モック認識）、ご飯タイマー、保護者ゲート、設定、SwiftData 永続化、広告の抑止 |
| 主要導線 | `PiyoStepUITests` | 起動・プロフィール作成・ホーム・今日のチャレンジ・時計/数字/ひらがな・なぞり書き・音声回答・ご飯タイマー・保護者画面・設定変更 |

### UI テストの決定性

アプリは起動引数を解釈します。

| 引数 | 効果 |
| --- | --- |
| `-uiTestMode 1` | インメモリ永続化・広告無効・アニメーション短縮・モック音声認識 |
| `-uiTestProfile <name>` | プロフィールを自動作成してオンボーディングを飛ばす |
| `-uiTestProfileAge <n>` | 自動作成するプロフィールの年齢 |
| `-uiTestFreshInstall 1` | プロフィール未作成状態から始める |
| `-uiTestSeed <n>` | 問題生成の乱数シードを固定 |
| `-uiTestVoiceScript <text>` | モック音声認識が返す文字列 |
| `-uiTestMealSeconds <n>` | ご飯タイマーの時間を秒で上書き |

### Swift ツールチェーンが無い環境での確認

```bash
python3 Tools/swift_sanity.py Packages PiyoStep PiyoStepTests PiyoStepUITests
python3 Tools/symbol_check.py
python3 Tools/view_init_check.py
```

- `swift_sanity.py`: 括弧・文字列・ブロックコメントの対応、`Set<Character>` リテラル、
  トップレベル型名の重複
- `symbol_check.py`: `A11yID` / `PiyoTheme` の参照、PiyoCore の公開範囲、
  `Skill` / `Subject` の網羅的 switch
- `view_init_check.py`: SwiftUI View のメンバーワイズ初期化子と呼び出し側の
  ラベル・順序・必須引数の整合

コンパイラの代わりにはなりませんが、ツールチェーンが無い環境でも
機械的に検出できる誤りを潰せます。

---

## 設計上の約束

- **ネガティブ演出をしない。** 「まちがい」「おそい」「じかんぎれ」「まけ」は使いません。
  ご飯タイマーでキャラクターが先に食べ終わっても、応援に切り替わります。
- **音声認識の失敗を不正解にしない。** 聞き取れなかった場合は `.unclear` として
  学習履歴にも習熟度にも影響させず、「もういちど いってみよう！」と誘導します。
  3 回続いたらタップ回答をすすめます。
- **音声データを外部に送らない。** iOS 標準の Speech framework のみを使い、
  アプリ独自の保存・送信は行いません。
- **広告は起動時だけ。** 学習中・ご飯タイマー中は `AdPresenting` が必ず false を返します。
  誤タップ防止のため、閉じるボタンは 3 秒後に有効になります。
- **ガチャ・課金煽り・強いストリークプレッシャーを作らない。**
  アンロックはすべて「やれば必ず届く」条件です。
- **タップ領域は最低 88pt。** 文字が読めなくても、イラストと音声で次の操作が分かります。

---

## 将来の拡張

- **iCloud 同期**: SwiftData のエンティティはすべてデフォルト値を持ち、リレーションを
  張らない設計にしてあるため、`ModelConfiguration(cloudKitDatabase:)` の切り替えだけで対応できます。
- **実広告 SDK**: `AdPresenting` の実装と `LaunchAdView` の中身を差し替えるだけです。
- **教材の追加**: `KanaCatalog` / `EnglishWordCatalog` / `UnlockCatalog` にデータを足すだけで、
  出題・アンロック・図鑑に反映されます。
- **パッケージのリンク形態**: `PiyoCore` を複数ターゲットがリンクしています。
  リンク時の重複が気になる場合は `Packages/PiyoCore/Package.swift` の product を
  `type: .dynamic` に変更してください。
