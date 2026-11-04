import XCTest
import SwiftData
@testable import ViAnh

final class BudgetCalculatorTests: XCTestCase {

    func testBudgetStatusNotSetWhenNilOrZero() {
        XCTAssertEqual(BudgetCalculator.budgetStatus(spent: 100_000, budget: nil), .notSet)
        XCTAssertEqual(BudgetCalculator.budgetStatus(spent: 100_000, budget: 0), .notSet)
        XCTAssertEqual(BudgetCalculator.budgetStatus(spent: 0, budget: nil), .notSet)
    }

    func testBudgetStatusSafeUnderEightyPercent() {
        let status = BudgetCalculator.budgetStatus(spent: 790_000, budget: 1_000_000)
        XCTAssertEqual(status, .safe(ratio: 0.79))
        XCTAssertEqual(status.label, "79% đã dùng")
        XCTAssertEqual(status.symbolName, "checkmark.circle.fill")
    }

    func testBudgetStatusWarningAtEightyPercent() {
        let status = BudgetCalculator.budgetStatus(spent: 800_000, budget: 1_000_000)
        XCTAssertEqual(status, .warning(ratio: 0.80))
        XCTAssertEqual(status.label, "Cảnh báo: 80% đã dùng")
        XCTAssertEqual(status.symbolName, "exclamationmark.triangle.fill")
    }

    func testBudgetStatusAtLimit() {
        let status = BudgetCalculator.budgetStatus(spent: 1_000_000, budget: 1_000_000)
        XCTAssertEqual(status, .atLimit(ratio: 1.0))
        XCTAssertEqual(status.label, "Đã dùng hết ngân sách")
        XCTAssertEqual(status.symbolName, "exclamationmark.circle.fill")
    }

    func testBudgetStatusOverBudget() {
        let status = BudgetCalculator.budgetStatus(spent: 1_250_000, budget: 1_000_000)
        XCTAssertEqual(status, .overBudget(ratio: 1.25, exceededVND: 250_000))
        XCTAssertEqual(status.symbolName, "xmark.circle.fill")
        XCTAssertTrue(status.label.contains("Vượt"))
    }

    func testTotalSpentCalculations() {
        let cat = ExpenseCategory(name: "Ăn uống", symbolName: "fork.knife", colorHex: "#FF6B6B", isDefault: true)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 7 * 3600)! // Vietnam UTC+7

        var comp1 = DateComponents(year: 2026, month: 11, day: 15, hour: 12)
        var comp2 = DateComponents(year: 2026, month: 11, day: 20, hour: 18)
        var comp3 = DateComponents(year: 2026, month: 10, day: 31, hour: 23, minute: 59) // Tháng 10

        let d1 = calendar.date(from: comp1)!
        let d2 = calendar.date(from: comp2)!
        let d3 = calendar.date(from: comp3)!

        let e1 = ExpenseItem(amountVND: 50_000, category: cat, spentAt: d1)
        let e2 = ExpenseItem(amountVND: 120_000, category: cat, spentAt: d2)
        let e3 = ExpenseItem(amountVND: 300_000, category: cat, spentAt: d3)

        let totalNov = BudgetCalculator.totalSpent(expenses: [e1, e2, e3], year: 2026, month: 11, calendar: calendar)
        XCTAssertEqual(totalNov, 170_000)

        let totalOct = BudgetCalculator.totalSpent(expenses: [e1, e2, e3], year: 2026, month: 10, calendar: calendar)
        XCTAssertEqual(totalOct, 300_000)
    }

    func testCategoryBudgetStatus() {
        let catFood = ExpenseCategory(name: "Ăn uống", symbolName: "fork.knife", colorHex: "#FF6B6B")
        let catShop = ExpenseCategory(name: "Mua sắm", symbolName: "bag", colorHex: "#4ECDC4")

        let d = Date.now
        let e1 = ExpenseItem(amountVND: 400_000, category: catFood, spentAt: d)
        let e2 = ExpenseItem(amountVND: 600_000, category: catShop, spentAt: d)

        let cal = Calendar.current
        let year = cal.component(.year, from: d)
        let month = cal.component(.month, from: d)

        let statusFood = BudgetCalculator.categoryBudgetStatus(
            categoryId: catFood.id,
            expenses: [e1, e2],
            year: year,
            month: month,
            categoryBudget: 500_000,
            calendar: cal
        )

        XCTAssertEqual(statusFood, .warning(ratio: 0.8))
    }
}

