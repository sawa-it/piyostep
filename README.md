# ぴよステップ（PiyoStep）

3〜6歳の日本人の未就学児向け iOS 学習アプリ。
**「子どもが自分から毎日さわりたくなること」** を最優先に設計しています。

- とけい（時刻を読む／針を合わせる）
- ひらがな・カタカナ（読み・なぞり書き・自由書き・ことばあわせ）
- すうじ（かぞえる・数字を読む・一/十/百の位）
- アルファベット・超基本英単語
- **キャラクターと競争するご飯タイマー**
- 声で答える（日本語／英語）。**マイクは押さない。** 問いかけを読み終えると勝手に聞き始める
- ずかん・スタンプ・きせかえのアンロック
- **アプリの呼び名とアイコンのカスタマイズ**（「たろうの アプリ」＋その子の写真）
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

シミュレータの自動選択まで含めたスクリプトを用意しています。

```bash
./Scripts/run_tests.sh          # PiyoCore → ビルド → Unit Test → UI Test
./Scripts/run_tests.sh core     # PiyoCore のテストだけ（Xcode 不要）
./Scripts/run_tests.sh build    # アプリ本体のビルドだけ
./Scripts/run_tests.sh unit     # アプリ層の Unit Test だけ
./Scripts/run_tests.sh ui       # UI Test だけ
```

シミュレータを指定したい場合:

```bash
PIYO_DESTINATION='platform=iOS Simulator,name=iPhone 16' ./Scripts/run_tests.sh
```

素の xcodebuild を使う場合:

```bash
xcodebuild build \
  -project PiyoStep.xcodeproj -scheme PiyoStep \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO

xcodebuild test \
  -project PiyoStep.xcodeproj -scheme PiyoStep \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO

# ドメインロジックだけなら Xcode 無しでも実行できます
swift test --package-path Packages/PiyoCore
```

### CI

`.github/workflows/ci.yml` で、push のたびに次が走ります。

| ジョブ | ランナー | 内容 |
| --- | --- | --- |
| 静的チェック | ubuntu-latest | `Tools/` の 6 種のチェック（ツールチェーン不要） |
| PiyoCore の Unit Test | macos-15 | `swift test` |
| アプリのビルドと Unit / UI Test | macos-15 | `Scripts/run_tests.sh` |

---

## テスト

| 層 | 場所 | 内容 |
| --- | --- | --- |
| ドメインロジック | `Packages/PiyoCore/Tests/PiyoCoreTests` | 問題生成・正誤判定・音声認識結果の正規化・習熟度・難易度自動調整・今日のチャレンジ選定・ご飯タイマー進行・アンロック条件・設定の保存/読込 |
| ViewModel・サービス | `PiyoStepTests` | セッション進行、音声回答（モック認識）、ご飯タイマー、保護者ゲート、設定、SwiftData 永続化、広告の抑止（保護者画面に入るときだけ出す）|
| 主要導線 | `PiyoStepUITests` | 起動・プロフィール作成・ホーム・今日のチャレンジ・時計/数字/ひらがな・なぞり書き・音声回答・ご飯タイマー・保護者画面・設定変更 |

### UI テストの決定性

アプリは起動引数を解釈します。

| 引数 | 効果 |
| --- | --- |
| `-uiTestMode 1` | インメモリ永続化・広告無効・アニメーション短縮・モック音声認識・正解後の自動「つぎへ」を無効化（押す導線を検証するため） |
| `-uiTestProfile <name>` | プロフィールを自動作成してオンボーディングを飛ばす |
| `-uiTestProfileAge <n>` | 自動作成するプロフィールの年齢 |
| `-uiTestFreshInstall 1` | プロフィール未作成状態から始める |
| `-uiTestSeed <n>` | 問題生成の乱数シードを固定 |
| `-uiTestVoiceScript <text>` | モック音声認識が返す文字列 |
| `-uiTestMealSeconds <n>` | ご飯タイマーの時間を秒で上書き |

### Swift ツールチェーンが無い環境での確認

