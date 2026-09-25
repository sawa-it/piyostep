# ぴよステップ（PiyoStep）設計ドキュメント

3〜6歳の日本人の未就学児向け iOS 学習アプリ。
「子どもが自分から毎日さわりたくなる」ことを最優先にした、ゲーム感覚の学習アプリ。

---

## 1. プロダクト方針

| 観点 | 方針 |
| --- | --- |
| 対象 | 3〜6歳（日本語話者） |
| 前提 | 文字が読めない子でも一人で操作できる |
| 操作 | 大きなボタン / イラスト / 音声読み上げ / ドラッグ / 音声入力 |
| 1回の時間 | 3〜10分（今日のチャレンジは 5〜12問） |
| ネガティブ演出 | 使わない。間違いは「もういっかい！」に変換 |
| 収益 | 保護者画面に入るときだけ広告（子どもの画面には一切出さない）／買い切りで広告解除 |
| 通信 | 初期版はオフライン完結。ログイン不要・バックエンド不要 |

### やらないこと

- ガチャ・ランダム報酬・課金煽り
- ストリーク途切れによる罰・不安演出
- 「まちがい」「おそい」「じかんぎれ」などの否定語
- 音声データの外部送信・独自保存

---

## 2. 画面構成

```
起動
 └─ RootView（オンボーディング or ホーム）
     ├─ [プロフィール未作成] OnboardingView
     │     1. なまえ（ひらがな入力 or おまかせ）
     │     2. としは？（3/4/5/6 の大きなボタン）
     │     3. あいぼうをえらぶ（キャラクター選択）
     └─ HomeView（子どもモード / タブなし・大ボタン6個）
          ├─ きょうのチャレンジ   → ChallengeSessionView → ResultView
          ├─ とけい               → SubjectMenuView(clock) → ClockReadGameView / ClockSetGameView
          ├─ もじ                 → SubjectMenuView(kana) → KanaReadView / TraceView / KanaWordView
          ├─ すうじ               → SubjectMenuView(number) → CountGameView / PlaceValueView / NumberReadView
          ├─ えいご               → SubjectMenuView(english) → AlphabetView / EnglishWordView
          ├─ ごはんタイマー       → MealSetupView → MealRaceView → MealResultView
          ├─ バッジ → BadgeCollectionView（なかま・きせかえ・おさら・はいけい・いきものバッジ）
          └─ おうちのひと（右上・小さめ）→ ParentGateView → ParentTabView
                                            ├─ ProgressDashboardView（習熟度）
                                            ├─ SettingsView（設定）
                                            └─ PurchaseView（広告解除）
```

### 画面の原則

- 1画面につき主要アクションは 1〜3 個。
- すべてのボタンは最小 88pt 角（Apple の推奨 44pt の 2 倍）。
- テキストには必ずアイコン／イラストが伴う。
- 画面表示時に「なにをするか」を音声で自動読み上げ（設定で OFF 可）。
- 戻る操作は左上の大きな「←」1 箇所のみ。

---

## 3. ユーザーフロー

### 3.1 今日のチャレンジ（メイン導線）

```
HomeView
  → [きょうのチャレンジ] タップ
  → ぴよちゃんが「きょうは ○もん いってみよう！」と音声
  → 問題 1 …… n （各問 20〜40 秒）
       ├ 出題（イラスト＋音声）
       ├ 回答（選択 / 数字入力 / ドラッグ / なぞり / 音声）
       ├ 正解 → ✨演出 + 「せいかい！」+ ★獲得
       └ 不正解 → キャラが「おしい！もういっかい！」→ 再挑戦（2回目でヒント）
  → ResultView（獲得★、アンロック演出）
  → HomeView
```

### 3.2 音声回答フロー（全教科共通）

```
問題表示
  → 大きなマイクボタン（🎤）
  → タップ
  → 権限未取得なら iOS の権限ダイアログ（拒否されても他の回答方法は残る）
  → 「はなしてね」表示 + マイク拡大アニメ + 波形 + キャラが耳をかたむける
  → 発話 → 認識結果を正規化 → 判定
       ├ 正解        → 正解演出
       ├ 不正解      → 「おしい！もういっかい！」（学習履歴には不正解として記録）
       └ 認識できない → 「もういちど いってみよう！」（不正解として記録しない）
  → 3回連続で認識できない場合、自動でタップ回答 UI に切替（「タップでこたえてもいいよ」）
```

### 3.3 ご飯タイマー

