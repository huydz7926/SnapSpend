import XCTest
import SwiftData
@testable import ViAnh

@MainActor
final class SnapSpendServicesTests: XCTestCase {

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

    // MARK: - StreakService Tests

    func testTotalCameraPhotosCountsOnlyCameraSourceWithThumbnail() throws {
        guard let cat = CategoryManager.findOtherCategory(context: context) else {
            XCTFail("Missing other category")
            return
        }

        // 1. Khoản chi có ảnh camera -> được tính
        let item1 = ExpenseItem(amountVND: 50_000, category: cat, spentAt: .now, type: .expense)
        item1.thumbnailFileName = "thumb1.jpg"
        item1.photoSourceRaw = "camera"

        // 2. Khoản chi có ảnh từ thư viện (gallery) -> không tính vào số ảnh camera
        let item2 = ExpenseItem(amountVND: 70_000, category: cat, spentAt: .now, type: .expense)
        item2.thumbnailFileName = "thumb2.jpg"
        item2.photoSourceRaw = "gallery"

        // 3. Khoản chi không có ảnh -> không tính
        let item3 = ExpenseItem(amountVND: 20_000, category: cat, spentAt: .now, type: .expense)
        item3.thumbnailFileName = nil
        item3.photoSourceRaw = "camera"

        let expenses = [item1, item2, item3]
        let summary = StreakService.calculate(expenses: expenses)
        XCTAssertEqual(summary.totalPhotos, 1, "Chỉ ảnh chụp camera có thumbnail mới được tính vào tổng ảnh")
    }

    func testStreakConsecutiveDaysCalculation() {
        guard let cat = CategoryManager.findOtherCategory(context: context) else {
            XCTFail("Missing other category")
            return
        }

        let calendar = Calendar.current
        let today = Date.now
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!

        let item1 = ExpenseItem(amountVND: 30_000, category: cat, spentAt: today, type: .expense)
        item1.thumbnailFileName = "thumb1.jpg"
        item1.capturedAt = today

        let item2 = ExpenseItem(amountVND: 40_000, category: cat, spentAt: yesterday, type: .expense)
        item2.thumbnailFileName = "thumb2.jpg"
        item2.capturedAt = yesterday

        let item3 = ExpenseItem(amountVND: 50_000, category: cat, spentAt: twoDaysAgo, type: .expense)
        item3.thumbnailFileName = "thumb3.jpg"
        item3.capturedAt = twoDaysAgo

        let expenses = [item1, item2, item3]
        let streak = StreakService.calculate(expenses: expenses, referenceDate: today)

        XCTAssertEqual(streak.currentStreak, 3, "3 ngày liên tiếp chụp ảnh thì chuỗi phải là 3")
        XCTAssertEqual(streak.longestStreak, 3, "Kỷ lục chuỗi dài nhất phải là 3")
    }

    func testStreakMaintainedIfTodayHasNoPhotoYet() {
        guard let cat = CategoryManager.findOtherCategory(context: context) else {
            XCTFail("Missing other category")
            return
        }

        let calendar = Calendar.current
        let today = Date.now
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        // Chỉ có ảnh hôm qua, hôm nay chưa chụp
        let item1 = ExpenseItem(amountVND: 30_000, category: cat, spentAt: yesterday, type: .expense)
        item1.thumbnailFileName = "thumb1.jpg"
        item1.capturedAt = yesterday

        let expenses = [item1]
        let streak = StreakService.calculate(expenses: expenses, referenceDate: today)

        XCTAssertEqual(streak.currentStreak, 1, "Chuỗi vẫn duy trì nếu hôm nay chưa chụp nhưng hôm qua đã chụp")
    }

    // MARK: - CurrencyExchangeService Tests

    func testCurrencyConversionAndFormatting() {
        let service = CurrencyExchangeService.shared
        service.displayCurrency = .vnd
        service.usdToVndRate = 25_000.0
        service.eurToVndRate = 27_000.0

        let formattedVnd = service.formatFromVND(100_000)
        XCTAssertTrue(formattedVnd.contains("100.000") && formattedVnd.contains("₫"))

        service.displayCurrency = .usd
        let convertedUsd = service.convert(amount: 100_000, from: "VND", to: .usd)
        XCTAssertEqual(convertedUsd, 4.0, accuracy: 0.01)

        let formattedUsd = service.format(amountVND: 100_000, targetCurrency: .usd)
        XCTAssertEqual(formattedUsd, "$4.00")

        // Khôi phục mặc định VND
        service.displayCurrency = .vnd
    }

    // MARK: - LocalizationManager Tests

    func testLocalizationManagerTranslations() {
        let manager = LocalizationManager.shared
        manager.currentLanguage = .vietnamese
        XCTAssertEqual(manager.t("tab_home"), "Trang chủ")
        XCTAssertEqual(manager.t("label_streak"), "Chuỗi")

        manager.currentLanguage = .english
        XCTAssertEqual(manager.t("tab_home"), "Home")
        XCTAssertEqual(manager.t("label_streak"), "Streak")

        // Khôi phục mặc định Tiếng Việt
        manager.currentLanguage = .vietnamese
    }

    // MARK: - Category Safe Replacement Tests

    func testDeleteCategoryWithCustomReplacementTransfersExpenses() throws {
        guard let otherCat = CategoryManager.findOtherCategory(context: context) else {
            XCTFail("Missing fallback other category")
            return
        }

        // Tạo 1 category mới
        let customCat = ExpenseCategory(name: "Đồ chơi công nghệ", symbolName: "laptopcomputer", colorHex: "#4ECDC4", isDefault: false, sortOrder: 99)
        context.insert(customCat)
        try context.save()

        // Tạo 1 khoản chi thuộc customCat
        let expense = ExpenseItem(amountVND: 2_500_000, category: customCat, spentAt: .now, type: .expense)
        context.insert(expense)
        try context.save()

        XCTAssertEqual(expense.category.name, "Đồ chơi công nghệ")

        // Xóa customCat và chuyển sang otherCat
        try CategoryManager.deleteCategory(customCat, replacementCategory: otherCat, context: context)

        let allExpenses = try context.fetch(FetchDescriptor<ExpenseItem>())
        XCTAssertEqual(allExpenses.count, 1)
        XCTAssertEqual(allExpenses.first?.category.name, "Khác", "Giao dịch phải được chuyển sang danh mục thay thế 'Khác'")
    }
}