```bash
pip install tree_sitter tree_sitter_swift   # 構文解析に使うもののみ

python3 Tools/swift_parse_check.py      Packages PiyoStep PiyoStepTests PiyoStepUITests
python3 Tools/type_check.py             Packages PiyoStep PiyoStepTests PiyoStepUITests
python3 Tools/switch_exhaustive_check.py Packages PiyoStep PiyoStepTests PiyoStepUITests
python3 Tools/swift_sanity.py           Packages PiyoStep PiyoStepTests PiyoStepUITests
python3 Tools/symbol_check.py
python3 Tools/view_init_check.py
```

- `swift_parse_check.py`: tree-sitter の Swift 文法で全ファイルを構文解析
- `type_check.py`: 宣言と使用箇所を突き合わせて、型エラーになりやすい 6 クラスを検査
  （enum の associated value / 静的メンバー参照 / protocol 準拠 /
  イニシャライザ呼び出し（メンバーワイズ含む）/ メソッド呼び出し / プロパティ参照）
- `switch_exhaustive_check.py`: `default` の無い `switch` が列挙を網羅しているか
- `swift_sanity.py`: 括弧・文字列・ブロックコメントの対応、`Set<Character>` リテラル、
  トップレベル型名の重複
- `symbol_check.py`: `A11yID` / `PiyoTheme` の参照、PiyoCore の公開範囲、
  `Skill` / `Subject` の網羅的 switch
- `view_init_check.py`: SwiftUI View のメンバーワイズ初期化子と呼び出し側の
  ラベル・順序・必須引数の整合

### 検出力について

`type_check.py` は、故意にコードを壊して検出できるかを確かめてあります
（ラベル間違い・引数の過不足・順序入れ替え・綴り間違い・requirement 未実装など
13 パターンすべて検出）。ただし **型推論が要るものは原理的に検出できません**。

| 検出できる | 検出できない |
| --- | --- |
| 引数ラベル・順序・過不足（init / メソッド / メンバーワイズ） | 式の型不一致（`Int` と `String` など） |
| enum の associated value の個数・ラベル | Optional のアンラップ漏れ |
| 未宣言のメンバー参照（型が型注釈から分かる場合） | ジェネリック制約違反（`Identifiable` 等の欠如） |
| protocol の requirement 未実装 | SwiftUI / SDK 側 API のシグネチャ違い |
| `switch` の網羅漏れ | クロージャの戻り値型推論の失敗 |

Xcode でのビルドの代わりにはなりません。実機・シミュレータでの
`xcodebuild build` と `xcodebuild test` は必ず実行してください。

---

## 設計上の約束

- **ネガティブ演出をしない。** 「まちがい」「おそい」「じかんぎれ」「まけ」は使いません。
  ご飯タイマーでキャラクターが先に食べ終わっても、応援に切り替わります。
- **音声認識の失敗を不正解にしない。** 聞き取れなかった場合は `.unclear` として
  学習履歴にも習熟度にも影響させず、「もういちど いってみよう！」と誘導します。
  3 回続いたらタップ回答をすすめます。
- **音声データを外部に送らない。** iOS 標準の Speech framework のみを使い、
  端末内で認識できる端末・言語では `requiresOnDeviceRecognition` を立てて端末の外に出しません。
  アプリ独自の保存・送信は行いません。
- **アイコンの写真も端末から出さない。** 選んだ写真は正方形に切り抜いて 512px の JPEG に
  縮めたうえで `Documents/ProfileImages` に置くだけで、送信も同期も行いません。
- **広告は保護者画面に入るときだけ。** 子どもの画面には一切出ません。
  ペアレンタルゲートの向こう側でしか表示されないので、広告を見るのは必ず大人です。
  起動時に出すと、アプリを初めて開いた子どもが最初に見るものが広告になってしまいます。
  同じ起動では 1 回だけ、誤タップ防止のため閉じるボタンは 3 秒後に有効になります。
- **ガチャ・課金煽り・強いストリークプレッシャーを作らない。**
  アンロックはすべて「やれば必ず届く」条件です。
- **タップ領域は最低 88pt。** 文字が読めなくても、イラストと音声で次の操作が分かります。
- **答え方を切り替えさせない。** 3〜6歳に「えらぶ／すうじ／こえ」の切り替えは無理です。
  タップの手段は問題ごとに 1 つに決め、声はその横で勝手に聞いています
  （問いかけを読み終えたら聞き取り開始。マイクを押すのは、聞き取りが止まったあとだけ）。
  「もじを みて よむ」問題だけは、答えになる選択肢を隠して声を待ち、
  黙ったままなら自動でタップに切り替えます。
