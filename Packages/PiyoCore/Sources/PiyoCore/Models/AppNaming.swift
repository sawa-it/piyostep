import Foundation

/// アプリの中で表示する「このアプリの呼び名」。
///
/// iOS ではホーム画面のアプリ名（CFBundleDisplayName）を実行中に変えられないので、
/// 変えられるのはアプリの中だけ。ホーム画面と食い違っても混乱しないよう、
/// 既定はビルド時の名前と同じ「ぴよステップ」にしておく。
public enum AppNaming {

    /// 何も設定していないときの名前。
    public static let defaultName = "ぴよステップ"

    /// 表示名の最大文字数。ホームの見出しに 1 行で収まる長さにする。
    public static let maxLength = 12

    /// 保護者が入力した名前を整える。長すぎるものは切り詰める。
    public static func sanitize(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxLength else { return trimmed }
        return String(trimmed.prefix(maxLength))
    }

    /// 実際に画面に出す名前を決める。
    /// 保護者が入れた名前 → 無ければ既定の名前。
    /// （子どもの名前から自動で作ってしまうと、ホーム画面のアプリ名と食い違うので、
    ///   既定のままにしておき、変えるかどうかは保護者に決めてもらう。）
    public static func displayName(custom: String) -> String {
        let sanitized = sanitize(custom)
        return sanitized.isEmpty ? defaultName : sanitized
    }

    /// 子どもの名前から作る候補（「たろうの アプリ」）。
    /// 入力欄のプレースホルダや「これにする」ボタンに使う。
    public static func suggestion(for profile: ChildProfile?) -> String? {
        guard let profile else { return nil }
        let name = profile.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        let candidate = "\(name)の アプリ"
        // 名前が長いと 12 文字に収まらないので、その場合は「〜のアプリ」と詰める。
        if candidate.count <= maxLength {
            return candidate
        }
        let compact = "\(name)のアプリ"
        return compact.count <= maxLength ? compact : sanitize(compact)
    }
}
