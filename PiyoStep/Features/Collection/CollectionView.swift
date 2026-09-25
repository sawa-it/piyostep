import SwiftUI
import PiyoCore

/// ずかん。集めたキャラクター・きせかえ・おさら・はいけい・スタンプを見せる。
struct CollectionView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.piyoLayout) private var layout

    @State private var selectedCategory: UnlockCategory = .character

    private var items: [UnlockableItem] {
        UnlockCatalog.items(in: selectedCategory)
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
            environment.speak("ずかんだよ")
        }
    }

    private var header: some View {
        HStack {
            BackCircleButton { dismiss() }
            Spacer()
            Text("ずかん")
                .piyoFont(.title)
                .foregroundStyle(PiyoTheme.text)
            Spacer()
            Color.clear.frame(width: 64, height: 64)
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
            ZStack {
                RoundedRectangle(cornerRadius: PiyoTheme.smallCornerRadius)
                    .fill(unlocked ? PiyoTheme.surface : PiyoTheme.surfaceSunken)
                    .frame(height: 104)

                if unlocked {
                    unlockedArt(item)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(PiyoTheme.outline)
                }
            }

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
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("\(A11yID.collectionItem)\(item.id)")
        .accessibilityLabel(unlocked ? item.name : "まだ ひみつ")
    }

    @ViewBuilder
    private func unlockedArt(_ item: UnlockableItem) -> some View {
        switch item.category {
        case .character:
            if let character = CharacterCatalog.character(id: item.artKey) {
                CharacterArtView(character: character, mood: .idle, size: 80, isAnimated: false)
            }
        case .costume:
            CharacterArtView(
                character: environment.buddyCharacter,
                mood: .happy,
                size: 80,
                costumeArtKey: item.artKey,
                isAnimated: false
            )
        case .tableware:
            PlateView(fullness: 0.6, tablewareArtKey: item.artKey, size: 84)
        case .background:
            RoundedRectangle(cornerRadius: 12)
                .fill(PiyoTheme.pastel(for: item.artKey))
                .frame(width: 80, height: 60)
                .overlay(
                    Image(systemName: backgroundSymbol(item.artKey))
                        .font(.system(size: 26))
                        .foregroundStyle(PiyoTheme.textSoft)
                )
        case .stamp:
            Image(systemName: stampSymbol(item.artKey))
                .font(.system(size: 42))
                .foregroundStyle(PiyoTheme.cheer)
        }
    }

    private func backgroundSymbol(_ key: String) -> String {
        switch key {
        case "park": return "tree.fill"
        case "sea": return "water.waves"
        case "space": return "moon.stars.fill"
        case "night": return "moon.fill"
        default: return "sun.max.fill"
        }
    }

    private func stampSymbol(_ key: String) -> String {
        switch key {
        case "heart": return "heart.fill"
        case "medal": return "medal.fill"
        case "trophy": return "trophy.fill"
        case "rainbow": return "rainbow"
        default: return "star.fill"
        }
    }

    private var goalFooter: some View {
        Group {
            if let goal = environment.nextUnlockGoal {
                PiyoCard(padding: 14) {
                    HStack(spacing: 12) {
                        Image(systemName: "target")
                            .font(.system(size: 22))
                            .foregroundStyle(PiyoTheme.primary)
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