- **数字を自由に入力させない。** 「40じ」のような時刻が入れられてしまうので、数字パッドは置きません。
  時刻も数も、選択肢と声で答えます。
- **音は順番に鳴らす。** 効果音 → 読み上げ → 聞き取り、の順で、重ねません。
  読み上げが終わる前にマイクを開くと、アプリが自分の声を聞き取ってしまいます。
- **正解したら押さなくても進む。** 「つぎへ」は残しますが、読み上げが終われば自動で次の問題へ。
  なぞり書きも、十分なぞれた時点で「できた！」を待たずに進みます。
- **やめる確認は絵で。** システムのダイアログは文字だけなので、キャラクターと絵つきの大きな 2 択にしています。

---

## 画面の向きとレイアウト

**iPhone・iPad とも横向きで使う前提**です。両方のターゲットを
`UIInterfaceOrientationLandscapeLeft / LandscapeRight` に固定してあります。
持ち替えても画面の作りが変わらないほうが、3〜6歳には分かりやすいためです。

寸法は端末名ではなく **いま与えられている幅と高さ** から決めます
（`PiyoCore/UI/LayoutMetrics.swift`）。iPad の Split View では iPad でも細くなるので、
端末では判断できません。

| 形 | 例 | 組み方 |
|---|---|---|
| `compactWide` | iPhone 横（852 × 393） | 左右 2 分割、絵は 0.72 倍に縮めて高さに収める |
| `wide` | iPad 横（1180 × 820） | 左右 2 分割、絵と文字を 1.25〜1.3 倍に拡大、教科は 3 列 |
| `regular` | iPad の分割表示 | 縦積み、1.2 倍 |
| `compact` | iPhone 縦（将来、縦を解禁した場合） | 縦積み、等倍 |

横向きでは、ホーム・学習・結果・保護者ゲートを**左右 2 列**に組み替えます。
縦に積むと、高さ 390pt の iPhone 横持ちで回答ボタンが画面の外に出てしまうためです。

文字は `.piyoFont(.title)` のように役割で指定し、大きさは `LayoutMetrics` が決めます。
固定サイズの `Font` を置くと iPad で小さいままになるので、`PiyoTheme` には置いていません。
タップ領域は、倍率が 1 未満の画面でも **88pt を下回りません**（指の大きさは変わらないため）。

CI は **iPhone と iPad の両方**で UI テストを走らせます
（`PIYO_DEVICE=iPad ./Scripts/run_tests.sh ui` でローカルでも切り替えられます）。

---

## アプリの呼び名とアイコン

保護者設定の「アプリの みため」から変更できます。

- **呼び名**: アプリの中のホーム画面に出る名前（最大 12 文字）。子どもの名前から
  「たろうの アプリ」という候補を出すので、1 タップで決められます。
- **アイコン**: 写真ライブラリから選んだ写真か、相棒キャラクターの絵。
  写真は `PhotosPicker`（PHPicker）で選ぶため、写真ライブラリへのアクセス許可は不要です。

**iPhone のホーム画面に並ぶアプリ名とアイコンは変更できません。** これは iOS の制約です。

- アプリ名（`CFBundleDisplayName`）はビルド時に固定で、実行中に変更する API がありません
- アイコンは `UIApplication.setAlternateIconName(_:)` で切り替えられますが、
  **あらかじめアプリに同梱したアイコンの中からしか選べません**（任意の写真は使えません）。
  候補アイコンを用意すれば対応できるので、必要になったら追加してください。

---

## 将来の拡張

- **iCloud 同期**: SwiftData のエンティティはすべてデフォルト値を持ち、リレーションを
  張らない設計にしてあるため、`ModelConfiguration(cloudKitDatabase:)` の切り替えだけで対応できます。
- **実広告 SDK**: `AdPresenting` の実装と `ParentAreaAdView` の中身を差し替えるだけです。
- **教材の追加**: `KanaCatalog` / `EnglishWordCatalog` / `UnlockCatalog` にデータを足すだけで、
  出題・アンロック・図鑑に反映されます。
- **パッケージのリンク形態**: `PiyoCore` を複数ターゲットがリンクしています。
  リンク時の重複が気になる場合は `Packages/PiyoCore/Package.swift` の product を
  `type: .dynamic` に変更してください。
