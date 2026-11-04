import Foundation
import SwiftData

// MARK: - CategoryManager

/// Service quản lý danh mục — seed mặc định, xóa an toàn
/// Tách khỏi View để dễ test và tái sử dụng
@MainActor
final class CategoryManager {

    // MARK: - Seed Default Categories

    /// Kiểm tra và seed 8 danh mục mặc định nếu chưa có
    /// Gọi một lần khi app khởi động
    static func seedDefaultCategoriesIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<ExpenseCategory>(
            predicate: #Predicate { $0.isDefault == true }
        )

        let existingDefaults = (try? context.fetch(descriptor)) ?? []

        // Nếu đã đủ 8 danh mục mặc định thì bỏ qua
        if existingDefaults.count >= ExpenseCategory.defaultDefinitions.count {
            return
        }

        // Seed các danh mục còn thiếu
        let existingNames = Set(existingDefaults.map { $0.name })

        for definition in ExpenseCategory.defaultDefinitions {
            guard !existingNames.contains(definition.name) else { continue }

            let category = ExpenseCategory(
                name: definition.name,
                symbolName: definition.symbol,
                colorHex: definition.color,
                isDefault: true,
                sortOrder: definition.order
            )
            context.insert(category)
        }

        try? context.save()
    }

    // MARK: - Find "Khác" Category

    /// Tìm danh mục "Khác" — dùng làm fallback khi xóa danh mục đang được dùng
    static func findOtherCategory(context: ModelContext) -> ExpenseCategory? {
        let name = ExpenseCategory.otherCategoryName
        let descriptor = FetchDescriptor<ExpenseCategory>(
            predicate: #Predicate { $0.name == name && $0.isDefault == true }
        )
        return try? context.fetch(descriptor).first
    }

    // MARK: - Delete Category Safely

    /// Lỗi khi thao tác trên Category
    enum CategoryError: LocalizedError {
        case cannotDeleteDefaultCategory
        case fallbackCategoryNotFound
        case saveFailed(Error)

        var errorDescription: String? {
            switch self {
            case .cannotDeleteDefaultCategory:
                return "Không thể xóa danh mục mặc định của hệ thống."
            case .fallbackCategoryNotFound:
                return "Không tìm thấy danh mục 'Khác' để chuyển dữ liệu."
            case .saveFailed(let error):
                return "Lưu dữ liệu thất bại: \(error.localizedDescription)"
            }
        }
    }

    /// Xóa danh mục và chuyển toàn bộ expense của danh mục đó sang danh mục thay thế (mặc định là "Khác"),
    /// đồng thời dọn dẹp các CategoryBudget tham chiếu đến danh mục này.
    static func deleteCategory(
        _ category: ExpenseCategory,
        replacementCategory: ExpenseCategory? = nil,
        context: ModelContext
    ) throws {
        guard !category.isDefault else {
            throw CategoryError.cannotDeleteDefaultCategory
        }

        let targetCategory: ExpenseCategory
        if let replacement = replacementCategory {
            targetCategory = replacement
        } else if let other = findOtherCategory(context: context) {
            targetCategory = other
        } else {
            throw CategoryError.fallbackCategoryNotFound
        }

        // Chuyển toàn bộ expense sang targetCategory
        for expense in category.expenses {
            expense.category = targetCategory
            expense.markUpdated()
        }

        // Dọn dẹp CategoryBudget đang tham chiếu đến category này
        let catId = category.id
        let budgetDescriptor = FetchDescriptor<CategoryBudget>()
        if let allCategoryBudgets = try? context.fetch(budgetDescriptor) {
            for cb in allCategoryBudgets where cb.category.id == catId {
                context.delete(cb)
            }
        }

        context.delete(category)

        do {
            try context.save()
        } catch {
            throw CategoryError.saveFailed(error)
        }
    }
}
