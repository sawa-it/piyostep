import XCTest
@testable import PiyoCore

final class ClockTimeTests: XCTestCase {

    func testNormalizesHourAndMinute() {
        XCTAssertEqual(ClockTime(hour: 0, minute: 0).hour, 12)
        XCTAssertEqual(ClockTime(hour: 13, minute: 0).hour, 1)
        XCTAssertEqual(ClockTime(hour: 3, minute: 60).minute, 0)
        XCTAssertEqual(ClockTime(hour: 3, minute: -10).minute, 50)
    }

    func testHandAngles() {
        let threeOClock = ClockTime(hour: 3, minute: 0)
        XCTAssertEqual(threeOClock.hourHandAngleDegrees, 90, accuracy: 0.001)
        XCTAssertEqual(threeOClock.minuteHandAngleDegrees, 0, accuracy: 0.001)

        let threeThirty = ClockTime(hour: 3, minute: 30)
        // 短針は 3 と 4 のちょうど真ん中
        XCTAssertEqual(threeThirty.hourHandAngleDegrees, 105, accuracy: 0.001)
        XCTAssertEqual(threeThirty.minuteHandAngleDegrees, 180, accuracy: 0.001)

        let twelve = ClockTime(hour: 12, minute: 0)
        XCTAssertEqual(twelve.hourHandAngleDegrees, 0, accuracy: 0.001)
    }

    func testTotalMinutesRoundTrip() {
        for hour in 1 ... 12 {
            for minute in [0, 7, 30, 59] {
                let time = ClockTime(hour: hour, minute: minute)
                XCTAssertEqual(ClockTime.fromTotalMinutes(time.totalMinutes), time)
            }
        }
    }

    func testFromHandAnglesReadsDraggedPosition() {
        let result = ClockTime.fromHandAngles(
            hourAngleDegrees: 105,
            minuteAngleDegrees: 180,
            minuteStep: 5
        )
        XCTAssertEqual(result, ClockTime(hour: 3, minute: 30))
    }

    func testFromHandAnglesSnapsToStep() {
        // 32 分の位置 (192°) は 5 分刻みでは 30 分に丸められる
        let snapped = ClockTime.fromHandAngles(
            hourAngleDegrees: 90,
            minuteAngleDegrees: 192,
            minuteStep: 5
        )
        XCTAssertEqual(snapped.minute, 30)

        // 1 分刻みならそのまま 32 分
        let exact = ClockTime.fromHandAngles(
            hourAngleDegrees: 90,
            minuteAngleDegrees: 192,
            minuteStep: 1
        )
        XCTAssertEqual(exact.minute, 32)
    }

    func testFromHandAnglesRoundsUpHourJustBeforeTwelve() {
        // 短針が 12 の少し手前、長針は 12 ちょうど → 12 時として受け取る
        let result = ClockTime.fromHandAngles(
            hourAngleDegrees: 359,
            minuteAngleDegrees: 0,
            minuteStep: 1
        )
        XCTAssertEqual(result, ClockTime(hour: 12, minute: 0))
    }

    func testFromHandAnglesDoesNotRoundUpWhenMinutesAreLarge() {
        // 短針が 3 の少し手前、長針は 55 分 → 2 時 55 分
        let result = ClockTime.fromHandAngles(
            hourAngleDegrees: 89,
            minuteAngleDegrees: 330,
            minuteStep: 5
        )
        XCTAssertEqual(result, ClockTime(hour: 2, minute: 55))
    }

    func testMatchesWithTolerance() {
        let target = ClockTime(hour: 3, minute: 30)
        XCTAssertTrue(target.matches(ClockTime(hour: 3, minute: 30)))
        XCTAssertFalse(target.matches(ClockTime(hour: 3, minute: 31)))
        XCTAssertTrue(target.matches(ClockTime(hour: 3, minute: 31), toleranceMinutes: 1))
        XCTAssertFalse(target.matches(ClockTime(hour: 4, minute: 30), toleranceMinutes: 1))
    }

    func testMatchesAcrossTwelveBoundary() {
        let justBefore = ClockTime(hour: 12, minute: 59)
        let justAfter = ClockTime(hour: 1, minute: 0)
        XCTAssertTrue(justBefore.matches(justAfter, toleranceMinutes: 1))
    }

    func testDisplayAndSpokenText() {
        XCTAssertEqual(ClockTime(hour: 3, minute: 0).displayJapanese, "3じ")
        XCTAssertEqual(ClockTime(hour: 3, minute: 30).displayJapanese, "3じ30ふん")
        // 読み上げは漢字で渡し、TTS に自然な読みを選ばせる
        XCTAssertEqual(ClockTime(hour: 3, minute: 0).spokenJapanese, "3時")
        XCTAssertEqual(ClockTime(hour: 3, minute: 30).spokenJapanese, "3時30分")
    }

    func testMinuteSuffixRules() {
        XCTAssertEqual(ClockTime.minuteSuffix(1), "ぷん")
        XCTAssertEqual(ClockTime.minuteSuffix(2), "ふん")
        XCTAssertEqual(ClockTime.minuteSuffix(5), "ふん")
        XCTAssertEqual(ClockTime.minuteSuffix(6), "ぷん")
        XCTAssertEqual(ClockTime.minuteSuffix(10), "ぷん")
        XCTAssertEqual(ClockTime.minuteSuffix(30), "ぷん")
        XCTAssertEqual(ClockTime.minuteSuffix(45), "ふん")
    }

    func testAcceptedSpokenFormsIncludeCommonReadings() {
        let forms = ClockTime(hour: 3, minute: 30).acceptedSpokenForms
        XCTAssertTrue(forms.contains("さんじはん"))
        XCTAssertTrue(forms.contains("3じはん"))
        XCTAssertTrue(forms.contains("さんじさんじゅうぷん"))

        let nine = ClockTime(hour: 9, minute: 0).acceptedSpokenForms
        XCTAssertTrue(nine.contains("くじ"))
        XCTAssertTrue(nine.contains("きゅうじ"))
    }
}
