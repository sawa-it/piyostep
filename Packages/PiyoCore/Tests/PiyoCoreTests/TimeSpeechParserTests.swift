import XCTest
@testable import PiyoCore

final class TimeSpeechParserTests: XCTestCase {

    private func parsedTime(_ text: String, file: StaticString = #filePath, line: UInt = #line) -> ClockTime? {
        if case let .time(time) = TimeSpeechParser.parse(text) {
            return time
        }
        return nil
    }

    func testParsesHourOnly() {
        XCTAssertEqual(parsedTime("さんじ"), ClockTime(hour: 3, minute: 0))
        XCTAssertEqual(parsedTime("3じ"), ClockTime(hour: 3, minute: 0))
        XCTAssertEqual(parsedTime("くじ"), ClockTime(hour: 9, minute: 0))
        XCTAssertEqual(parsedTime("よじ"), ClockTime(hour: 4, minute: 0))
        XCTAssertEqual(parsedTime("しちじ"), ClockTime(hour: 7, minute: 0))
    }

    func testParsesTwelveWithoutConfusingJuu() {
        // 「じゅう」の「じ」を時刻の区切りと誤解しないこと
        XCTAssertEqual(parsedTime("じゅうにじ"), ClockTime(hour: 12, minute: 0))
        XCTAssertEqual(parsedTime("じゅういちじ"), ClockTime(hour: 11, minute: 0))
    }

    func testParsesHourAndMinute() {
        XCTAssertEqual(parsedTime("さんじさんじゅっぷん"), ClockTime(hour: 3, minute: 30))
        XCTAssertEqual(parsedTime("3じ30ぷん"), ClockTime(hour: 3, minute: 30))
        XCTAssertEqual(parsedTime("ごじじゅうごふん"), ClockTime(hour: 5, minute: 15))
        XCTAssertEqual(parsedTime("１２じ４５ふん"), ClockTime(hour: 12, minute: 45))
    }

    func testParsesHalfPast() {
        XCTAssertEqual(parsedTime("くじはん"), ClockTime(hour: 9, minute: 30))
        XCTAssertEqual(parsedTime("9じはんです"), ClockTime(hour: 9, minute: 30))
    }

    func testParsesExactlyOnTheHour() {
        XCTAssertEqual(parsedTime("ろくじちょうど"), ClockTime(hour: 6, minute: 0))
    }

    func testToleratesFillersAndPoliteness() {
        XCTAssertEqual(parsedTime("えっと、さんじ３０ぷんです！"), ClockTime(hour: 3, minute: 30))
        XCTAssertEqual(parsedTime("にじだとおもう"), ClockTime(hour: 2, minute: 0))
    }

    func testBareNumberIsReportedSeparately() {
        XCTAssertEqual(TimeSpeechParser.parse("さん"), .bareNumber(3))
        XCTAssertEqual(TimeSpeechParser.parse("30"), .bareNumber(30))
    }

    func testUnparsableInput() {
        XCTAssertEqual(TimeSpeechParser.parse("わかんない"), .unparsable)
        XCTAssertEqual(TimeSpeechParser.parse(""), .unparsable)
        // 13 時のような 12 時間表記外は受け取らない
        XCTAssertEqual(TimeSpeechParser.parse("じゅうさんじ"), .unparsable)
    }

    func testRejectsImpossibleMinutes() {
        XCTAssertEqual(TimeSpeechParser.parse("さんじななじゅうごふん"), .unparsable)
    }
}
