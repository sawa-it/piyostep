import Foundation
import StoreKit

/// 課金（広告解除）の抽象。StoreKit をテストから切り離すために挟む。
@MainActor
protocol PurchaseServing: AnyObject {
    /// 広告解除を購入済みか
    var isAdFreePurchased: Bool { get }
    /// 表示用の価格（未取得なら nil）
    var displayPrice: String? { get }
    /// 商品情報を取得する
    func loadProducts() async
    /// 購入する。成功したら true
    func purchaseAdFree() async -> PurchaseOutcome
    /// 以前の購入を復元する
    func restorePurchases() async -> PurchaseOutcome
}

enum PurchaseOutcome: Equatable {
    case purchased
    case cancelled
    case pending
    case nothingToRestore
    case failed(String)
}

/// StoreKit 2 による実装。
@MainActor
final class StoreKitPurchaseService: PurchaseServing {
    static let adFreeProductID = "jp.piyostep.removeads"

    private(set) var isAdFreePurchased: Bool = false
    private(set) var displayPrice: String?
    private var product: Product?
    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                if case let .verified(transaction) = update {
                    await self.apply(transaction: transaction)
                    await transaction.finish()
                }
            }
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProducts() async {
        do {
            let products = try await Product.products(for: [StoreKitPurchaseService.adFreeProductID])
            product = products.first
            displayPrice = product?.displayPrice
        } catch {
            displayPrice = nil
        }
        await refreshEntitlements()
    }

    func purchaseAdFree() async -> PurchaseOutcome {
        if product == nil {
            await loadProducts()
        }
        guard let product else {
            return .failed("商品情報を取得できませんでした")
        }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case let .verified(transaction) = verification else {
                    return .failed("購入の検証に失敗しました")
                }
                await apply(transaction: transaction)
                await transaction.finish()
                return .purchased
            case .userCancelled:
                return .cancelled
            case .pending:
                return .pending
            @unknown default:
                return .failed("不明な結果です")
            }
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    func restorePurchases() async -> PurchaseOutcome {
        try? await AppStore.sync()
        await refreshEntitlements()
        return isAdFreePurchased ? .purchased : .nothingToRestore
    }

    private func refreshEntitlements() async {
        var purchased = false
        for await entitlement in Transaction.currentEntitlements {
            if case let .verified(transaction) = entitlement,
               transaction.productID == StoreKitPurchaseService.adFreeProductID,
               transaction.revocationDate == nil {
                purchased = true
            }
        }
        isAdFreePurchased = purchased
    }

    private func apply(transaction: Transaction) async {
        guard transaction.productID == StoreKitPurchaseService.adFreeProductID else { return }
        isAdFreePurchased = transaction.revocationDate == nil
    }
}

/// テスト・プレビュー用。
@MainActor
final class MockPurchaseService: PurchaseServing {
    var isAdFreePurchased: Bool
    var displayPrice: String?
    var nextOutcome: PurchaseOutcome = .purchased
    private(set) var loadCount = 0
    private(set) var purchaseCount = 0
    private(set) var restoreCount = 0

    init(isAdFreePurchased: Bool = false, displayPrice: String? = "¥480") {
        self.isAdFreePurchased = isAdFreePurchased
        self.displayPrice = displayPrice
    }

    func loadProducts() async {
        loadCount += 1
    }

    func purchaseAdFree() async -> PurchaseOutcome {
        purchaseCount += 1
        if nextOutcome == .purchased {
            isAdFreePurchased = true
        }
        return nextOutcome
    }

    func restorePurchases() async -> PurchaseOutcome {
        restoreCount += 1
        return isAdFreePurchased ? .purchased : .nothingToRestore
    }
}
