import Foundation
import SwiftData

// MARK: - Preview Data
// CHỈ dùng trong #Preview — KHÔNG bao giờ dùng trong production code

#if DEBUG
@MainActor
enum PreviewData {

    // MARK: - Container

    /// Tạo in-memory ModelContainer cho Preview
    static var container: ModelContainer = {
        let schema = Schema([
            ExpenseItem.self,
            ExpenseCategory.self,
            MonthlyBudget.self,
            CategoryBudget.self,
            Wallet.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)

        // Seed dữ liệu mẫu
        seedSampleData(context: container.mainContext)
        return container
    }()

    // MARK: - Sample Categories

    static var sampleCategories: [ExpenseCategory] = []

    // MARK: - Seed

    private static func seedSampleData(context: ModelContext) {
        // Tạo danh mục mẫu
        let categories = ExpenseCategory.defaultDefinitions.enumerated().map { i, def in
            ExpenseCategory(
                name: def.name,
                symbolName: def.symbol,
                colorHex: def.color,
                isDefault: true,
                sortOrder: def.order
            )
        }

        categories.forEach { context.insert($0) }
        sampleCategories = categories

        guard categories.count >= 4 else { return }

        let foodCat     = categories[0]
        let shoppingCat = categories[1]
        let travelCat   = categories[2]
        let eduCat      = categories[4]

        // Tạo expense mẫu cho tháng hiện tại
        let calendar = Calendar.current
        let now = Date.now

        let expenses: [ExpenseItem] = [
            makeExpense(amount: 45_000,  category: foodCat,     daysAgo: 0,  title: "Cà phê sáng",    note: "Highlands Coffee",   calendar: calendar, now: now),
            makeExpense(amount: 35_000,  category: foodCat,     daysAgo: 0,  title: "Ăn trưa",         note: "Cơm tấm gần công ty", calendar: calendar, now: now),
            makeExpense(amount: 15_000,  category: travelCat,   daysAgo: 1,  title: "Xe buýt",          note: "",                    calendar: calendar, now: now),
            makeExpense(amount: 250_000, category: shoppingCat, daysAgo: 2,  title: "Áo thun",          note: "Uniqlo sale",         calendar: calendar, now: now),
            makeExpense(amount: 120_000, category: eduCat,      daysAgo: 3,  title: "Sách lập trình",   note: "Swift in Depth",      calendar: calendar, now: now),
            makeExpense(amount: 75_000,  category: foodCat,     daysAgo: 5,  title: "Ăn tối",           note: "Lẩu cùng bạn bè",     calendar: calendar, now: now),
            makeExpense(amount: 500_000, category: shoppingCat, daysAgo: 8,  title: "Giày thể thao",    note: "",                    calendar: calendar, now: now),
            makeExpense(amount: 30_000,  category: travelCat,   daysAgo: 10, title: "Grab",             note: "",                    calendar: calendar, now: now),
        ]

        expenses.forEach { context.insert($0) }

        // Tạo ngân sách mẫu
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)

        let budget = MonthlyBudget(year: year, month: month, totalBudgetVND: 3_000_000)
        context.insert(budget)

        if let foodBudget = CategoryBudget(category: foodCat, amount: 1_000_000, budget: budget, context: context) {
            context.insert(foodBudget)
        }
        if let shopBudget = CategoryBudget(category: shoppingCat, amount: 500_000, budget: budget, context: context) {
            context.insert(shopBudget)
        }

        try? context.save()
    }

    private static func makeExpense(
        amount: Int64,
        category: ExpenseCategory,
        daysAgo: Int,
        title: String,
        note: String,
        calendar: Calendar,
        now: Date
    ) -> ExpenseItem {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now
        let expense = ExpenseItem(
            amountVND: amount,
            category: category,
            spentAt: date,
            title: title,
            note: note
        )
        return expense
    }
}

private extension CategoryBudget {
    convenience init?(category: ExpenseCategory, amount: Int64, budget: MonthlyBudget, context: ModelContext) {
        self.init(category: category, amountVND: amount, monthlyBudget: budget)
        return
    }
}
#endif