```
HomeView → [ごはんタイマー]
  → MealSetupView（保護者設定の時間・キャラを確認、スタートのみ）
  → 「くまくんと きょうそう！ どっちが さきに ごはんを たべおわるかな？」（音声＋アニメ）
  → 3・2・1 カウントダウン
  → MealRaceView
       ├ 左：じぶん（お皿が減っていく）／右：くまくん（もぐもぐアニメ）
       ├ 中央：ゴールまでのトラック（2つのアイコンが進む）
       ├ 「もぐもぐ！」タップでじぶんのお皿が少し進む
       └ 大きな「たべおわった！」ボタン（完食したお皿のイラスト付き）
  → MealResultView
       ├ 子どもが先  → 「やったー！くまくんより はやかったね！」＋一緒に喜ぶ
       └ キャラが先  → 「くまくんは たべおわったよ！あとちょっと！」＋応援（否定語なし）
  → ★付与 → HomeView
```

### 3.4 保護者フロー

```
HomeView 右上の小さな「おうちのひと」
  → ParentGateView（「3 + 4 は？」などの計算を数字キーパッドで回答）
       ├ 正解 → ParentTabView
       └ 不正解 → 別の問題に差し替え（子どもは突破しにくい）
  → 習熟度 / 設定 / 広告解除
```

---

## 4. データモデル

### 4.1 ドメインモデル（PiyoCore・純粋 Swift）

| 型 | 役割 |
| --- | --- |
| `Subject` | 教科（clock / hiragana / katakana / number / alphabet / englishWord） |
| `Skill` | 習熟度を追う単位（clockRead, clockSet, hiraganaRead, hiraganaWrite, numberCount, placeValue, …） |
| `DifficultyLevel` | 1〜5 の段階（Skill ごとに意味づけ） |
| `Question` | 出題1問（id / subject / skill / difficulty / prompt / content / answer / answerModes / choices） |
| `QuestionContent` | 出題内容の列挙（clockRead, clockSet, countObjects, placeValue, numberRead, kana, alphabet, englishWord） |
| `ExpectedAnswer` | 正解（.time / .integer / .text(canonical, accepted) / .trace） |
| `AnswerInput` | 回答入力（.choice / .integer / .time / .speech / .trace） |
| `AnswerJudgement` | `.correct` / `.incorrect` / `.unclear`（音声が聞き取れなかった＝不正解にしない） |
| `ChildProfile` | 子ども情報（名前・年齢・相棒キャラ・作成日） |
| `AttemptRecord` | 1回答の記録（skill / difficulty / judgement / answerMode / 所要時間 / 日時） |
| `SessionRecord` | 1セッションの記録（種別 / 開始終了 / 問題数 / 正答数 / 獲得★） |
| `MasterySnapshot` | Skill ごとの習熟度（ewma / attempts / level / lastPracticed） |
| `UnlockableItem` | アンロック対象（character / costume / tableware / background / stamp） |
| `UnlockCondition` | 条件（totalStars / learningDays / mealsCompleted / subjectMastery / challengesCompleted） |
| `AppSettings` | 設定一式（Codable） |
| `MealRaceConfiguration` | ご飯タイマー設定（時間・キャラ・シード） |

### 4.2 永続化（アプリ層・SwiftData）

```
@Model ChildProfileEntity     id, name, age, buddyCharacterID, createdAt
@Model AttemptEntity          id, skillRaw, difficulty, judgementRaw, answerModeRaw, durationMS, createdAt
@Model SessionEntity          id, kindRaw, startedAt, endedAt, questionCount, correctCount, starsEarned
@Model MasteryEntity          skillRaw(unique), ewma, attempts, correctCount, level, lastPracticedAt
@Model UnlockEntity           itemID(unique), unlockedAt
@Model MealSessionEntity      id, startedAt, endedAt, targetSeconds, childFinishedFirst, characterID
@Model SettingsEntity         single row, settingsJSON(String)
```

- `PiyoCore` の純粋な構造体 ⇄ SwiftData エンティティは `SwiftDataProgressRepository` が相互変換する。
  これにより **コアロジックは SwiftData に一切依存しない**（Linux/CI でもテスト可能）。
- 将来の iCloud 同期は `ModelConfiguration(cloudKitDatabase:)` の切り替えだけで対応できるよう、
  エンティティはすべて「省略可能な値 + デフォルト」を持たせ、リレーションを張らずに ID 参照とする。

---

## 5. ディレクトリ構成

