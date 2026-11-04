import Foundation
import SwiftData

// MARK: - Wallet Model

/// Ví tiền / Nguồn tiền: Tiền mặt, Ngân hàng, Thẻ tín dụng,...
@Model
final class Wallet {

    var id: UUID
    var name: String
    var symbolName: String
    var colorHex: String
    var isDefault: Bool
    var sortOrder: Int
    var initialBalanceVND: Int64
    var createdAt: Date
    var ownerUID: String?

    // Quan hệ với các khoản giao dịch thuộc ví này
    @Relationship(deleteRule: .nullify, inverse: \ExpenseItem.wallet)
    var expenses: [ExpenseItem] = []

    init(
        name: String,
        symbolName: String = "creditcard.fill",
        colorHex: String = "#1B4D3E",
        isDefault: Bool = false,
        sortOrder: Int = 0,
        initialBalanceVND: Int64 = 0,
        ownerUID: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.symbolName = symbolName
        self.colorHex = colorHex
        self.isDefault = isDefault
        self.sortOrder = sortOrder
        self.initialBalanceVND = initialBalanceVND
        self.createdAt = .now
        self.ownerUID = ownerUID
    }

    /// Định nghĩa ví mặc định khởi tạo ban đầu
    static let defaultDefinitions: [(name: String, symbol: String, color: String, isDefault: Bool, order: Int)] = [
        ("Tiền mặt", "banknote.fill", "#2E7D32", true, 0),
        ("Tài khoản chính", "building.columns.fill", "#1E88E5", false, 1),
        ("Ví điện tử", "iphone", "#E91E63", false, 2)
    ]
}

// MARK: - Balance Calculation Helpers

extension Wallet {
    /// Tính số dư hiện tại của ví dựa trên số dư ban đầu và các giao dịch phát sinh
    func currentBalance(expenses: [ExpenseItem]) -> Int64 {
        let walletExpenses = expenses.filter { $0.wallet?.id == self.id }
        let totalIncome = walletExpenses.filter { $0.type == .income }.reduce(Int64(0)) { $0 + $1.amountVND }
        let totalExpense = walletExpenses.filter { $0.type == .expense }.reduce(Int64(0)) { $0 + $1.amountVND }
        return initialBalanceVND + totalIncome - totalExpense
    }
}

