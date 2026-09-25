import Foundation

/// 現在時刻の供給源。テストで固定できるように抽象化する。
public protocol ClockProviding: AnyObject {
    var now: Date { get }
}

public final class SystemClock: ClockProviding {
    public init() {}
    public var now: Date { Date() }
}

/// テスト用。`now` を明示的に進められる。
public final class MutableClock: ClockProviding {
    private var current: Date

    public init(now: Date = Date(timeIntervalSince1970: 1_700_000_000)) {
        self.current = now
    }

    public var now: Date { current }

    public func set(_ date: Date) {
        current = date
    }

    public func advance(by interval: TimeInterval) {
        current = current.addingTimeInterval(interval)
    }
}

extension Calendar {
    /// アプリ全体で使う日本時間ベースのカレンダー。
    public static var piyo: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo") ?? TimeZone(secondsFromGMT: 9 * 3600)!
        calendar.locale = Locale(identifier: "ja_JP")
        return calendar
    }
}