```
.
├── PiyoStep.xcodeproj/                  Xcode 16 形式（フォルダ同期グループ）
├── project.yml                          XcodeGen 用スペック（プロジェクト再生成用の予備）
├── Packages/
│   └── PiyoCore/                        ★ 純粋ロジック（Foundation のみ・UI 非依存）
│       ├── Package.swift
│       ├── Sources/PiyoCore/
│       │   ├── Core/                    RandomSource, Clock 抽象, 共通ユーティリティ
│       │   ├── Models/                  Subject, Skill, Question, Card データ, Profile, Record
│       │   ├── Text/                    日本語/英語の正規化・数詞解析・時刻解析・あいまい一致
│       │   ├── Generators/              各教科の問題生成
│       │   ├── Grading/                 正誤判定
│       │   ├── Engine/                  習熟度・難易度自動調整・今日のチャレンジ・セッション進行
│       │   ├── Meal/                    ご飯タイマー（キャラのペース計画・進行・終了判定）
│       │   ├── Rewards/                 アンロック条件・カタログ
│       │   ├── Settings/                AppSettings と保存/読込
│       │   ├── Persistence/             履歴ストアの抽象と集計
│       │   └── Speech/                  音声認識/合成の抽象 + 音声回答ステートマシン
│       └── Tests/PiyoCoreTests/         ★ Unit Test（Xcode 不要・swift test で実行可能）
├── PiyoStep/                            アプリターゲット（SwiftUI）
│   ├── App/                             エントリポイント・DI コンテナ・ルーティング
│   ├── DesignSystem/                    色・タイポ・大ボタン・キャラ描画・演出
│   ├── Services/                        Speech / AVFoundation / StoreKit / 広告 / SwiftData 実装
│   ├── ViewModels/                      画面ごとの ViewModel（@MainActor / Observable）
│   ├── Features/                        画面（Home, Challenge, Clock, Kana, Number, English, Meal, Parent）
│   └── Resources/                       Assets.xcassets（Fluent Emoji から描き出したイラスト・アイコン・色）
│                                        ※ Info.plist は GENERATE_INFOPLIST_FILE で生成し、
│                                          マイク／音声認識の説明文はビルド設定で指定
├── PiyoStepTests/                       アプリ層の Unit Test（ViewModel・モック注入）
├── PiyoStepUITests/                     XCUITest（主要導線）
└── docs/DESIGN.md                       本書
```

**イラストについて**: キャラクター・ことばの絵・食べもの・バッジは、フリー素材の
**Fluent Emoji**（Microsoft, MIT License）を `Tools/fetch_art_assets.py` で PNG に描き出して使う。
どの絵をどこで使うかは `DesignSystem/Art/ArtAsset.swift` の対応表に集める。
キャラクターは静止画 1 枚だが、`CharacterArtView` が時刻から「はずむ・ちぢむ・かたむく」を
計算し、気持ちに合わせた小物（きらきら・zzz・ふきだし・好物）を添えて動かす。
お皿・時計・バッジのふち・紙吹雪・光の帯など、素材で表せないものはコード描画のまま。
動きは「視差効果を減らす」と UI テスト（`-uiTestMode 1`）で止まる（`PiyoMotion`）。

**バッジについて**: 集めたものは「ずかん」ではなく **バッジ** として見せる。
なかま・きせかえ・おさら・はいけいに加えて、チューリップ・バッタ・てんとうむし などの
いきものバッジがあり、どれも缶バッジの形（金のふち＋リボン）で並ぶ。

**なぞり書きについて**: 幼児は小さくは書けないので、なぞり書き・自由書きのときは
出題を脇に寄せ、残りの高さをすべてキャンバスに渡す（横に余裕があればボタンは右に立てる）。

---

## 6. 学習エンジンの構造

```
                    ┌──────────────────────┐
  AttemptRecord ──▶ │  MasteryEstimator    │ ──▶ MasterySnapshot(skill)
                    └──────────────────────┘             │
                                                          ▼
                    ┌──────────────────────┐    ┌────────────────────────┐
                    │ AdaptiveDifficulty   │◀───│  難易度の現在値/推移    │
                    │ Engine               │───▶│  DifficultyLevel 1..5   │
                    └──────────────────────┘    └────────────────────────┘
                                                          │
                    ┌──────────────────────┐              ▼
                    │ DailyChallengeBuilder│───▶ [Question]（弱点重み付け + 変化）
                    └──────────────────────┘              │
                                                          ▼
                    ┌──────────────────────┐    ┌────────────────────────┐
                    │ LearningSessionEngine│◀──▶│ AnswerGrader            │
                    │（進行・再挑戦・★）    │    │（教科別の正誤判定）      │
                    └──────────────────────┘    └────────────────────────┘
                                │
                                ▼
                    AttemptRecord / SessionRecord → LearningHistoryStore
                                │
                                ▼
                    UnlockEvaluator → 新規アンロック演出
```

