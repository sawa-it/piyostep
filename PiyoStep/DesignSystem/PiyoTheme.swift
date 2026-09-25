import SwiftUI
import PiyoCore

/// 明るく・やわらかく・ごちゃごちゃしない配色とタイポグラフィ。
enum PiyoTheme {

    // MARK: - 色

    static let background = Color(red: 1.00, green: 0.98, blue: 0.93)
    static let surface = Color.white
    static let surfaceSunken = Color(red: 0.97, green: 0.95, blue: 0.90)
    static let primary = Color(red: 1.00, green: 0.62, blue: 0.29)
    static let primaryDeep = Color(red: 0.93, green: 0.45, blue: 0.18)
    static let text = Color(red: 0.26, green: 0.22, blue: 0.18)
    static let textSoft = Color(red: 0.48, green: 0.43, blue: 0.38)
    static let success = Color(red: 0.36, green: 0.75, blue: 0.45)
    static let cheer = Color(red: 0.99, green: 0.78, blue: 0.24)
    static let calm = Color(red: 0.42, green: 0.69, blue: 0.93)
    static let outline = Color(red: 0.86, green: 0.82, blue: 0.75)
    /// 影の色。黒をそのまま使うと濁るので、少し暖色に寄せる。
    static let shadow = Color(red: 0.36, green: 0.26, blue: 0.16)

    /// 教科ごとの色。
    static func color(for subject: Subject) -> Color {
        switch subject {
        case .clock: return Color(red: 0.42, green: 0.69, blue: 0.93)
        case .hiragana: return Color(red: 0.98, green: 0.55, blue: 0.55)
        case .katakana: return Color(red: 0.71, green: 0.56, blue: 0.91)
        case .number: return Color(red: 0.36, green: 0.75, blue: 0.55)
        case .alphabet: return Color(red: 0.99, green: 0.72, blue: 0.25)
        case .englishWord: return Color(red: 0.36, green: 0.72, blue: 0.80)
        }
    }

    /// 16 進表記（キャラクター定義）から色をつくる。
    static func color(hex: String) -> Color {
        var value = hex
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let number = UInt32(value, radix: 16) else {
            return primary
        }
        return Color(
            red: Double((number >> 16) & 0xFF) / 255.0,
            green: Double((number >> 8) & 0xFF) / 255.0,
            blue: Double(number & 0xFF) / 255.0
        )
    }

    /// キーから安定したパステルカラーをつくる（イラストの背景に使う）。
    static func pastel(for key: String) -> Color {
        var hash: UInt64 = 5381
        for byte in key.utf8 {
            hash = (hash &* 33) &+ UInt64(byte)
        }
        let hue = Double(hash % 360) / 360.0
        return Color(hue: hue, saturation: 0.35, brightness: 0.97)
    }

    // MARK: - フォント

    /// 子ども向けはすべて丸ゴシック。
    static func childFont(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    // 役割ごとの大きさは画面の形で変わるので `.piyoFont(.title)` を使う。
    // ここに固定値の Font を置くと、iPad や横向きで大きさが追従しなくなる。

    // MARK: - 形

    static let cornerRadius: CGFloat = 28
    static let smallCornerRadius: CGFloat = 18
    // タップ領域と余白は画面の広さで変わるので `LayoutMetrics` が持つ。
    // 固定値をここに置くと、iPad で小さいままになる。
}

/// 画面全体の背景。
///
/// 上をわずかに明るく、下を教科の色に寄せる。べた塗りだと平坦に見え、
/// 逆に模様を増やすと、幼児には「押せるもの」との区別がつかなくなる。
struct PiyoBackground: View {
    var tint: Color = PiyoTheme.primary

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    PiyoTheme.background,
                    PiyoTheme.background,
                    tint.opacity(0.14)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // やわらかい丸を散らして、余白が寂しくならないようにする。
            GeometryReader { proxy in
                let width = proxy.size.width
                let height = proxy.size.height
                Circle()
                    .fill(tint.opacity(0.10))
                    .frame(width: width * 0.62)
                    .blur(radius: 18)
                    .position(x: width * 0.10, y: height * 0.06)
                Circle()
                    .fill(PiyoTheme.cheer.opacity(0.10))
                    .frame(width: width * 0.40)
                    .blur(radius: 22)
                    .position(x: width * 0.92, y: height * 0.90)
            }
        }
        .ignoresSafeArea()
    }
}

/// 白いカード。
struct PiyoCard<Content: View>: View {
    var padding: CGFloat = 20
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: PiyoTheme.cornerRadius, style: .continuous)
                    .fill(PiyoTheme.surface)
                    .shadow(color: PiyoTheme.shadow.opacity(0.10), radius: 18, x: 0, y: 8)
            )
            .overlay(
                // 白い背景に白いカードが重なるので、ごく薄い縁で境目を出す。
                RoundedRectangle(cornerRadius: PiyoTheme.cornerRadius, style: .continuous)
                    .stroke(PiyoTheme.outline.opacity(0.45), lineWidth: 1)
            )
    }
}
