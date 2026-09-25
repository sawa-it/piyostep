import Foundation

/// ホームに出す「じぶんの アイコン」。
///
/// 写真を選んだ場合も、画像そのものは端末の中にだけ置き、ここにはファイル名だけを持つ。
/// （録音と同じく、子どもの写真を外へ送らないための切り分け。）
public enum ProfileAvatar: Hashable, Sendable {
    /// アプリに入っているキャラクターの絵を使う。
    case character(String)
    /// 端末に保存した写真を使う。
    case photo(String)

    public static let `default` = ProfileAvatar.character(CharacterCatalog.defaultCharacterID)

    /// 写真を使っているときだけファイル名を返す。
    public var photoFileName: String? {
        if case let .photo(name) = self { return name }
        return nil
    }

    /// キャラクターを使っているときだけ ID を返す。
    public var characterID: String? {
        if case let .character(id) = self { return id }
        return nil
    }
}

// MARK: - Codable

/// 保存形式は `{"kind": "photo", "value": "xxx.jpg"}`。
/// 将来ここに種類を足しても、古いアプリが読めずに落ちないようにしておく。
extension ProfileAvatar: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind
        case value
    }

    private enum Kind: String, Codable {
        case character
        case photo
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try? container.decode(Kind.self, forKey: .kind)
        let value = (try? container.decode(String.self, forKey: .value)) ?? ""
        switch kind {
        case .photo where !value.isEmpty:
            self = .photo(value)
        case .character where !value.isEmpty:
            self = .character(value)
        default:
            // 知らない種類・壊れた値は既定に倒す。アイコンのせいで遊べなくならないように。
            self = .default
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .character(id):
            try container.encode(Kind.character, forKey: .kind)
            try container.encode(id, forKey: .value)
        case let .photo(name):
            try container.encode(Kind.photo, forKey: .kind)
            try container.encode(name, forKey: .value)
        }
    }
}

// MARK: - 画像の保存先

/// アイコン画像の保存先。実体はファイル、テストではメモリ。
public protocol ProfileImageStoring: AnyObject {
    /// 画像を保存してファイル名を返す。
    func save(imageData: Data) -> String?
    func imageData(named name: String) -> Data?
    func delete(named name: String)
}

/// テスト・プレビュー用のインメモリ実装。
public final class InMemoryProfileImageStore: ProfileImageStoring {
    private var storage: [String: Data] = [:]
    private var counter = 0

    public init() {}

    public func save(imageData: Data) -> String? {
        guard !imageData.isEmpty else { return nil }
        counter += 1
        let name = "avatar-\(counter).jpg"
        storage[name] = imageData
        return name
    }

    public func imageData(named name: String) -> Data? { storage[name] }

    public func delete(named name: String) {
        storage.removeValue(forKey: name)
    }

    /// テストから保存件数を見るため。
    public var storedCount: Int { storage.count }
}

// MARK: - 写真の切り抜き

/// 写真から切り出す正方形。CoreGraphics に依存しないよう、素の数値で持つ。
public struct AvatarCropRect: Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let side: Double

    public init(x: Double, y: Double, side: Double) {
        self.x = x
        self.y = y
        self.side = side
    }

    public static let zero = AvatarCropRect(x: 0, y: 0, side: 0)
}

public enum AvatarImageGeometry {
    /// アイコンに使う一辺の長さ（px）。端末に置くだけなので大きすぎない値にする。
    public static let targetSide: Double = 512

    /// JPEG の品質。顔が分かれば十分なので欲張らない。
    public static let jpegQuality: Double = 0.8

    /// 画像の中央から正方形を切り出す。
    /// 縦長の写真は中央よりすこし上を採る（顔が上に写っていることが多いため）。
    public static func squareCropRect(width: Double, height: Double) -> AvatarCropRect {
        guard width > 0, height > 0 else { return .zero }
        let side = min(width, height)
        let originX = (width - side) / 2
        let originY: Double
        if height > width {
            // はみ出さないように 0 で止める。
            originY = max(0, (height - side) / 2 - side * 0.12)
        } else {
            originY = (height - side) / 2
        }
        return AvatarCropRect(x: originX, y: originY, side: side)
    }
}
