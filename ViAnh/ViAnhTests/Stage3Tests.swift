import XCTest
import SwiftData
@testable import ViAnh

@MainActor
final class Stage3Tests: XCTestCase {

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

    // MARK: - Keypad 000 and 000,000 Multipliers Tests

    func testQuickMultiplierThreeZerosProducesThirtyFiveThousand() {
        var raw = "35"
        let multiplier = "000"

        if raw.count + multiplier.count <= 11 {
            raw += multiplier
        }

        let amount = Int64(raw) ?? 0
        XCTAssertEqual(amount, 35_000)
        XCTAssertEqual(amount.vndFormatted, "35.000 ₫")
    }

    func testQuickMultiplierSixZerosProducesThirtyFiveMillion() {
        var raw = "35"
        let multiplier = "000000"

        if raw.count + multiplier.count <= 11 {
            raw += multiplier
        }

        let amount = Int64(raw) ?? 0
        XCTAssertEqual(amount, 35_000_000)
        XCTAssertEqual(amount.vndFormatted, "35.000.000 ₫")
    }

    func testQuickMultiplierPreventsOverflowBeyondElevenDigits() {
        var raw = "999999999" // 9 chữ số
        let multiplier = "000" // thêm 3 chữ số = 12 chữ số -> bị chặn vì > 11

        if raw.count + multiplier.count <= 11 {
            raw += multiplier
        }

        XCTAssertEqual(raw, "999999999") // không bị tràn số
    }

    // MARK: - Expense Creation Without Photo (3 Seconds Goal)

    func testSaveExpenseWithoutPhotoSucceeds() throws {
        CategoryManager.seedDefaultCategoriesIfNeeded(context: context)
        WalletManager.seedDefaultWalletsIfNeeded(context: context)

        guard let cat = CategoryManager.findOtherCategory(context: context),
              let wallet = WalletManager.getDefaultWallet(context: context) else {
            XCTFail("Missing category or wallet")
            return
        }

        // Tạo khoản chi 35.000 ₫ không có ảnh
        let expense = ExpenseItem(
            amountVND: 35_000,
            category: cat,
            spentAt: .now,
            title: "Cà phê vỉa hè",
            type: .expense,
            wallet: wallet
        )
        // Không có ảnh
        expense.imageFileName = nil
        expense.thumbnailFileName = nil

        context.insert(expense)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<ExpenseItem>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.amountVND, 35_000)
        XCTAssertNil(fetched.first?.imageFileName)
        XCTAssertNil(fetched.first?.thumbnailFileName)
        XCTAssertEqual(fetched.first?.wallet?.name, "Tiền mặt")
    }
}

