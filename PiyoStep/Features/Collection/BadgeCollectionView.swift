import SwiftUI
import PiyoCore

/// バッジ。集めたなかま・きせかえ・おさら・はいけい・バッジを、丸いバッジの形で並べて見せる。
struct BadgeCollectionView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.piyoLayout) private var layout

    @State private var selectedCategory: UnlockCategory = .character

    private var items: [UnlockableItem] {
        UnlockCatalog.items(in: selectedCategory)
    }

    private var unlockedCount: Int {
        UnlockCatalog.all.filter { environment.isUnlocked($0.id) }.count
    }

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: CGFloat(layout.sized(14))),
            count: layout.collectionColumns
        )
    }

    var body: some View {
        ZStack {
            PiyoBackground(tint: PiyoTheme.calm)

            VStack(spacing: 16) {
                header
                categoryPicker
                ScrollView {
                    LazyVGrid(columns: columns, spacing: CGFloat(layout.sized(14))) {
                        ForEach(items) { item in
                            itemCell(item)
                        }
                    }
                    .padding(.bottom, 24)
                }
                goalFooter
            }
            .padding(CGFloat(layout.spacing))
            .piyoContentWidth(layout)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.collection)
        .onAppear {
            environment.refreshProgress()
            environment.speak("バッジだよ")
        }
    }

    private var header: some View {
        HStack {
            BackCircleButton { dismiss() }
            Spacer()
            HStack(spacing: 10) {
                ArtImage(asset: .medal, size: CGFloat(layout.sized(40)))
                Text("バッジ")
                    .piyoFont(.title)
                    .foregroundStyle(PiyoTheme.text)
            }
            Spacer()
            // 集めた数。右端に置いて、戻るボタンと左右の釣り合いをとる。
            Text("\(unlockedCount) / \(UnlockCatalog.all.count)")
                .piyoFont(size: 15, weight: .bold)
                .foregroundStyle(PiyoTheme.textSoft)
                .monospacedDigit()
                .frame(width: 64, height: 64)
        }
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(UnlockCategory.allCases) { category in
                    Button {
                        selectedCategory = category
                        environment.haptics.tap()
                    } label: {
                        Text(category.childTitle)
                            .piyoFont(.body)
                            .foregroundStyle(selectedCategory == category ? .white : PiyoTheme.textSoft)
                            .padding(.horizontal, 20)
                            .frame(height: 56)
                            .background(
                                Capsule().fill(selectedCategory == category ? PiyoTheme.calm : PiyoTheme.surface)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func itemCell(_ item: UnlockableItem) -> some View {
        let unlocked = environment.isUnlocked(item.id)
        return VStack(spacing: 8) {
            BadgeView(item: item, isUnlocked: unlocked, size: CGFloat(layout.sized(112)))

            Text(unlocked ? item.name : "？？？")
                .piyoFont(size: 13, weight: .semibold)
                .foregroundStyle(unlocked ? PiyoTheme.text : PiyoTheme.textSoft)
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            if !unlocked {
                Text(item.condition.childDescription)
                    .piyoFont(size: 11, weight: .medium)
                    .foregroundStyle(PiyoTheme.textSoft)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("\(A11yID.collectionItem)\(item.id)")
        .accessibilityLabel(unlocked ? item.name : "まだ ひみつ")
    }

    private var goalFooter: some View {
        Group {
            if let goal = environment.nextUnlockGoal {
                PiyoCard(padding: 14) {
                    HStack(spacing: 12) {
                        ArtImage(asset: .glowingStar, size: 34)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("つぎの おたのしみ")
                                .piyoFont(size: 13, weight: .semibold)
                                .foregroundStyle(PiyoTheme.textSoft)
                            Text(goal.condition.childDescription)
                                .piyoFont(.body)
                                .foregroundStyle(PiyoTheme.text)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }
}

/// 丸いバッジ。金色のふちどりとリボンが付いた、胸につける缶バッジの形。
/// まだ手に入れていないものは、灰色でカギを見せる。
struct BadgeView: View {
    var item: UnlockableItem
    var isUnlocked: Bool
    var size: CGFloat = 112

    private var ringColors: [Color] {
        if !isUnlocked {
            return [Color(red: 0.86, green: 0.84, blue: 0.80), Color(red: 0.74, green: 0.72, blue: 0.68)]
        }
        switch item.category {
        case .character: return [Color(red: 1.0, green: 0.85, blue: 0.40), Color(red: 0.93, green: 0.62, blue: 0.16)]
        case .costume: return [Color(red: 0.98, green: 0.70, blue: 0.82), Color(red: 0.90, green: 0.42, blue: 0.62)]
        case .tableware: return [Color(red: 0.72, green: 0.90, blue: 0.78), Color(red: 0.36, green: 0.72, blue: 0.50)]
        case .background: return [Color(red: 0.72, green: 0.86, blue: 1.0), Color(red: 0.38, green: 0.62, blue: 0.92)]
        case .badge: return [Color(red: 1.0, green: 0.85, blue: 0.40), Color(red: 0.93, green: 0.62, blue: 0.16)]
        }
    }

    var body: some View {
        ZStack {
            // リボン。バッジの下から 2 本のぞく。
            RibbonTails()
                .fill(
                    LinearGradient(
                        colors: isUnlocked
                            ? [Color(red: 0.96, green: 0.36, blue: 0.40), Color(red: 0.80, green: 0.20, blue: 0.28)]
                            : [Color(red: 0.80, green: 0.78, blue: 0.75), Color(red: 0.68, green: 0.66, blue: 0.62)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.62, height: size * 0.42)
                .offset(y: size * 0.36)

            // 外側のギザギザのふち。
            ScallopedCircle(bumps: 18)
                .fill(
                    LinearGradient(colors: ringColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: size, height: size)
                .shadow(color: PiyoTheme.shadow.opacity(isUnlocked ? 0.22 : 0.10), radius: size * 0.07, y: size * 0.05)

            // 内側の白い面。
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white, Color(red: 0.97, green: 0.96, blue: 0.93)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.78, height: size * 0.78)
            Circle()
                .stroke(Color.white.opacity(0.9), lineWidth: max(1.5, size * 0.02))
                .frame(width: size * 0.84, height: size * 0.84)

            if isUnlocked {
                UnlockableItemArtView(item: item, size: size * 0.58)
            } else {
                ArtImage(asset: .locked, size: size * 0.36)
                    .saturation(0.2)
                    .opacity(0.8)
            }

            // 上のハイライト。缶バッジの光沢。
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.55), Color.white.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size * 0.56, height: size * 0.26)
                .offset(y: -size * 0.24)
                .allowsHitTesting(false)
        }
        .frame(width: size, height: size * 1.2)
        .saturation(isUnlocked ? 1 : 0.15)
        .accessibilityHidden(true)
    }
}

/// ふちがギザギザの丸。
private struct ScallopedCircle: Shape {
    var bumps: Int

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * 0.92
        let steps = bumps * 12
        for step in 0 ... steps {
            let angle = Double(step) / Double(steps) * 2 * .pi
            let wave = 0.5 + 0.5 * cos(angle * Double(bumps))
            let radius = inner + (outer - inner) * CGFloat(wave)
            let point = CGPoint(x: center.x + radius * CGFloat(cos(angle)), y: center.y + radius * CGFloat(sin(angle)))
            if step == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

/// バッジの下からのぞく 2 本のリボン。先は燕尾に切る。
private struct RibbonTails: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let tailWidth = rect.width * 0.36
        let notch = rect.height * 0.22
        for side in [-1.0, 1.0] {
            let centerX = rect.midX + CGFloat(side) * rect.width * 0.20
            let left = centerX - tailWidth / 2
            let right = centerX + tailWidth / 2
            path.move(to: CGPoint(x: left, y: rect.minY))
            path.addLine(to: CGPoint(x: right, y: rect.minY))
            path.addLine(to: CGPoint(x: right + CGFloat(side) * rect.width * 0.04, y: rect.maxY))
            path.addLine(to: CGPoint(x: centerX + CGFloat(side) * rect.width * 0.02, y: rect.maxY - notch))
            path.addLine(to: CGPoint(x: left + CGFloat(side) * rect.width * 0.04, y: rect.maxY))
            path.closeSubpath()
        }
        return path
    }
}

#Preview {
    HStack(spacing: 16) {
        BadgeView(item: UnlockCatalog.all[0], isUnlocked: true)
        BadgeView(item: UnlockCatalog.items(in: .badge)[0], isUnlocked: true)
        BadgeView(item: UnlockCatalog.items(in: .badge)[1], isUnlocked: false)
    }
    .padding()
    .background(PiyoTheme.background)
}
