import XCTest
@testable import PiyoCore

final class JapaneseTextNormalizerTests: XCTestCase {

    func testKatakanaBecomesHiragana() {
        XCTAssertEqual(JapaneseTextNormalizer.katakanaToHiragana("アヒル"), "あひる")
        XCTAssertEqual(JapaneseTextNormalizer.katakanaToHiragana("ヴァイオリン"), "ゔぁいおりん")
    }

    func testFullwidthDigitsBecomeHalfwidth() {
        XCTAssertEqual(JapaneseTextNormalizer.toHalfwidthAlphanumerics("３０"), "30")
        XCTAssertEqual(JapaneseTextNormalizer.toHalfwidthAlphanumerics("Ａｂ"), "Ab")
    }

    func testStripsSymbolsAndSpaces() {
        XCTAssertEqual(JapaneseTextNormalizer.stripSymbols("さん じ、３０ ぷん！"), "さんじ３０ぷん")
    }

    func testStripsFillers() {
        XCTAssertEqual(JapaneseTextNormalizer.stripFillers("えっとさんじ"), "さんじ")
        XCTAssertEqual(JapaneseTextNormalizer.stripFillers("あのうさぎ"), "うさぎ")
    }

    func testStripsTrailingExpressions() {
        XCTAssertEqual(JapaneseTextNormalizer.stripTrailingExpressions("さんじです"), "さんじ")
        XCTAssertEqual(JapaneseTextNormalizer.stripTrailingExpressions("さんじだとおもう"), "さんじ")
    }

    func testFullPipeline() {
        XCTAssertEqual(JapaneseTextNormalizer.normalize("えっと、サンジ３０ぷんです！"), "さんじ30ぷん")
        XCTAssertEqual(JapaneseTextNormalizer.normalize("  アヒル  "), "あひる")
        XCTAssertEqual(JapaneseTextNormalizer.normalize("三時半"), "さんじはん")
    }

    func testNormalizeIsIdempotent() {
        let once = JapaneseTextNormalizer.normalize("えっと、サンジ３０ぷんです！")
        XCTAssertEqual(JapaneseTextNormalizer.normalize(once), once)
    }

    func testLooseKeyIgnoresVoicingAndSmallKana() {
        XCTAssertEqual(JapaneseTextNormalizer.looseKey("がっこう"), JapaneseTextNormalizer.looseKey("かこう"))
        XCTAssertEqual(JapaneseTextNormalizer.looseKey("しゃ"), JapaneseTextNormalizer.looseKey("しや"))
        XCTAssertEqual(JapaneseTextNormalizer.looseKey("ケーキ"), "けき")
    }
}

final class JapaneseNumberParserTests: XCTestCase {

    func testParsesArabicDigits() {
        XCTAssertEqual(JapaneseNumberParser.parse("30"), 30)
        XCTAssertEqual(JapaneseNumberParser.parse("３０ぷん"), 30)
        XCTAssertEqual(JapaneseNumberParser.parse("7こ"), 7)
    }

    func testParsesSingleDigitReadings() {
        let expectations: [(String, Int)] = [
            ("ぜろ", 0), ("いち", 1), ("に", 2), ("さん", 3), ("よん", 4), ("し", 4),
            ("ご", 5), ("ろく", 6), ("なな", 7), ("しち", 7), ("はち", 8), ("きゅう", 9), ("く", 9)
        ]
        for (text, expected) in expectations {
            XCTAssertEqual(JapaneseNumberParser.parse(text), expected, "\(text)")
        }
    }

    func testParsesTens() {
        XCTAssertEqual(JapaneseNumberParser.parse("じゅう"), 10)
        XCTAssertEqual(JapaneseNumberParser.parse("じゅうに"), 12)
        XCTAssertEqual(JapaneseNumberParser.parse("にじゅう"), 20)
        XCTAssertEqual(JapaneseNumberParser.parse("にじゅうご"), 25)
        XCTAssertEqual(JapaneseNumberParser.parse("さんじゅっ"), 30)
        XCTAssertEqual(JapaneseNumberParser.parse("きゅうじゅうきゅう"), 99)
    }

    func testParsesHundreds() {
        XCTAssertEqual(JapaneseNumberParser.parse("ひゃく"), 100)
        XCTAssertEqual(JapaneseNumberParser.parse("さんびゃく"), 300)
        XCTAssertEqual(JapaneseNumberParser.parse("ろっぴゃく"), 600)
        XCTAssertEqual(JapaneseNumberParser.parse("はっぴゃくにじゅうさん"), 823)
    }

    func testParsesKanjiDigits() {
        XCTAssertEqual(JapaneseNumberParser.parse("三"), 3)
        XCTAssertEqual(JapaneseNumberParser.parse("十二"), 12)
    }

