import SwiftUI
import PiyoCore

/// 「じぶんの アイコン」。写真を選んでいれば写真、無ければキャラクターの絵。
struct AvatarView: View {
    var avatar: ProfileAvatar
    /// 写真の中身。読み込みは呼び出し側で行う（View を単純に保つため）。
    var photoData: Data?
    var size: CGFloat = 72
    var isAnimated: Bool = false

    private var character: CharacterDefinition {
        CharacterCatalog.character(id: avatar.characterID ?? "") ?? CharacterCatalog.fallback
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(PiyoTheme.surface)

            if let image = photoImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                CharacterArtView(
                    character: character,
                    mood: .idle,
                    size: size * 0.86,
                    isAnimated: isAnimated
                )
            }
        }
        .frame(width: size, height: size)
        .overlay(
            Circle().stroke(PiyoTheme.outline, lineWidth: max(2, size * 0.03))
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(photoImage == nil ? character.name : "じぶんの しゃしん")
        .accessibilityIdentifier(A11yID.avatar)
    }

    private var photoImage: UIImage? {
        guard case .photo = avatar, let photoData else { return nil }
        return UIImage(data: photoData)
    }
}

#Preview {
    HStack(spacing: 20) {
        AvatarView(avatar: .character(CharacterCatalog.defaultCharacterID), photoData: nil)
        AvatarView(avatar: .character(CharacterCatalog.defaultCharacterID), photoData: nil, size: 120)
    }
    .padding()
    .background(PiyoTheme.background)
}
