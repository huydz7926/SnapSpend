import Foundation
import SwiftData

// MARK: - DataOwnerMigrationService

/// Quản lý phân quyền sở hữu dữ liệu SwiftData theo Firebase UID
/// Đảm bảo tính toàn vẹn, bảo toàn dữ liệu cũ, không xóa database và không ghi đè chéo tài khoản
@MainActor
final class DataOwnerMigrationService {

    static let shared = DataOwnerMigrationService()

    private let legacyOwnerKey = "snapspend_legacy_owner_uid"
    private let migrationPerformedKey = "snapspend_data_owner_migrated"

    private init() {}

    // MARK: - 1. Di chuyển & Gán quyền dữ liệu cũ (Legacy Migration)

    /// Rà soát các bản ghi cũ chưa có ownerUID và gán an toàn theo nguyên tắc bảo toàn dữ liệu
    func migrateLegacyDataIfNeeded(context: ModelContext, activeOwnerID: String) {
        guard !activeOwnerID.isEmpty && activeOwnerID != "signed_out" else { return }

        // Kiểm tra xem đã từng ghi nhận chủ nhân ban đầu của dữ liệu cũ chưa
        let recordedLegacyOwner = UserDefaults.standard.string(forKey: legacyOwnerKey)

        if recordedLegacyOwner == nil {
            // Đây là lần chạy đầu tiên kể từ khi nâng cấp phân quyền
            // Nếu người dùng đang là tài khoản thật (hoặc guest), lưu lại làm chủ nhân của dữ liệu lịch sử
            UserDefaults.standard.set(activeOwnerID, forKey: legacyOwnerKey)
        }

        let assignedOwner = UserDefaults.standard.string(forKey: legacyOwnerKey) ?? activeOwnerID

        // 1. Quét ExpenseItem chưa có ownerUID
        let expenseDescriptor = FetchDescriptor<ExpenseItem>()
        if let allExpenses = try? context.fetch(expenseDescriptor) {
            var didChange = false
            for item in allExpenses {
                if item.ownerUID.isEmpty {
                    // Chỉ gán cho chủ nhân ban đầu đã xác định; nếu là tài khoản B mới đăng nhập, gán vào legacy_unassigned
                    if activeOwnerID == assignedOwner {
                        item.ownerUID = assignedOwner
                    } else {
                        item.ownerUID = "legacy_unassigned"
                    }
                    didChange = true
                }
            }
            if didChange {
                try? context.save()
            }
        }

        // 2. Quét MonthlyBudget chưa có ownerUID
        let budgetDescriptor = FetchDescriptor<MonthlyBudget>()
        if let allBudgets = try? context.fetch(budgetDescriptor) {
            var didChange = false
            for budget in allBudgets {
                if budget.ownerUID.isEmpty {
                    if activeOwnerID == assignedOwner {
                        budget.ownerUID = assignedOwner
                    } else {
                        budget.ownerUID = "legacy_unassigned"
                    }
                    didChange = true
                }
            }
            if didChange {
                try? context.save()
            }
        }
    }

    // MARK: - 2. Quản lý dữ liệu Khách (Guest Data Management)

    /// Đếm số lượng giao dịch thuộc phiên Khách chưa gán vào tài khoản
    func countGuestExpenses(context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<ExpenseItem>(
            predicate: #Predicate { $0.ownerUID == "guest_local" }
        )
        return (try? context.fetch(descriptor).count) ?? 0
    }

    /// Chuyển dữ liệu khách vào tài khoản đã đăng nhập có cơ chế chống trùng lặp (khi người dùng đồng ý)
    func transferGuestExpensesToUser(targetOwnerID: String, context: ModelContext) -> Int {
        guard !targetOwnerID.isEmpty && targetOwnerID != "guest_local" && targetOwnerID != "signed_out" else {
            return 0
        }

        let guestDescriptor = FetchDescriptor<ExpenseItem>(
            predicate: #Predicate { $0.ownerUID == "guest_local" }
        )
        guard let guestItems = try? context.fetch(guestDescriptor), !guestItems.isEmpty else {
            return 0
        }

        // Lấy danh sách ID đã có của user để chống duplicate
        let userDescriptor = FetchDescriptor<ExpenseItem>(
            predicate: #Predicate { $0.ownerUID == targetOwnerID }
        )
        let existingUserIDs = Set(((try? context.fetch(userDescriptor)) ?? []).map { $0.id })

        var transferredCount = 0
        for item in guestItems {
            if !existingUserIDs.contains(item.id) {
                item.ownerUID = targetOwnerID
                item.updatedAt = .now
                transferredCount += 1
            } else {
                // Đã tồn tại trùng lặp, xóa bản sao khách an toàn
                context.delete(item)
            }
        }

        // Chuyển cả ngân sách khách nếu có
        let guestBudgets = (try? context.fetch(FetchDescriptor<MonthlyBudget>(
            predicate: #Predicate { $0.ownerUID == "guest_local" }
        ))) ?? []

        for b in guestBudgets {
            b.ownerUID = targetOwnerID
        }

        try? context.save()
        return transferredCount
    }
}

