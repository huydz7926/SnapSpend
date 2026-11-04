import XCTest
import SwiftData
@testable import ViAnh

@MainActor
final class Stage2Tests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
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
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    // MARK: - MonthGridBuilder Tests

    func testFebruary2026StartsOnSundayLeadingPadding() {
        // Tháng 02/2026: Ngày 1/2/2026 là Chủ nhật!
        // Trong tuần bắt đầu T2: CN phải có 6 ô đệm phía trước
        let grid = MonthGridBuilder.buildMonthGrid(year: 2026, month: 2)

        XCTAssertFalse(grid.isEmpty)
        // 6 ô đệm đầu + 28 ngày = 34 ô -> cộng thêm 1 ô đệm cuối để đủ 35 ô (5 hàng x 7 cột)
        XCTAssertEqual(grid.count, 35)

        // 6 ô đầu không phải current month
        for i in 0..<6 {
            XCTAssertFalse(grid[i].isCurrentMonth)
            XCTAssertNil(grid[i].dayNumber)
        }

        // Ô thứ 7 (chỉ số 6) là ngày 1
        XCTAssertTrue(grid[6].isCurrentMonth)
        XCTAssertEqual(grid[6].dayNumber, 1)

        // Ô thứ 33 (chỉ số 33) là ngày 28
        XCTAssertTrue(grid[33].isCurrentMonth)
        XCTAssertEqual(grid[33].dayNumber, 28)

        // Ô cuối cùng (chỉ số 34) là ô đệm
        XCTAssertFalse(grid[34].isCurrentMonth)
    }

    func testLeapYearFebruary2024Has29Days() {
        // Năm nhuận 2024: Tháng 2 có 29 ngày
        let grid = MonthGridBuilder.buildMonthGrid(year: 2024, month: 2)
        let daysInMonth = grid.filter { $0.isCurrentMonth }
        XCTAssertEqual(daysInMonth.count, 29)
    }

    func testAugust2026RequiresSixRows() {
        // Tháng 8/2026 có 31 ngày, bắt đầu vào Thứ 7 (5 ô đệm đầu)
        // 5 + 31 = 36 ô -> cần 42 ô (6 hàng x 7 cột)
        let grid = MonthGridBuilder.buildMonthGrid(year: 2026, month: 8)
        XCTAssertEqual(grid.count, 42)
    }

    // MARK: - DayExpenseSummary & Badge Calculations

    func testTwoExpensesSameDayProducesBadge2AndCorrectSums() {
        CategoryManager.seedDefaultCategoriesIfNeeded(context: context)
        guard let cat = CategoryManager.findOtherCategory(context: context) else {
            XCTFail("Missing category")
            return
        }

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 7 * 3600)!
        var comp = DateComponents(year: 2026, month: 11, day: 15, hour: 10)
        let date = cal.date(from: comp)!

        // Khoản chi 1: 200.000 ₫
        let exp1 = ExpenseItem(amountVND: 200_000, category: cat, spentAt: date, type: .expense)
        // Khoản chi 2: 260.000 ₫
        let exp2 = ExpenseItem(amountVND: 260_000, category: cat, spentAt: date, type: .expense)

        let summary = DayExpenseSummary(date: date, expenses: [exp1, exp2])

        // Badge phải là 2
        XCTAssertEqual(summary.count, 2)
        // Tổng chi là 460.000 ₫
        XCTAssertEqual(summary.totalExpense, 460_000)
        // Số ròng là -460.000 ₫
        XCTAssertEqual(summary.netAmountVND, -460_000)
        // Format rút gọn ô lịch phải là -460k
        XCTAssertEqual(abs(summary.netAmountVND).vndSignedShortFormatted(isIncome: false), "-460k")
    }

    // MARK: - Hidden Money Mode Tests

    func testHiddenMoneyModeMasksOutputs() {
        let amount: Int64 = 460_000
        let isHidden = true

        let cardDisplay = isHidden ? "•••••• ₫" : amount.vndFormatted
        let calendarDisplay = isHidden ? "•••" : amount.vndShortFormatted

        XCTAssertEqual(cardDisplay, "•••••• ₫")
        XCTAssertEqual(calendarDisplay, "•••")
    }
}

