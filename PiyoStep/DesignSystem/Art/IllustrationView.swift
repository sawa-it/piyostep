import SwiftUI
import PiyoCore

/// 数えるものの色（背景の丸に使う）。
enum IllustrationPalette {
    static func color(for object: CountableObject) -> Color {
        switch object {
        case .apple: return Color(red: 0.90, green: 0.32, blue: 0.30)
        case .star: return Color(red: 0.99, green: 0.76, blue: 0.20)
        case .fish: return Color(red: 0.29, green: 0.64, blue: 0.87)
        case .ball: return Color(red: 0.42, green: 0.74, blue: 0.47)
        case .candy: return Color(red: 0.93, green: 0.50, blue: 0.73)
        case .flower: return Color(red: 0.86, green: 0.44, blue: 0.84)
        case .car: return Color(red: 0.36, green: 0.55, blue: 0.90)
        case .bear: return Color(red: 0.74, green: 0.58, blue: 0.44)
        }
    }
}

/// 丸い台の上にイラストを置く。絵が無いときは文字を大きく見せる。
///
/// 台は上を明るくした色の面にして、絵に薄い影を落とす。
/// 平らな単色の丸に置くより、絵が「そこにある」ように見える。
struct IllustrationView: View {
    var asset: ArtAsset?
    /// 絵が無いときに大きく出す文字（例語の 1 文字目）
    var fallbackText: String
    var tint: Color
    var size: CGFloat = 96
    /// 出たときに小さくはずむ。
    var popsIn: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    private var shouldPop: Bool {
        popsIn && !PiyoMotion.isReduced(accessibilityReduceMotion: reduceMotion)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.10), tint.opacity(0.26)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            Circle()
                .stroke(tint.opacity(0.22), lineWidth: max(1.5, size * 0.02))

            if let asset, asset.exists {
                ArtImage(asset: asset, size: size * 0.70)
                    .shadow(color: PiyoTheme.shadow.opacity(0.18), radius: size * 0.05, y: size * 0.04)
            } else {
                Text(fallbackText)
                    .font(PiyoTheme.childFont(size: size * 0.46, weight: .heavy))
                    .foregroundStyle(tint)
                    .minimumScaleFactor(0.4)
                    .lineLimit(1)
                    .padding(size * 0.12)
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(shouldPop && !hasAppeared ? 0.6 : 1)
        .opacity(shouldPop && !hasAppeared ? 0 : 1)
        .onAppear {
            guard shouldPop else { return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.62)) {
                hasAppeared = true
            }
        }
    }
}

/// かなの例語カード（イラスト + ことば）。
struct KanaWordIllustration: View {
    var card: KanaCard
    var subject: Subject
    var size: CGFloat = 96
    var showsWord: Bool = true

    var body: some View {
        VStack(spacing: 8) {
            IllustrationView(
                asset: ArtCatalog.kanaWord(card: card, subject: subject),
                fallbackText: String(card.word(for: subject).prefix(1)),
                tint: PiyoTheme.color(for: subject),
                size: size
            )
            if showsWord {
                Text(card.word(for: subject))
                    .piyoFont(.body)
                    .foregroundStyle(PiyoTheme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
    }
}

/// 英単語カード（イラスト + つづり + 日本語）。
struct EnglishWordIllustration: View {
    var card: EnglishWordCard
    var size: CGFloat = 96
    var showsText: Bool = true

    var body: some View {
        VStack(spacing: 6) {
            IllustrationView(
                asset: ArtCatalog.english[card.illustration],
                fallbackText: String(card.english.prefix(1)).uppercased(),
                tint: PiyoTheme.color(for: .englishWord),
                size: size
            )
            if showsText {
                Text(card.english)
                    .piyoFont(.body)
                    .foregroundStyle(PiyoTheme.text)
                Text(card.japanese)
                    .piyoFont(.caption)
                    .foregroundStyle(PiyoTheme.textSoft)
            }
        }
    }
}

/// ものを並べて数えさせる表示。
struct CountableObjectsView: View {
    var kind: CountableObject
    var count: Int
    var maximumColumns: Int = 5
    var itemSize: CGFloat = 52
    /// タップして数えた印を付ける
    var tappedIndices: Set<Int> = []
    var onTap: ((Int) -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appearedCount = 0

    private var columns: [GridItem] {
        let columnCount = min(maximumColumns, max(1, count))
        return Array(repeating: GridItem(.flexible(), spacing: 10), count: columnCount)
    }

    private var shouldStagger: Bool {
        onTap != nil && !PiyoMotion.isReduced(accessibilityReduceMotion: reduceMotion)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(0 ..< max(0, count), id: \.self) { index in
                Button {
                    onTap?(index)
                } label: {
                    item(index: index)
                }
                .buttonStyle(.plain)
                .disabled(onTap == nil)
            }
        }
        .onAppear {
            guard shouldStagger else {
                appearedCount = count
                return
            }
            // ひとつずつ順に出すと、数えるものの「数」に目が向く。
            for index in 0 ..< max(0, count) {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.62).delay(Double(index) * 0.05)) {
                    appearedCount = index + 1
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(kind.childName)が \(count)こ")
    }

    private func item(index: Int) -> some View {
        let isCounted = tappedIndices.contains(index)
        let isVisible = !shouldStagger || index < appearedCount
        return ZStack {
            IllustrationView(
                asset: ArtCatalog.countable(kind),
                fallbackText: String(kind.childName.prefix(1)),
                tint: IllustrationPalette.color(for: kind),
                size: itemSize,
                popsIn: false
            )
            .saturation(isCounted ? 0.55 : 1)
            .overlay(
                Circle()
                    .stroke(PiyoTheme.success, lineWidth: max(3, itemSize * 0.07))
                    .opacity(isCounted ? 1 : 0)
            )
            // 数えた印。丸の右上に小さく出す。
            if isCounted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: max(14, itemSize * 0.34), weight: .bold))
                    .foregroundStyle(.white, PiyoTheme.success)
                    .offset(x: itemSize * 0.34, y: -itemSize * 0.34)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .scaleEffect(isVisible ? (isCounted ? 0.92 : 1) : 0.4)
        .opacity(isVisible ? 1 : 0)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isCounted)
    }
}
