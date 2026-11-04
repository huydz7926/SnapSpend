import Foundation
import SwiftData

// MARK: - WalletManager

/// Service quản lý ví / nguồn tiền — seed mặc định, tìm ví chính
@MainActor
final class WalletManager {

    /// Kiểm tra và seed các ví mặc định nếu chưa có
    static func seedDefaultWalletsIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<Wallet>()
        let existing = (try? context.fetch(descriptor)) ?? []

        if !existing.isEmpty {
            return
        }

        for item in Wallet.defaultDefinitions {
            let wallet = Wallet(
                name: item.name,
                symbolName: item.symbol,
                colorHex: item.color,
                isDefault: item.isDefault,
                sortOrder: item.order
            )
            context.insert(wallet)
        }

        try? context.save()
    }

    /// Lấy ví mặc định (hoặc ví đầu tiên)
    static func getDefaultWallet(context: ModelContext) -> Wallet? {
        let descriptor = FetchDescriptor<Wallet>(
            predicate: #Predicate { $0.isDefault == true }
        )
        if let wallet = try? context.fetch(descriptor).first {
            return wallet
        }
        let fallbackDescriptor = FetchDescriptor<Wallet>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        return try? context.fetch(fallbackDescriptor).first
    }
}

