import SwiftUI
import PiyoCore

/// アナログ時計。読み取り専用にも、針をドラッグできるようにもできる。
///
/// 針は本物の時計のようにつながっている。長い針を 1 周まわすと短い針が 1 時間ぶん進む。
/// 2 本の針を別々に合わせるのは幼児には難しく、長い針だけをぐるぐる回して
/// 目当ての時刻に持っていけるほうが、時計のしくみの理解にもつながる。
struct AnalogClockView: View {
    var time: ClockTime
    var isInteractive: Bool = false
    var minuteStep: Int = 5
    var showsNumbers: Bool = true
    var size: CGFloat = 280
    var onChange: ((ClockTime) -> Void)? = nil

    /// 0 時からの通算分。ドラッグ中は小数で持ち、指の動きにそのまま追従させる。
    @State private var totalMinutes: Double = 0
    @State private var draggingHand: Hand?
    @State private var lastDragAngle: Double = 0

    enum Hand {
        case hour
        case minute
    }

    /// 現在表示している時刻（刻みに丸めたもの）。
    private var displayedTime: ClockTime {
        guard isInteractive else { return time }
        return AnalogClockView.snapped(totalMinutes: totalMinutes, step: minuteStep)
    }

    private var hourAngle: Double {
        guard isInteractive else { return time.hourHandAngleDegrees }
        return ClockTime.normalizeDegrees(totalMinutes / 2)
    }

    private var minuteAngle: Double {
        guard isInteractive else { return time.minuteHandAngleDegrees }
        return ClockTime.normalizeDegrees(totalMinutes * 6)
    }