### 6.1 習熟度推定（MasteryEstimator）

- Skill ごとに指数移動平均 `ewma = ewma * (1 - α) + correct * α`（α = 0.3、初期値 0.5）。
- `judgement == .unclear`（音声が聞き取れなかった）は **集計から除外**。
- 直近30件のウィンドウ正答率も併用し、`masteryScore = 0.7 * ewma + 0.3 * windowAccuracy`。

### 6.2 難易度自動調整（AdaptiveDifficultyEngine）

| 条件 | 動作 |
| --- | --- |
| 現レベルでの試行 ≥ 6 かつ ewma ≥ 0.8 | レベル +1（上限 5） |
| 現レベルでの試行 ≥ 4 かつ ewma ≤ 0.4 | レベル −1（下限 1） |
| 直近 3 問連続不正解 | 次の 2 問を 1 段下げた復習問題に差し替え |
| その他 | 維持 |

保護者設定で「かんたん / ふつう / むずかしい / じどう」を選択可能。
「じどう」以外は上限レベルを固定し、その範囲内で上下する。

### 6.3 今日のチャレンジ（DailyChallengeBuilder）

1. 有効教科から Skill を列挙し、重み `w = (1 - masteryScore) + 最終学習からの経過日数ボーナス` を計算。
2. 1問目は必ず **得意な Skill の 1 段やさしい問題**（成功体験から始める）。
3. 以降は重み付き抽選。**同じ Skill が 3 連続しない**ように制約。
4. 最後の 1 問は「お気に入り教科（直近で最も遊んだ）」から出題して気持ちよく終える。
5. 問題数は `dailyGoal`（light=5 / normal=8 / plenty=12）。
6. 乱数は `RandomSource` 経由（テストでは `SeededRandomSource` で決定的）。

### 6.4 セッション進行（LearningSessionEngine）

- 状態: `.question(index)` → `.judging` → `.feedback` → 次へ / 再挑戦。
- 1問につき再挑戦は最大 2 回。2 回目からヒント（選択肢を 4→2 に減らす等）。
- `.unclear` は試行回数にカウントせず、スコアにも影響しない。
- ★ は「1回目正解 = 2★ / 再挑戦後正解 = 1★ / 未正解 = 1★（参加賞）」。ゼロにはしない。

---

## 7. 音声入力の共通設計

```
┌─────────────────────────────────────────────────────────┐
│ VoiceAnswerCoordinator（PiyoCore・純粋ステートマシン）   │
│  idle → requestingPermission → listening → processing    │
│       → result(.correct/.incorrect/.unclear) → idle      │
│  ・連続 unclear 回数を保持し、3回でタップ回答を提案       │
│  ・権限拒否 / 未対応端末は即 .unavailable（学習は継続可） │
└─────────────────────────────────────────────────────────┘
        ▲ 依存は protocol のみ（テストではモック）
        │
┌───────┴────────────┐        ┌─────────────────────────┐
│ SpeechRecognizing  │        │ SpeechSynthesizing      │
│  .authorize()      │        │  .speak(text, locale)   │
│  .start(locale:)   │        │  .stop()                │
│  .stop()           │        └─────────────────────────┘
│  結果: AsyncStream │                 ▲
└────────────────────┘                 │
        ▲                              │
┌───────┴──────────────┐   ┌───────────┴──────────────┐
│ SystemSpeechRecognizer│   │ SystemSpeechSynthesizer  │
│ (Speech + AVAudio)    │   │ (AVSpeechSynthesizer)    │
└───────────────────────┘   └──────────────────────────┘
```

### 認識結果の正規化パイプライン（日本語）

```
"えっと、さんじ３０ぷんです！"
  → 記号・空白・フィラー除去           "さんじ30ぷんです"
  → 全角→半角、カタカナ→ひらがな        "さんじ30ぷんです"
  → 語尾除去（です/だよ/かな/だと思う）  "さんじ30ぷん"
  → 日本語数詞→数値（さん→3）           "3じ30ぷん"
  → 時刻パターン抽出                     ClockTime(hour: 3, minute: 30)
```

