import Foundation
import SwiftData

// MARK: - MonthlyBudget Model

@Model
final class MonthlyBudget {

    var id: UUID
    var year: Int    // Ví dụ: 2026
    var month: Int   // 1–12

    // nil = chưa đặt ngân sách tổng — KHÔNG coi là 0 để tránh chia cho 0
    var totalBudgetVND: Int64?

    // Ngân sách theo danh mục — entity riêng (không JSON string)
    @Relationship(deleteRule: .cascade, inverse: \CategoryBudget.monthlyBudget)
    var categoryBudgets: [CategoryBudget] = []

    var createdAt: Date
    var ownerUID: String = ""

    init(year: Int, month: Int, totalBudgetVND: Int64? = nil, ownerUID: String = "") {
        self.id = UUID()
        self.year = year
        self.month = month
        self.totalBudgetVND = totalBudgetVND
        self.createdAt = .now
        self.ownerUID = ownerUID
    }
}

// MARK: - CategoryBudget Model

@Model
final class CategoryBudget {

    var id: UUID
    var category: ExpenseCategory   // Quan hệ tới danh mục
    var amountVND: Int64            // Giới hạn ngân sách cho danh mục này

    // Back-reference tới MonthlyBudget
    var monthlyBudget: MonthlyBudget

    init(category: ExpenseCategory, amountVND: Int64, monthlyBudget: MonthlyBudget) {
        self.id = UUID()
        self.category = category
        self.amountVND = amountVND
        self.monthlyBudget = monthlyBudget
    }
}

// MARK: - Helpers

extension MonthlyBudget {

    /// Lấy ngân sách của một danh mục cụ thể (nil = chưa đặt)
    func budgetAmount(for categoryId: UUID) -> Int64? {
        categoryBudgets.first { $0.category.id == categoryId }?.amountVND
    }
}
