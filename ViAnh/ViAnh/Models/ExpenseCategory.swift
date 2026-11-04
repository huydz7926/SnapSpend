import Foundation
import SwiftData
import SwiftUI

// MARK: - ExpenseCategory Model

@Model
final class ExpenseCategory {

    var id: UUID
    var name: String
    var symbolName: String   // SF Symbol name, e.g. "fork.knife"
    var colorHex: String     // Hex string, e.g. "#FF6B6B" — tránh lưu Color trực tiếp
    var isDefault: Bool      // true = 8 danh mục mặc định, không xóa được
    var sortOrder: Int
    var ownerUID: String?    // nil = dùng chung cho hệ thống, có giá trị = thuộc về tài khoản tạo

    // Relationship ngược từ ExpenseItem
    @Relationship(deleteRule: .nullify, inverse: \ExpenseItem.category)
    var expenses: [ExpenseItem] = []

    init(
        name: String,
        symbolName: String,
        colorHex: String,
        isDefault: Bool = false,
        sortOrder: Int = 0,
        ownerUID: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.symbolName = symbolName
        self.colorHex = colorHex
        self.isDefault = isDefault
        self.sortOrder = sortOrder
        self.ownerUID = ownerUID
    }
}

// MARK: - Default Categories

extension ExpenseCategory {

    /// 8 danh mục mặc định — chỉ dùng để seed lần đầu
    static let defaultDefinitions: [(name: String, symbol: String, color: String, order: Int)] = [
        ("Ăn uống",  "fork.knife",       "#FF6B6B", 0),
        ("Mua sắm",  "bag",              "#4ECDC4", 1),
        ("Đi lại",   "car",              "#45B7D1", 2),
        ("Nhà ở",    "house",            "#96CEB4", 3),
        ("Học tập",  "book",             "#F9CA24", 4),
        ("Sức khỏe", "heart",            "#DDA0DD", 5),
        ("Giải trí", "gamecontroller",   "#98D8C8", 6),
        ("Khác",     "ellipsis.circle",  "#B0B0B0", 7),
    ]

    /// Tên danh mục "Khác" — dùng khi chuyển expense sang fallback
    static let otherCategoryName = "Khác"
}

// MARK: - Helpers

extension ExpenseCategory {

    /// Chuyển colorHex thành SwiftUI Color
    var color: Color {
        Color(hex: colorHex) ?? .gray
    }
}
