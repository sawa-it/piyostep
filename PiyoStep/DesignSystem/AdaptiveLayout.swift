import SwiftUI

/// いま使える画面の形。
///
/// iPad を横向きにすると幅は広いが高さが足りなくなる。縦に積んだままだと
/// 「できた！」などのボタンが画面の外に出てしまうので、この値を見て
/// 「左右 2 枚に分ける」「イラストを少し小さくする」を切り替える。
struct PiyoLayoutMetrics: Equatable {
    var size: CGSize

    /// 左右 2 枚に分けたほうがよい形か（横長で、分けても狭くならない幅がある）。
    var isSideBySide: Bool {
        size.width >= 720 && size.width > size.height * 1.1
    }

    /// 縦の余裕が少ないか。イラストやボタンを小さめにする判断に使う。
    var isCompactHeight: Bool { size.height < 700 }

    /// 1 枚で見せるときの、読みやすい最大幅。
    var columnMaxWidth: CGFloat { isSideBySide ? 900 : 640 }

    /// 高さに合わせて寸法を縮める。縦に余裕があるときはそのまま返す。
    func scaled(_ value: CGFloat, minimum: CGFloat? = nil) -> CGFloat {
        guard isCompactHeight, size.height > 0 else { return value }
        let ratio = max(0.6, size.height / 700)
        return max(minimum ?? value * 0.6, value * ratio)
    }
}

private struct PiyoLayoutKey: EnvironmentKey {
    /// 測る前の既定値（iPhone の縦持ち相当）。
    static let defaultValue = PiyoLayoutMetrics(size: CGSize(width: 390, height: 844))
}

extension EnvironmentValues {
    var piyoLayout: PiyoLayoutMetrics {
        get { self[PiyoLayoutKey.self] }
        set { self[PiyoLayoutKey.self] = newValue }
    }
}

/// 画面の大きさを測って、子ビューの環境に流す。各画面のいちばん外側に置く。
///
/// 測った値は自分自身の `@Environment(\.piyoLayout)` には返ってこないので、
/// 置いた画面自身が値を見たいときはクロージャの引数を使う。
struct PiyoLayoutReader<Content: View>: View {
    @ViewBuilder var content: (PiyoLayoutMetrics) -> Content

    var body: some View {
        GeometryReader { proxy in
            let metrics = PiyoLayoutMetrics(size: proxy.size)
            content(metrics)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .environment(\.piyoLayout, metrics)
        }
    }
}

/// 縦長では上下に、横長では左右に並べる。
///
/// どちらの形でも中身はスクロールできるので、ボタンが画面の外に出たままになることがない。
struct AdaptivePanes<Leading: View, Trailing: View>: View {
    @Environment(\.piyoLayout) private var layout

    var spacing: CGFloat = 20
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        if layout.isSideBySide {
            HStack(alignment: .top, spacing: spacing) {
                pane { leading }
                pane { trailing }
            }
        } else {
            ScrollView {
                VStack(spacing: spacing) {
                    leading
                    trailing
                }
                .frame(maxWidth: layout.columnMaxWidth)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 24)
            }
        }
    }

    private func pane<Content: View>(@ViewBuilder _ content: @escaping () -> Content) -> some View {
        GeometryReader { proxy in
            ScrollView {
                content()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    // 入りきるときは縦の中央に置く。上詰めだと下が大きく余ってしまう。
                    .frame(minHeight: proxy.size.height, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// 1 枚ものの画面。入りきるときは今までどおり中央に置き、
/// 入りきらない形（横向きなど）になったらスクロールできるようにする。
struct AdaptiveColumn<Content: View>: View {
    @Environment(\.piyoLayout) private var layout

    var spacing: CGFloat = 20
    var maxWidth: CGFloat?
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: spacing) {
                    content
                }
                .frame(maxWidth: maxWidth ?? layout.columnMaxWidth)
                .frame(maxWidth: .infinity)
                // 余裕があるときは Spacer() が効くように、最低でも画面の高さを確保する。
                .frame(minHeight: proxy.size.height)
            }
        }
    }
}
