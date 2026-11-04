import XCTest
import SwiftData
@testable import ViAnh

@MainActor
final class CategoryManagerTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        let schema = Schema([
            ExpenseItem.self,
            ExpenseCategory.self,
            MonthlyBudget.self,
            CategoryBudget.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    func testSeedDefaultCategories() throws {
        // Trước khi seed: rỗng
        let beforeDescriptor = FetchDescriptor<ExpenseCategory>()
        let beforeCount = try context.fetch(beforeDescriptor).count
        XCTAssertEqual(beforeCount, 0)

        // Seed
        CategoryManager.seedDefaultCategoriesIfNeeded(context: context)

        let afterDescriptor = FetchDescriptor<ExpenseCategory>()
        let after = try context.fetch(afterDescriptor)
        XCTAssertEqual(after.count, 8)

        // Tìm thấy danh mục "Khác"
        let other = CategoryManager.findOtherCategory(context: context)
        XCTAssertNotNil(other)
        XCTAssertEqual(other?.name, "Khác")
    }

    func testCannotDeleteDefaultCategory() throws {
        CategoryManager.seedDefaultCategoriesIfNeeded(context: context)

        let descriptor = FetchDescriptor<ExpenseCategory>(predicate: #Predicate { $0.isDefault == true })
        guard let defaultCat = try context.fetch(descriptor).first else {
            XCTFail("No default category found")
            return
        }

        XCTAssertThrowsError(try CategoryManager.deleteCategory(defaultCat, context: context)) { error in
            guard let catErr = error as? CategoryManager.CategoryError else {
                XCTFail("Unexpected error type: \(error)")
                return
            }
            switch catErr {
            case .cannotDeleteDefaultCategory:
                break // Đúng mong đợi
            default:
                XCTFail("Wrong CategoryError: \(catErr)")
            }
        }
    }

    func testDeleteCustomCategoryMigratesExpensesAndCleansBudgets() throws {
        CategoryManager.seedDefaultCategoriesIfNeeded(context: context)
        guard let otherCat = CategoryManager.findOtherCategory(context: context) else {
            XCTFail("Missing Khác category")
            return
        }

        // Tạo danh mục tùy chỉnh
        let customCat = ExpenseCategory(name: "Sở thích cá nhân", symbolName: "gamecontroller", colorHex: "#A29BFE", isDefault: false)
        context.insert(customCat)

        // Gán expense
        let expense = ExpenseItem(amountVND: 250_000, category: customCat, spentAt: Date.now, title: "Mua game Steam")
        context.insert(expense)

        // Tạo budget tháng và budget cho custom category
        let monthlyBudget = MonthlyBudget(year: 2026, month: 11, totalBudgetVND: 10_000_000)
        let catBudget = CategoryBudget(category: customCat, amountVND: 1_000_000, monthlyBudget: monthlyBudget)
        context.insert(monthlyBudget)
        context.insert(catBudget)
        try context.save()

        // Xóa danh mục tùy chỉnh
        try CategoryManager.deleteCategory(customCat, context: context)

        // Expense phải được chuyển sang "Khác"
        XCTAssertEqual(expense.category.id, otherCat.id)

        // CategoryBudget phải bị dọn dẹp
        let remainingBudgets = try context.fetch(FetchDescriptor<CategoryBudget>())
        let budgetsForCustom = remainingBudgets.filter { $0.category.id == customCat.id }
        XCTAssertEqual(budgetsForCustom.count, 0)
    }
}

