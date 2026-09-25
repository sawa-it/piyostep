import Foundation

/// アナログ時計の時刻（12 時間表記）。
public struct ClockTime: Hashable, Codable, Sendable, CustomStringConvertible {
    /// 1 ... 12
    public let hour: Int
    /// 0 ... 59
    public let minute: Int

    public init(hour: Int, minute: Int) {
        let normalizedMinute = ((minute % 60) + 60) % 60
        var normalizedHour = ((hour % 12) + 12) % 12
        if normalizedHour == 0 { normalizedHour = 12 }
        self.hour = normalizedHour
        self.minute = normalizedMinute
    }

    public var description: String { "\(hour):\(String(format: "%02d", minute))" }

    /// 読み上げ用テキスト。漢字で書くと TTS が自然な読み（さんじさんじゅっぷん）を選ぶ。
    public var spokenJapanese: String {
        minute == 0 ? "\(hour)時" : "\(hour)時\(minute)分"
    }

    /// 音声認識の正解候補として受け入れるひらがな表記の一覧。
    public var acceptedSpokenForms: [String] {
        let hourReadings = JapaneseNumberParser.readings(for: hour)
        var results: [String] = []
        if minute == 0 {
            for hourText in hourReadings {
                results.append("\(hourText)じ")
                results.append("\(hourText)じちょうど")
            }
            results.append("\(hour)じ")
            return results
        }

        var minuteTexts = JapaneseNumberParser.readings(for: minute).map {
            "\($0)\(ClockTime.minuteSuffix(minute))"
        }
        minuteTexts.append("\(minute)\(ClockTime.minuteSuffix(minute))")
        if minute == 30 {
            minuteTexts.append("はん")
        }
        for hourText in hourReadings + ["\(hour)"] {
            for minuteText in minuteTexts {
                results.append("\(hourText)じ\(minuteText)")
            }
        }
        return results
    }

    /// 画面表示用（「3じ30ふん」）。
    public var displayJapanese: String {
        minute == 0 ? "\(hour)じ" : "\(hour)じ\(minute)ふん"
    }

    /// 短針の角度（12時＝0度、時計回り）。分による進みも含む。
    public var hourHandAngleDegrees: Double {
        let hourComponent = Double(hour % 12)
        return hourComponent * 30.0 + Double(minute) * 0.5
    }

    /// 長針の角度（12時＝0度、時計回り）。
    public var minuteHandAngleDegrees: Double {
        Double(minute) * 6.0
    }

    /// 0 時基準の総分数（0 ... 719）。
    public var totalMinutes: Int {
        (hour % 12) * 60 + minute
    }

    public static func fromTotalMinutes(_ minutes: Int) -> ClockTime {
        let normalized = ((minutes % 720) + 720) % 720
        return ClockTime(hour: normalized / 60, minute: normalized % 60)
    }

    /// 針の角度から時刻を復元する。`minuteStep` に丸める。
    public static func fromHandAngles(
        hourAngleDegrees: Double,
        minuteAngleDegrees: Double,
        minuteStep: Int
    ) -> ClockTime {
        let step = max(1, minuteStep)
        let normalizedMinuteAngle = normalizeDegrees(minuteAngleDegrees)
        let rawMinute = normalizedMinuteAngle / 6.0
        var minute = Int((rawMinute / Double(step)).rounded()) * step
        if minute >= 60 { minute -= 60 }

        // 長針と短針は独立にドラッグできるので、「時」は短針だけから決める。
        let normalizedHourAngle = normalizeDegrees(hourAngleDegrees)
        var hourIndex = Int((normalizedHourAngle / 30.0).rounded(.down))
        let withinHour = normalizedHourAngle - Double(hourIndex) * 30.0
        // 次の時間の直前に置かれていて、長針も 0 分付近なら繰り上げる（幼児の操作に寛容にする）。
        if withinHour > 27.5 && minute < 5 {
            hourIndex += 1
        }
        hourIndex %= 12
        let hour = hourIndex == 0 ? 12 : hourIndex
        return ClockTime(hour: hour, minute: minute)
    }

    public static func normalizeDegrees(_ degrees: Double) -> Double {
        var value = degrees.truncatingRemainder(dividingBy: 360)
        if value < 0 { value += 360 }
        return value
    }

    /// 許容誤差（分）以内で一致するか。
    public func matches(_ other: ClockTime, toleranceMinutes: Int = 0) -> Bool {
        guard toleranceMinutes > 0 else { return self == other }
        let diff = abs(totalMinutes - other.totalMinutes)
        let circularDiff = min(diff, 720 - diff)
        return circularDiff <= toleranceMinutes
    }

    // MARK: - 読み

    static let hourReadings: [Int: String] = [
        1: "いち", 2: "に", 3: "さん", 4: "よ", 5: "ご", 6: "ろく",
        7: "しち", 8: "はち", 9: "く", 10: "じゅう", 11: "じゅういち", 12: "じゅうに"
    ]

    public static func hourReading(_ hour: Int) -> String {
        hourReadings[hour] ?? "\(hour)"
    }

    /// 「30ぷん」「15ふん」など、分の読みを返す。
    public static func minuteReading(_ minute: Int) -> String {
        if minute == 30 { return "はん" }
        let suffix = minuteSuffix(minute)
        return "\(JapaneseNumberParser.reading(for: minute))\(suffix)"
    }

    /// 「ふん」/「ぷん」の使い分け。1,3,4,6,8 と 10 の倍数は「ぷん」。
    public static func minuteSuffix(_ minute: Int) -> String {
        let ones = minute % 10
        if ones == 0 { return "ぷん" }
        return [1, 3, 4, 6, 8].contains(ones) ? "ぷん" : "ふん"
    }
}