    var body: some View {
        ZStack {
            face
            ticks
            if showsNumbers { numbers }
            hand(
                length: size * 0.26,
                width: size * 0.06,
                angle: hourAngle,
                color: PiyoTheme.primaryDeep,
                identifier: A11yID.sessionClockHourHand
            )
            hand(
                length: size * 0.38,
                width: size * 0.04,
                angle: minuteAngle,
                color: PiyoTheme.calm,
                identifier: A11yID.sessionClockMinuteHand
            )
            Circle()
                .fill(PiyoTheme.text)
                .frame(width: size * 0.07)
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .gesture(dragGesture, including: isInteractive ? .all : .subviews)
        .onAppear(perform: syncFromTime)
        .onChange(of: time) { _, _ in syncFromTime() }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(A11yID.sessionClockFace)
        .accessibilityLabel(Text(displayedTime.displayJapanese))
    }

    // MARK: - 部品

    private var face: some View {
        ZStack {
            Circle()
                .fill(PiyoTheme.surface)
                .shadow(color: .black.opacity(0.08), radius: 10, y: 5)
            Circle()
                .stroke(PiyoTheme.primary.opacity(0.5), lineWidth: size * 0.03)
        }
    }

    private var ticks: some View {
        ForEach(0 ..< 60, id: \.self) { index in
            let isHour = index % 5 == 0
            Capsule()
                .fill(isHour ? PiyoTheme.textSoft : PiyoTheme.outline)
                .frame(width: isHour ? size * 0.012 : size * 0.006,
                       height: isHour ? size * 0.05 : size * 0.026)
                .offset(y: -size * 0.43)
                .rotationEffect(.degrees(Double(index) * 6))
        }
    }

    private var numbers: some View {
        ForEach(1 ... 12, id: \.self) { hour in
            let angle = Double(hour) * .pi / 6
            Text("\(hour)")
                .font(PiyoTheme.childFont(size: size * 0.11))
                .foregroundStyle(PiyoTheme.text)
                .offset(
                    x: CGFloat(sin(angle)) * size * 0.345,
                    y: CGFloat(-cos(angle)) * size * 0.345
                )
        }
    }

    private func hand(
        length: CGFloat,
        width: CGFloat,
        angle: Double,
        color: Color,
        identifier: String
    ) -> some View {
        Capsule()
            .fill(color)
            .frame(width: width, height: length)
            .offset(y: -length / 2)
            .rotationEffect(.degrees(angle))
            // ドラッグ中は指にぴったり付ける。離したときだけ、刻みに揃う動きを見せる。
            .animation(draggingHand == nil ? .spring(response: 0.2, dampingFraction: 0.8) : nil, value: angle)
            .accessibilityIdentifier(identifier)
    }

    // MARK: - ドラッグ

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // CGFloat と Double が混ざると演算子の解決が曖昧になるので、
                // 角度の計算はすべて Double に寄せる。
                let center = CGPoint(x: size / 2, y: size / 2)
                let dx = Double(value.location.x - center.x)
                let dy = Double(value.location.y - center.y)
                let radius = (dx * dx + dy * dy).squareRoot()
                guard radius > Double(size) * 0.05 else { return }

                let angle = ClockTime.normalizeDegrees(atan2(dx, -dy) * 180.0 / .pi)

                if draggingHand == nil {
                    let hand = closestHand(to: angle, radius: radius)
                    draggingHand = hand
                    // つかんだ針のいまの角度から測り始める。最初の一回で針が指に飛びつく。
                    lastDragAngle = hand == .minute ? minuteAngle : hourAngle
                }
                let delta = AnalogClockView.signedDelta(from: lastDragAngle, to: angle)
                lastDragAngle = angle
                switch draggingHand {
                case .minute:
                    // 長い針 6 度 = 1 分。短い針もつられて進む。
                    totalMinutes = AnalogClockView.wrap(totalMinutes + delta / 6)
                case .hour:
                    // 短い針 30 度 = 60 分。
                    totalMinutes = AnalogClockView.wrap(totalMinutes + delta * 2)
                case .none:
                    break
                }
                onChange?(displayedTime)
            }
            .onEnded { _ in
                draggingHand = nil
                // 指を離したら、丸められた位置に針を揃える。
                let snapped = displayedTime
                totalMinutes = Double(snapped.totalMinutes)
                onChange?(snapped)
            }
    }

    /// 触った場所に近いほうの針を掴む。
    private func closestHand(to angle: Double, radius: Double) -> Hand {
        let hourDelta = angularDistance(angle, hourAngle)
        let minuteDelta = angularDistance(angle, minuteAngle)

        // 外周に近いところを触ったら、長い針（分）を優先する。
        if radius > Double(size) * 0.30 {
            return minuteDelta < 50 ? .minute : (hourDelta < minuteDelta ? .hour : .minute)
        }
        return hourDelta <= minuteDelta ? .hour : .minute
    }

    private func angularDistance(_ lhs: Double, _ rhs: Double) -> Double {
        let diff = abs(ClockTime.normalizeDegrees(lhs) - ClockTime.normalizeDegrees(rhs))
        return min(diff, 360 - diff)
    }

    private func syncFromTime() {
        // ドラッグ中に親から同じ値が戻ってきても、指の位置を崩さない。
        guard draggingHand == nil else { return }
        if displayedTime != time || !isInteractive {
            totalMinutes = Double(time.totalMinutes)
        }
    }

    // MARK: - 計算（テストしやすいように static）

    /// -180 〜 180 の範囲で、`from` から `to` への最短の回転角を返す。
    static func signedDelta(from: Double, to: Double) -> Double {
        var delta = ClockTime.normalizeDegrees(to) - ClockTime.normalizeDegrees(from)
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        return delta
    }

    /// 0 以上 720 未満に収める。
    static func wrap(_ minutes: Double) -> Double {
        var value = minutes.truncatingRemainder(dividingBy: 720)
        if value < 0 { value += 720 }
        return value
    }

    /// 通算分を、分の刻みに丸めた時刻にする。
    static func snapped(totalMinutes: Double, step: Int) -> ClockTime {
        let stepValue = max(1, step)
        let total = Int(wrap(totalMinutes).rounded())
        let hourIndex = total / 60
        let minute = total % 60
        var snappedMinute = Int((Double(minute) / Double(stepValue)).rounded()) * stepValue
        var hour = hourIndex
        if snappedMinute >= 60 {
            snappedMinute -= 60
            hour += 1
        }
        return ClockTime.fromTotalMinutes(hour * 60 + snappedMinute)
    }
}

/// 時計を小さく出すだけの表示（選択肢用）。
struct MiniClockView: View {
    var time: ClockTime
    var size: CGFloat = 76

    var body: some View {
        AnalogClockView(
            time: time,
            isInteractive: false,
            showsNumbers: false,
            size: size
        )
    }
}