- 「はん」→ 30分、「ちょうど」→ 0分、「じはん」対応。
- 数字は「じゅう/ひゃく」構成にも対応（`JapaneseNumberParser`、0〜999）。
- ひらがな 1 文字問題は **濁点・半濁点・拗音・促音の揺れ**を許容する
  `FuzzyMatcher`（レーベンシュタイン距離 + かな混同表）で判定。
- 英語は小文字化・非英字除去・語尾 s/es 許容・距離しきい値（3〜4文字は1、5文字以上は2）。
- **判定できない**（空文字・信頼度が極端に低い・想定外の語）場合は `.unclear` とし、
  学習履歴上の不正解にはしない。

---

## 8. テスト戦略

| 層 | 場所 | 手段 |
| --- | --- | --- |
| ドメインロジック | `Packages/PiyoCore/Tests/PiyoCoreTests` | XCTest（`swift test` で Xcode なしでも実行可） |
| ViewModel / サービス | `PiyoStepTests` | XCTest + モック注入（Speech/StoreKit/時計/履歴） |
| 主要導線 | `PiyoStepUITests` | XCUITest（`-uiTestMode` 起動引数で決定的な状態を注入） |

### 抽象化して差し替え可能にするもの

| 実物 | Protocol | テスト用 |
| --- | --- | --- |
| Speech framework | `SpeechRecognizing` | `MockSpeechRecognizer`（任意の認識結果を流す） |
| AVSpeechSynthesizer | `SpeechSynthesizing` | `MockSpeechSynthesizer`（発話内容を記録） |
| AVAudioPlayer 効果音 | `SoundPlaying` | `MockSoundPlayer` |
| `Date()` | `ClockProviding` | `FixedClock` / `AdvancingClock` |
| SwiftData | `LearningHistoryStoring` / `SettingsStoring` | `InMemory…` |
| StoreKit | `PurchaseServing` | `MockPurchaseService` |
| 広告 SDK | `AdPresenting` | `MockAdPresenter`（表示要求を記録） |
| 乱数 | `RandomSource` | `SeededRandomSource` |

### UI テストの決定性

アプリは起動引数を解釈する:

- `-uiTestMode 1` … インメモリ永続化 + 広告無効 + アニメーション短縮
- `-uiTestProfile <name>` … プロフィール自動作成（オンボーディングをスキップ）
- `-uiTestSeed <n>` … 問題生成の乱数シードを固定
- `-uiTestFreshInstall 1` … プロフィール未作成状態（オンボーディング検証）
- `-uiTestVoiceScript "さんじ"` … モック音声認識に流す文字列

すべての主要要素に `accessibilityIdentifier` を付与する（`A11yID` に集約）。

---

## 9. MVP 範囲

### MVP に含む（実装済み）

- オンボーディング（子どもプロフィール作成）
- ホーム画面
- 今日のチャレンジ（複数教科ミックス）
- とけい：時刻を読む（選択 / 数字入力 / 音声）
- とけい：針をドラッグして合わせる
- ひらがな：読み・なぞり書き・ことばあわせ・音声回答
- カタカナ：読み・なぞり書き・音声回答
- すうじ：かぞえる・数字を読む・位（一/十/百）・音声回答
- アルファベット：大文字小文字・なぞり書き・音声回答
- えいごのことば：絵と音と文字・音声回答
- ご飯タイマー（キャラクターとの競争）
- 共通の音声入力 UI（マイクボタン・波形・キャラリアクション・再入力導線）
- 学習結果の保存（SwiftData）
- バッジ / アンロック（なかま・きせかえ・おさら・はいけい・いきものバッジ）
- ペアレンタルゲート → 保護者画面（習熟度グラフ・設定・広告解除）
- 保護者画面に入るときの広告スロット（子どもの画面には出さない）+ StoreKit による広告解除
- Unit Test / UI Test

### MVP 以降（構造だけ用意）

- iCloud 同期（`ModelConfiguration` の切り替えで対応可能な設計）
- 実広告 SDK の差し込み（`AdPresenting` の実装追加のみ）
- 追加キャラクター・追加教材（カタログにデータを足すだけ）
- 保護者向けの週次レポート通知

---

## 10. 依存関係の方向

```
PiyoStepUITests ─▶ PiyoStep(app)
PiyoStepTests   ─▶ PiyoStep(app) ─▶ PiyoCore
PiyoCoreTests   ─▶ PiyoCore
```

`PiyoCore` は **SwiftUI / UIKit / SwiftData / Speech / StoreKit に一切依存しない**。
これにより、出題・判定・習熟度・難易度・チャレンジ選定・ご飯タイマー進行といった
「アプリの頭脳」部分が OS 非依存でテストできる。
