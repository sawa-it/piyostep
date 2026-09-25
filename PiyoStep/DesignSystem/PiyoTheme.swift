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
struct PiyoBackground: View {
    var tint: Color = PiyoTheme.primary

    var body: some View {
        ZStack {
            PiyoTheme.background
            // やわらかい丸を散らして、余白が寂しくならないようにする。
            GeometryReader { proxy in
                let width = proxy.size.width
                let height = proxy.size.height
                Circle()
                    .fill(tint.opacity(0.10))
                    .frame(width: width * 0.9)
                    .position(x: width * 0.12, y: height * 0.08)
                Circle()
                    .fill(tint.opacity(0.07))
                    .frame(width: width * 0.7)
                    .position(x: width * 0.95, y: height * 0.85)
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
                    .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
            )
    }
}
