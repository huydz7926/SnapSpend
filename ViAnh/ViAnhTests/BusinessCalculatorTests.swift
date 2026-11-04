import XCTest
import SwiftData
@testable import ViAnh

// MARK: - BusinessCalculatorTests

/// Bộ kiểm thử tự động các thuật toán kinh doanh cốt lõi:
/// Ngân sách, chuỗi ngày Streaks, biến động số dư Ví và gợi ý mệnh giá tiền SmartVND
@MainActor
final class BusinessCalculatorTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        let schema = Schema([
            ExpenseItem.self,
            ExpenseCategory.self,
            MonthlyBudget.self,
            CategoryBudget.self,
            Wallet.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext

        CategoryManager.seedDefaultCategoriesIfNeeded(context: context)
        WalletManager.seedDefaultWalletsIfNeeded(context: context)
    }

    override func tearDown() async throws {
        container = nil
        context = nil
    }

    // MARK: - 1. Tính toán hạn mức MonthlyBudget (5 trạng thái)

    func testMonthlyBudgetCalculationSafeWarningLimitOver() {
        let budgetLimit: Int64 = 1_000_000

        // 1. Chưa đặt ngân sách
        XCTAssertEqual(BudgetCalculator.budgetStatus(spent: 500_000, budget: nil), .notSet)
        XCTAssertEqual(BudgetCalculator.budgetStatus(spent: 500_000, budget: 0), .notSet)

        // 2. An toàn (ratio < 0.8)
        let safeStatus = BudgetCalculator.budgetStatus(spent: 750_000, budget: budgetLimit)
        XCTAssertEqual(safeStatus, .safe(ratio: 0.75))
        XCTAssertEqual(safeStatus.symbolName, "checkmark.circle.fill")
        XCTAssertTrue(safeStatus.label.contains("75%"))

        // 3. Cảnh báo (0.8 <= ratio < 1.0)
        let warningStatus = BudgetCalculator.budgetStatus(spent: 850_000, budget: budgetLimit)
        XCTAssertEqual(warningStatus, .warning(ratio: 0.85))
        XCTAssertEqual(warningStatus.symbolName, "exclamationmark.triangle.fill")
        XCTAssertTrue(warningStatus.label.contains("85%"))

        // 4. Chạm hạn mức chính xác (ratio == 1.0)
        let limitStatus = BudgetCalculator.budgetStatus(spent: 1_000_000, budget: budgetLimit)
        XCTAssertEqual(limitStatus, .atLimit(ratio: 1.0))
        XCTAssertEqual(limitStatus.symbolName, "exclamationmark.circle.fill")

        // 5. Vượt hạn mức (ratio > 1.0)
        let overStatus = BudgetCalculator.budgetStatus(spent: 1_350_000, budget: budgetLimit)
        XCTAssertEqual(overStatus, .overBudget(ratio: 1.35, exceededVND: 350_000))
        XCTAssertEqual(overStatus.symbolName, "xmark.circle.fill")
        XCTAssertTrue(overStatus.label.contains("350.000"))
    }

    // MARK: - 2. Ngân sách theo từng danh mục riêng lẻ

    func testCategoryBudgetStatusCalculation() {
        let cat = ExpenseCategory(name: "Ăn uống", symbolName: "fork.knife", colorHex: "#FF6B6B")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 7 * 3600)!

        let date = calendar.date(from: DateComponents(year: 2026, month: 11, day: 10))!
        let e1 = ExpenseItem(amountVND: 400_000, category: cat, spentAt: date)
        let e2 = ExpenseItem(amountVND: 500_000, category: cat, spentAt: date)

        let status = BudgetCalculator.categoryBudgetStatus(
            categoryId: cat.id,
            expenses: [e1, e2],
            year: 2026,
            month: 11,
            categoryBudget: 1_000_000,
            calendar: calendar
        )

        // Đã chi 900.000 / 1.000.000 = 90% -> warning
        XCTAssertEqual(status, .warning(ratio: 0.9))
    }

    // MARK: - 3. Lọc tổng chi loại trừ các tháng khác

    func testTotalSpentExcludesOtherMonths() {
        let cat = ExpenseCategory(name: "Mua sắm", symbolName: "bag", colorHex: "#4ECDC4")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 7 * 3600)!

        let novDate1 = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 0, minute: 1))!
        let novDate2 = calendar.date(from: DateComponents(year: 2026, month: 11, day: 30, hour: 23, minute: 58))!
        let octDate = calendar.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: 23, minute: 59))!
        let decDate = calendar.date(from: DateComponents(year: 2026, month: 12, day: 1, hour: 0, minute: 1))!

        let expNov1 = ExpenseItem(amountVND: 100_000, category: cat, spentAt: novDate1)
        let expNov2 = ExpenseItem(amountVND: 250_000, category: cat, spentAt: novDate2)
        let expOct = ExpenseItem(amountVND: 500_000, category: cat, spentAt: octDate)
        let expDec = ExpenseItem(amountVND: 700_000, category: cat, spentAt: decDate)

        let allExpenses = [expNov1, expNov2, expOct, expDec]

        let totalNov = BudgetCalculator.totalSpent(expenses: allExpenses, year: 2026, month: 11, calendar: calendar)
        XCTAssertEqual(totalNov, 350_000, "Tổng chi tháng 11 phải chính xác là 350.000 ₫ và loại bỏ tháng 10 và tháng 12")
    }

    // MARK: - 4. Tính biến động số dư Ví (initial + income - expense)

    func testWalletBalanceCalculationWithIncomeAndExpense() {
        let cat = ExpenseCategory(name: "Lương", symbolName: "dollarsign.circle", colorHex: "#4CAF50")
        let wallet = Wallet(name: "Tài khoản Techcombank", initialBalanceVND: 5_000_000)

        // Khoản thu +15.000.000 ₫
        let income = ExpenseItem(
            amountVND: 15_000_000,
            category: cat,
            type: .income,
            wallet: wallet
        )

        // Khoản chi -3.200.000 ₫
        let expense1 = ExpenseItem(
            amountVND: 3_200_000,
            category: cat,
            type: .expense,
            wallet: wallet
        )

        // Khoản chi -1.800.000 ₫
        let expense2 = ExpenseItem(
            amountVND: 1_800_000,
            category: cat,
            type: .expense,
            wallet: wallet
        )

        let expenses = [income, expense1, expense2]
        let currentBalance = wallet.currentBalance(expenses: expenses)

        // 5.000.000 + 15.000.000 - 3.200.000 - 1.800.000 = 15.000.000 ₫
        XCTAssertEqual(currentBalance, 15_000_000, "Số dư ví tính toán theo công thức chuẩn phải là 15.000.000 ₫")
    }

    // MARK: - 5. Tính chuỗi ngày chụp ảnh camera liên tục

    func testStreakConsecutiveDaysCalculation() {
        let cat = ExpenseCategory(name: "Ăn uống", symbolName: "fork.knife", colorHex: "#FF6B6B")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 7 * 3600)!

        let today = calendar.date(from: DateComponents(year: 2026, month: 11, day: 4, hour: 12))!
        let yesterday = calendar.date(from: DateComponents(year: 2026, month: 11, day: 3, hour: 10))!
        let twoDaysAgo = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 15))!

        let item1 = ExpenseItem(amountVND: 40_000, category: cat, photoSource: "camera", capturedAt: today)
        item1.imageFileName = "img_1.jpg"

        let item2 = ExpenseItem(amountVND: 50_000, category: cat, photoSource: "camera", capturedAt: yesterday)
        item2.imageFileName = "img_2.jpg"

        let item3 = ExpenseItem(amountVND: 60_000, category: cat, photoSource: "camera", capturedAt: twoDaysAgo)
        item3.imageFileName = "img_3.jpg"

        let summary = StreakService.calculate(
            expenses: [item1, item2, item3],
            referenceDate: today,
            calendar: calendar
        )

        XCTAssertEqual(summary.totalPhotos, 3)
        XCTAssertEqual(summary.currentStreak, 3)
        XCTAssertEqual(summary.longestStreak, 3)
    }

    // MARK: - 6. Duy trì streak nếu hôm nay chưa chụp nhưng hôm qua đã chụp

    func testStreakMaintainedWhenYesterdayCaptured() {
        let cat = ExpenseCategory(name: "Ăn uống", symbolName: "fork.knife", colorHex: "#FF6B6B")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 7 * 3600)!

        let today = calendar.date(from: DateComponents(year: 2026, month: 11, day: 4, hour: 9))!
        let yesterday = calendar.date(from: DateComponents(year: 2026, month: 11, day: 3, hour: 12))!
        let twoDaysAgo = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 14))!

        // Hôm nay người dùng chưa chụp ảnh, chỉ có hôm qua và hôm kia
        let itemYesterday = ExpenseItem(amountVND: 30_000, category: cat, photoSource: "camera", capturedAt: yesterday)
        itemYesterday.imageFileName = "img_y.jpg"

        let itemTwoDaysAgo = ExpenseItem(amountVND: 35_000, category: cat, photoSource: "camera", capturedAt: twoDaysAgo)
        itemTwoDaysAgo.imageFileName = "img_2d.jpg"

        let summary = StreakService.calculate(
            expenses: [itemYesterday, itemTwoDaysAgo],
            referenceDate: today,
            calendar: calendar
        )

        XCTAssertEqual(summary.currentStreak, 2, "Hôm nay chưa chụp thì streak vẫn kéo dài từ hôm qua là 2 ngày")
    }

    // MARK: - 7. Thuật toán gợi ý mệnh giá thông minh SmartVNDSuggestion

    func testSmartVNDChipsMultipliers() {
        // Người dùng gõ "35"
        let suggestions35 = SmartVNDSuggestion.suggestions(for: "35")
        XCTAssertEqual(suggestions35, [35_000, 350_000, 3_500_000])

        // Người dùng gõ "1"
        let suggestions1 = SmartVNDSuggestion.suggestions(for: "1")
        XCTAssertEqual(suggestions1, [1_000, 10_000, 100_000])

        // Người dùng gõ "120"
        let suggestions120 = SmartVNDSuggestion.suggestions(for: "120")
        XCTAssertEqual(suggestions120, [120_000, 1_200_000, 12_000_000])
    }

    // MARK: - 8. Xử lý ca biên SmartVNDSuggestion (0, số âm, overflow)

    func testSmartVNDChipsEdgeCasesZeroNegativeInvalid() {
        // Nhập 0 hoặc rỗng
        XCTAssertTrue(SmartVNDSuggestion.suggestions(for: "0").isEmpty)
        XCTAssertTrue(SmartVNDSuggestion.suggestions(for: "").isEmpty)
        XCTAssertTrue(SmartVNDSuggestion.suggestions(for: "   ").isEmpty)

        // Ký tự chữ
        XCTAssertTrue(SmartVNDSuggestion.suggestions(for: "abc").isEmpty)

        // Số vượt quá 999 tỷ (vượt giới hạn an toàn)
        let suggestionsHuge = SmartVNDSuggestion.suggestions(for: "9999999999999")
        XCTAssertTrue(suggestionsHuge.isEmpty, "Số quá lớn vượt ngưỡng phải trả về mảng rỗng")
    }
}

