import SwiftUI
import UIKit
import PiyoCore

/// 画像アセットを持たずにイラストを出すための仕組み。
/// SF Symbols があればそれを使い、無ければ文字を大きく見せる。
enum IllustrationCatalog {

    /// かなの例語イラスト。候補の先頭から、存在するシンボルを使う。
    static let kanaSymbols: [String: [String]] = [
        "duck": ["bird.fill", "bird"],
        "dog": ["dog.fill", "pawprint.fill"],
        "horse": ["hare.fill"],
        "pencil": ["pencil"],
        "riceball": ["fork.knife"],
        "umbrella": ["umbrella.fill"],
        "giraffe": ["pawprint.fill"],
        "bear": ["teddybear.fill", "pawprint.fill"],
        "caterpillar": ["ladybug.fill", "ant.fill"],
        "spinningtop": ["circle.hexagongrid.fill"],
        "fish": ["fish.fill"],
        "zebra": ["pawprint.fill"],
        "watermelon": ["circle.fill"],
        "cicada": ["ant.fill"],
        "sled": ["snowflake"],
        "drum": ["circle.circle.fill"],
        "butterfly": ["ladybug.fill"],
        "moon": ["moon.fill"],
        "glove": ["hand.raised.fill"],
        "clock": ["clock.fill"],
        "eggplant": ["leaf.fill"],
        "carrot": ["carrot.fill", "leaf.fill"],
        "teddy": ["teddybear.fill"],
        "cat": ["cat.fill", "pawprint.fill"],
        "seaweed": ["leaf.fill"],
        "flower": ["camera.macro"],
        "airplane": ["airplane"],
        "ship": ["ferry.fill", "sailboat.fill"],
        "snake": ["scribble"],
        "star": ["star.fill"],
        "pillow": ["bed.double.fill"],
        "orange": ["circle.fill"],
        "bug": ["ant.fill"],
        "glasses": ["eyeglasses"],
        "peach": ["circle.fill"],
        "vegetable": ["carrot.fill", "leaf.fill"],
        "snow": ["snowflake"],
        "clothes": ["tshirt.fill"],
        "lion": ["pawprint.fill"],
        "apple": ["circle.fill"],
        "house": ["house.fill"],
        "fridge": ["refrigerator.fill", "square.fill"],
        "candle": ["flame.fill"],
        "crocodile": ["pawprint.fill"],
        "bread": ["birthday.cake.fill", "fork.knife"],
        "particle": ["textformat"]
    ]

    /// 英単語のイラスト。
    static let englishSymbols: [String: [String]] = [
        "apple": ["circle.fill"],
        "dog": ["dog.fill", "pawprint.fill"],
        "cat": ["cat.fill", "pawprint.fill"],
        "car": ["car.fill"],
        "sun": ["sun.max.fill"],
        "moon": ["moon.fill"],
        "red": ["paintpalette.fill"],
        "blue": ["paintpalette.fill"],
        "green": ["paintpalette.fill"],
        "yellow": ["paintpalette.fill"],
        "mom": ["figure.and.child.holdinghands", "person.fill"],
        "dad": ["figure.and.child.holdinghands", "person.fill"],
        "lion": ["pawprint.fill"],
        "fish": ["fish.fill"],
        "bird": ["bird.fill"],
        "egg": ["oval.fill"],
        "milk": ["cup.and.saucer.fill"],
        "ball": ["circle.fill"],
        "tree": ["tree.fill", "leaf.fill"],
        "star": ["star.fill"],
        "grape": ["circle.grid.2x2.fill"],
        "hat": ["graduationcap.fill"],
        "ice": ["snowflake"],
        "juice": ["cup.and.saucer.fill"],
        "key": ["key.fill"],
        "nose": ["face.smiling.inverse", "face.smiling"],
        "orange": ["circle.fill"],
        "pig": ["pawprint.fill"],
        "queen": ["crown.fill"],
        "umbrella": ["umbrella.fill"],
        "van": ["bus.fill", "car.fill"],
        "water": ["drop.fill"],
        "box": ["shippingbox.fill"],
        "zebra": ["pawprint.fill"]
    ]

    /// 数えるものの形。
    static let countableSymbols: [CountableObject: [String]] = [
        .apple: ["circle.fill"],
        .star: ["star.fill"],
        .fish: ["fish.fill"],
        .ball: ["circle.fill"],
        .candy: ["circle.hexagongrid.fill"],
        .flower: ["camera.macro"],
        .car: ["car.fill"],
        .bear: ["teddybear.fill", "pawprint.fill"]
    ]

    /// 数えるものの色。
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

    /// 端末に存在する最初のシンボル名を返す。
    static func firstAvailableSymbol(_ candidates: [String]) -> String? {
        candidates.first { UIImage(systemName: $0) != nil }
    }
}

/// シンボル or 文字でイラストを描く。
struct IllustrationView: View {
    var symbolCandidates: [String]
    /// シンボルが無いときに大きく出す文字（例語の 1 文字目）
    var fallbackText: String
    var tint: Color
    var size: CGFloat = 96

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.18))
            if let symbol = IllustrationCatalog.firstAvailableSymbol(symbolCandidates) {
                Image(systemName: symbol)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.24)
                    .foregroundStyle(tint)
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
                symbolCandidates: IllustrationCatalog.kanaSymbols[card.illustration] ?? [],
                fallbackText: String(card.word(for: subject).prefix(1)),
                tint: PiyoTheme.color(for: subject),
                size: size
            )
            if showsWord {
                Text(card.word(for: subject))
                    .font(PiyoTheme.bodyFont)
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
                symbolCandidates: IllustrationCatalog.englishSymbols[card.id] ?? [],
                fallbackText: String(card.english.prefix(1)).uppercased(),
                tint: PiyoTheme.color(for: .englishWord),
                size: size
            )
            if showsText {
                Text(card.english)
                    .font(PiyoTheme.bodyFont)
                    .foregroundStyle(PiyoTheme.text)
                Text(card.japanese)
                    .font(PiyoTheme.captionFont)
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

    private var columns: [GridItem] {
        let columnCount = min(maximumColumns, max(1, count))
        return Array(repeating: GridItem(.flexible(), spacing: 10), count: columnCount)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(0 ..< max(0, count), id: \.self) { index in
                Button {
                    onTap?(index)
                } label: {
                    IllustrationView(
                        symbolCandidates: IllustrationCatalog.countableSymbols[kind] ?? ["circle.fill"],
                        fallbackText: String(kind.childName.prefix(1)),
                        tint: IllustrationCatalog.color(for: kind),
                        size: itemSize
                    )
                    .overlay(
                        Circle()
                            .stroke(PiyoTheme.success, lineWidth: 4)
                            .opacity(tappedIndices.contains(index) ? 1 : 0)
                    )
                    .scaleEffect(tappedIndices.contains(index) ? 0.9 : 1)
                    .animation(.spring(response: 0.25, dampingFraction: 0.6), value: tappedIndices.contains(index))
                }
                .buttonStyle(.plain)
                .disabled(onTap == nil)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(kind.childName)が \(count)こ")
    }
}