    func testIgnoresTrailingCounters() {
        XCTAssertEqual(JapaneseNumberParser.parse("さんこ"), 3)
        XCTAssertEqual(JapaneseNumberParser.parse("ごほん"), 5)
    }

    func testReturnsNilForNonNumbers() {
        XCTAssertNil(JapaneseNumberParser.parse("わかんない"), "数として解釈できないものは nil")
        XCTAssertNil(JapaneseNumberParser.parse(""))
        XCTAssertNil(JapaneseNumberParser.parse("めがね"))
    }

    func testReadingsRoundTrip() {
        for value in [0, 1, 4, 7, 9, 10, 12, 25, 30, 57, 99, 100, 300, 600, 823] {
            for reading in JapaneseNumberParser.readings(for: value) {
                XCTAssertEqual(
                    JapaneseNumberParser.parse(reading),
                    value,
                    "\(value) の読み「\(reading)」が復元できない"
                )
            }
        }
    }
}

final class EnglishTextNormalizerTests: XCTestCase {

    func testNormalizeKeepsLettersOnly() {
        XCTAssertEqual(EnglishTextNormalizer.normalize("Apple!"), "apple")
        XCTAssertEqual(EnglishTextNormalizer.normalize("  an   APPLE  "), "an apple")
        XCTAssertEqual(EnglishTextNormalizer.normalize("ice-cream"), "ice cream")
    }

    func testStripsArticlesAndPlurals() {
        XCTAssertEqual(EnglishTextNormalizer.stripArticlesAndPlural("an apple"), "apple")
        XCTAssertEqual(EnglishTextNormalizer.stripArticlesAndPlural("apples"), "apple")
        XCTAssertEqual(EnglishTextNormalizer.stripArticlesAndPlural("the dogs"), "dog")
        XCTAssertEqual(EnglishTextNormalizer.stripArticlesAndPlural("glasses"), "glass")
        XCTAssertEqual(EnglishTextNormalizer.stripArticlesAndPlural("class"), "class")
    }
}

final class FuzzyMatcherTests: XCTestCase {

    func testLevenshteinDistance() {
        XCTAssertEqual(FuzzyMatcher.levenshteinDistance("", ""), 0)
        XCTAssertEqual(FuzzyMatcher.levenshteinDistance("abc", ""), 3)
        XCTAssertEqual(FuzzyMatcher.levenshteinDistance("kitten", "sitting"), 3)
        XCTAssertEqual(FuzzyMatcher.levenshteinDistance("あひる", "あひろ"), 1)
    }

    func testJapaneseExactMatch() {
        XCTAssertEqual(FuzzyMatcher.matchJapanese(input: "あ", candidates: ["あ"]), .exact)
        XCTAssertEqual(FuzzyMatcher.matchJapanese(input: "ア", candidates: ["あ"]), .exact)
        XCTAssertEqual(FuzzyMatcher.matchJapanese(input: "あひるです", candidates: ["あ", "あひる"]), .exact)
    }

    func testJapaneseToleratesSmallDeviations() {
        // 「らいおん」を「らいをん」と聞き取ってしまっても正解にする
        XCTAssertNotEqual(FuzzyMatcher.matchJapanese(input: "らいをん", candidates: ["らいおん"]), .none)
        // 長音記号と表記系の揺れ
        XCTAssertEqual(FuzzyMatcher.matchJapanese(input: "ケーキ", candidates: ["けーき"]), .exact)
        // 濁点の揺れ
        XCTAssertNotEqual(FuzzyMatcher.matchJapanese(input: "しまうま", candidates: ["しまうば"]), .none)
    }

    func testJapaneseRejectsUnrelatedInput() {
        XCTAssertEqual(FuzzyMatcher.matchJapanese(input: "ぶどう", candidates: ["あ"]), .none)
        XCTAssertEqual(FuzzyMatcher.matchJapanese(input: "", candidates: ["あ"]), .none)
    }

    func testSingleCharacterRequiresExactMatch() {
        // 1 文字問題で隣の文字を誤って正解にしないこと
        XCTAssertEqual(FuzzyMatcher.matchJapanese(input: "い", candidates: ["あ"]), .none)
    }

    func testEnglishMatching() {
        XCTAssertEqual(FuzzyMatcher.matchEnglish(input: "Apple!", candidates: ["apple"]), .exact)
        XCTAssertEqual(FuzzyMatcher.matchEnglish(input: "an apple", candidates: ["apple"]), .exact)
        XCTAssertNotEqual(FuzzyMatcher.matchEnglish(input: "aple", candidates: ["apple"]), .none)
        XCTAssertEqual(FuzzyMatcher.matchEnglish(input: "banana", candidates: ["apple"]), .none)
    }
}
