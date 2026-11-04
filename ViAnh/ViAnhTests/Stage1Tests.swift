import XCTest
import SwiftData
@testable import ViAnh

@MainActor
final class Stage1Tests: XCTestCase {

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

    // MARK: - VND Formatting Tests

    func testVNDFormattedFull() {
        let amount: Int64 = 460_000
        XCTAssertEqual(amount.vndFormatted, "460.000 ₫")

        let signedExpense = amount.vndSignedFormatted(isIncome: false)
        XCTAssertEqual(signedExpense, "-460.000 ₫")

        let signedIncome = amount.vndSignedFormatted(isIncome: true)
        XCTAssertEqual(signedIncome, "+460.000 ₫")
    }

    func testVNDShortFormattedForCalendarAndBadges() {
        let amount460k: Int64 = 460_000
        XCTAssertEqual(amount460k.vndShortFormatted, "460k")
        XCTAssertEqual(amount460k.vndSignedShortFormatted(isIncome: false), "-460k")
        XCTAssertEqual(amount460k.vndSignedShortFormatted(isIncome: true), "+460k")

        let amount200k: Int64 = 200_000
        XCTAssertEqual(amount200k.vndSignedShortFormatted(isIncome: true), "+200k")

        let amount1_5tr: Int64 = 1_500_000
        XCTAssertEqual(amount1_5tr.vndShortFormatted, "1,5tr")
    }

    // MARK: - Wallet Model & Manager Tests

    func testSeedDefaultWallets() throws {
        let beforeWallets = try context.fetch(FetchDescriptor<Wallet>())
        XCTAssertEqual(beforeWallets.count, 0)

        WalletManager.seedDefaultWalletsIfNeeded(context: context)

        let afterWallets = try context.fetch(FetchDescriptor<Wallet>())
        XCTAssertEqual(afterWallets.count, 3)

        let defaultWallet = WalletManager.getDefaultWallet(context: context)
        XCTAssertNotNil(defaultWallet)
        XCTAssertEqual(defaultWallet?.name, "Tiền mặt")
        XCTAssertTrue(defaultWallet?.isDefault == true)
    }

    // MARK: - Transaction Model & Income/Expense Tests

    func testTransactionTypeAndWalletAssociation() throws {
        WalletManager.seedDefaultWalletsIfNeeded(context: context)
        CategoryManager.seedDefaultCategoriesIfNeeded(context: context)

        guard let wallet = WalletManager.getDefaultWallet(context: context),
              let category = CategoryManager.findOtherCategory(context: context) else {
            XCTFail("Missing default wallet or category")
            return
        }

        // Tạo khoản chi (Expense)
        let expenseItem = ExpenseItem(
            amountVND: 460_000,
            category: category,
            spentAt: .now,
            title: "Ăn tối",
            type: .expense,
            wallet: wallet
        )
        context.insert(expenseItem)

        // Tạo khoản thu (Income)
        let incomeItem = ExpenseItem(
            amountVND: 10_000_000,
            category: category,
            spentAt: .now,
            title: "Lương tháng",
            type: .income,
            wallet: wallet
        )
        context.insert(incomeItem)

        try context.save()

        XCTAssertTrue(expenseItem.isExpense)
        XCTAssertFalse(expenseItem.isIncome)
        XCTAssertEqual(expenseItem.transactionType.arrowSymbol, "↗")

        XCTAssertTrue(incomeItem.isIncome)
        XCTAssertFalse(incomeItem.isExpense)
        XCTAssertEqual(incomeItem.transactionType.arrowSymbol, "↙")

        XCTAssertEqual(expenseItem.wallet?.name, "Tiền mặt")
        XCTAssertEqual(expenseItem.currencyCode, "VND")
    }
}

