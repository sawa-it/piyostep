import Foundation
import UIKit
import PiyoCore

/// アイコン画像を端末の中だけに保存する。
///
/// 保存先は Documents/ProfileImages。外へは送らない。
/// （子どもの写真を扱うので、録音と同じく端末内で完結させる。）
final class FileProfileImageStore: ProfileImageStoring {
    private let directory: URL
    private let fileManager: FileManager

    init(fileManager: FileManager = .default, directory: URL? = nil) {
        self.fileManager = fileManager
        if let directory {
            self.directory = directory
        } else {
            let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            self.directory = documents.appendingPathComponent("ProfileImages", isDirectory: true)
        }
    }

    private func prepareDirectory() -> Bool {
        if fileManager.fileExists(atPath: directory.path) { return true }
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            return true
        } catch {
            return false
        }
    }

    /// ファイル名からパスを組み立てる。
    /// 保存済みの名前しか来ない想定だが、念のため階層を跨げないようにする。
    private func url(for name: String) -> URL? {
        let safe = name.replacingOccurrences(of: "/", with: "")
        guard !safe.isEmpty, safe != ".", safe != ".." else { return nil }
        return directory.appendingPathComponent(safe, isDirectory: false)
    }

    func save(imageData: Data) -> String? {
        guard !imageData.isEmpty, prepareDirectory() else { return nil }
        let name = "avatar-\(UUID().uuidString).jpg"
        guard let url = url(for: name) else { return nil }
        do {
            try imageData.write(to: url, options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    func imageData(named name: String) -> Data? {
        guard let url = url(for: name) else { return nil }
        return try? Data(contentsOf: url)
    }

    func delete(named name: String) {
        guard let url = url(for: name) else { return }
        try? fileManager.removeItem(at: url)
    }
}

/// 選んでもらった写真を、アイコンとして扱える大きさ・形に整える。
enum AvatarImageProcessor {

    /// 正方形に切り抜いて縮小し、JPEG にする。
    /// 失敗したら nil（元の巨大な画像をそのまま保存しない）。
    static func makeAvatarData(from image: UIImage) -> Data? {
        guard let square = squareImage(from: image) else { return nil }
        return square.jpegData(compressionQuality: AvatarImageGeometry.jpegQuality)
    }

    /// 中央（縦長なら少し上）を正方形に切り抜いて、512pt 四方に描き直す。
    static func squareImage(from image: UIImage) -> UIImage? {
        let width = Double(image.size.width)
        let height = Double(image.size.height)
        let crop = AvatarImageGeometry.squareCropRect(width: width, height: height)
        guard crop.side > 0 else { return nil }

        let side = min(crop.side, AvatarImageGeometry.targetSide)
        let canvas = CGSize(width: side, height: side)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: canvas, format: format).image { _ in
            // 切り抜きたい範囲が原点に来るように、画像全体をずらして描く。
            let scale = side / crop.side
            let drawSize = CGSize(width: width * scale, height: height * scale)
            let origin = CGPoint(x: -crop.x * scale, y: -crop.y * scale)
            image.draw(in: CGRect(origin: origin, size: drawSize))
        }
    }
}
