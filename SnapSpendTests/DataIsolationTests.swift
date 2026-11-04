import XCTest
import SwiftData
@testable import ViAnh

// MARK: - DataIsolationTests

/// Bộ kiểm thử tự động kiểm tra tính cô lập dữ liệu theo Firebase UID (ownerUID)
/// Đảm bảo không rò rỉ dữ liệu giữa các tài khoản và bảo toàn dữ liệu lịch sử
@MainActor
final class DataIsolationTests: XCTestCase {

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

    // MARK: - 1. Khoản chi tiêu phân tách theo ownerUID

    func testCreateAndQueryExpensesSeparatedByOwnerUID() throws {
        let catDescriptor = FetchDescriptor<ExpenseCategory>(predicate: #Predicate { $0.isDefault == true })
        guard let defaultCat = try context.fetch(catDescriptor).first else {
            XCTFail("Cần ít nhất một danh mục mặc định để chạy kiểm thử.")
            return
        }

        let userA_UID = "UID_USER_A_12345"
        let userB_UID = "UID_USER_B_67890"

        // User A tạo 2 khoản chi: 35.000 ₫ và 65.000 ₫
        let expenseA1 = ExpenseItem(amountVND: 35_000, category: defaultCat, title: "Cà phê sáng", ownerUID: userA_UID)
        let expenseA2 = ExpenseItem(amountVND: 65_000, category: defaultCat, title: "Cơm trưa", ownerUID: userA_UID)
        context.insert(expenseA1)
        context.insert(expenseA2)

        // User B tạo 1 khoản chi: 120.000 ₫
        let expenseB1 = ExpenseItem(amountVND: 120_000, category: defaultCat, title: "Mua sách", ownerUID: userB_UID)
        context.insert(expenseB1)

        try context.save()

        // Truy vấn dữ liệu cho User A
        let descriptorA = FetchDescriptor<ExpenseItem>(predicate: #Predicate { $0.ownerUID == userA_UID })
        let itemsA = try context.fetch(descriptorA)
        let totalA = itemsA.reduce(Int64(0)) { $0 + $1.amountVND }

        // Truy vấn dữ liệu cho User B
        let descriptorB = FetchDescriptor<ExpenseItem>(predicate: #Predicate { $0.ownerUID == userB_UID })
        let itemsB = try context.fetch(descriptorB)
        let totalB = itemsB.reduce(Int64(0)) { $0 + $1.amountVND }

        XCTAssertEqual(itemsA.count, 2, "User A phải có đúng 2 khoản chi")
        XCTAssertEqual(totalA, 100_000, "Tổng chi của User A phải là 100.000 ₫")

        XCTAssertEqual(itemsB.count, 1, "User B phải có đúng 1 khoản chi")
        XCTAssertEqual(totalB, 120_000, "Tổng chi của User B phải là 120.000 ₫")

        // Kiểm tra tài khoản User C hoàn toàn mới
        let userC_UID = "UID_USER_C_NEW"
        let descriptorC = FetchDescriptor<ExpenseItem>(predicate: #Predicate { $0.ownerUID == userC_UID })
        let itemsC = try context.fetch(descriptorC)
        XCTAssertEqual(itemsC.count, 0, "User C mới chưa có giao dịch nào phải trả về 0")
    }

    // MARK: - 2. Ngân sách tháng phân tách theo ownerUID

    func testBudgetSeparatedByOwnerUID() throws {
        let userA_UID = "UID_USER_A_BUDGET"
        let userB_UID = "UID_USER_B_BUDGET"

        let budgetA = MonthlyBudget(year: 2026, month: 11, totalBudgetVND: 10_000_000, ownerUID: userA_UID)
        let budgetB = MonthlyBudget(year: 2026, month: 11, totalBudgetVND: 5_000_000, ownerUID: userB_UID)

        context.insert(budgetA)
        context.insert(budgetB)
        try context.save()

        let fetchA = FetchDescriptor<MonthlyBudget>(predicate: #Predicate { $0.ownerUID == userA_UID })
        let resultsA = try context.fetch(fetchA)
        XCTAssertEqual(resultsA.count, 1)
        XCTAssertEqual(resultsA.first?.totalBudgetVND, 10_000_000)

        let fetchB = FetchDescriptor<MonthlyBudget>(predicate: #Predicate { $0.ownerUID == userB_UID })
        let resultsB = try context.fetch(fetchB)
        XCTAssertEqual(resultsB.count, 1)
        XCTAssertEqual(resultsB.first?.totalBudgetVND, 5_000_000)
    }

    // MARK: - 3. Danh mục tùy chỉnh phân tách theo ownerUID

    func testCustomCategoriesSeparation() throws {
        let userA_UID = "UID_A_CAT"
        let userB_UID = "UID_B_CAT"

        let customCatA = ExpenseCategory(
            name: "Gym & Thể Thao",
            symbolName: "figure.run",
            colorHex: "#FF5722",
            isDefault: false,
            sortOrder: 10,
            ownerUID: userA_UID
        )
        context.insert(customCatA)
        try context.save()

        // Truy vấn danh mục khả dụng cho User A: bao gồm mặc định HOẶC sở hữu bởi User A
        let allCategories = try context.fetch(FetchDescriptor<ExpenseCategory>())
        let availableForA = allCategories.filter { $0.isDefault || $0.ownerUID == userA_UID }
        let availableForB = allCategories.filter { $0.isDefault || $0.ownerUID == userB_UID }

        XCTAssertTrue(availableForA.contains { $0.name == "Gym & Thể Thao" }, "User A phải nhìn thấy danh mục riêng của mình")
        XCTAssertFalse(availableForB.contains { $0.name == "Gym & Thể Thao" }, "User B tuyệt đối KHÔNG được nhìn thấy danh mục của User A")
    }

    // MARK: - 4. 8 danh mục mặc định dùng chung cho mọi tài khoản

    func testDefaultCategoriesSharedAcrossAllUsers() throws {
        let allCategories = try context.fetch(FetchDescriptor<ExpenseCategory>())
        let defaultCategories = allCategories.filter { $0.isDefault }

        XCTAssertEqual(defaultCategories.count, 8, "Hệ thống phải có đúng 8 danh mục mặc định")
        for cat in defaultCategories {
            XCTAssertNil(cat.ownerUID, "Danh mục mặc định của hệ thống phải có ownerUID = nil")
            XCTAssertTrue(cat.isDefault, "Danh mục mặc định phải có cờ isDefault = true")
        }
    }

    // MARK: - 5. Ví tiền tùy chỉnh phân tách theo ownerUID

    func testWalletIsolationBetweenUsers() throws {
        let userA_UID = "UID_USER_A_WALLET"
        let userB_UID = "UID_USER_B_WALLET"

        let walletA = Wallet(
            name: "Ví Bí Mật A",
            symbolName: "lock.shield",
            colorHex: "#9C27B0",
            isDefault: false,
            initialBalanceVND: 50_000_000,
            ownerUID: userA_UID
        )
        context.insert(walletA)
        try context.save()

        let allWallets = try context.fetch(FetchDescriptor<Wallet>())
        let visibleToA = allWallets.filter { $0.isDefault || $0.ownerUID == userA_UID }
        let visibleToB = allWallets.filter { $0.isDefault || $0.ownerUID == userB_UID }

        XCTAssertTrue(visibleToA.contains { $0.name == "Ví Bí Mật A" })
        XCTAssertFalse(visibleToB.contains { $0.name == "Ví Bí Mật A" })
    }

    // MARK: - 6. Di chuyển dữ liệu cũ cho chủ sở hữu ban đầu

    func testLegacyDataMigrationAssignsToOriginalUser() throws {
        let cat = try context.fetch(FetchDescriptor<ExpenseCategory>(predicate: #Predicate { $0.isDefault == true })).first!
        let originalOwnerUID = "UID_ORIGINAL_FOUNDER"

        // Tạo khoản chi cũ chưa có ownerUID
        let legacyExpense = ExpenseItem(amountVND: 500_000, category: cat, title: "Tiền điện cũ", ownerUID: "")
        context.insert(legacyExpense)
        try context.save()

        UserDefaults.standard.removeObject(forKey: "snapspend_legacy_owner_uid")

        // Thực hiện migration khi User ban đầu mở app
        DataOwnerMigrationService.shared.migrateLegacyDataIfNeeded(context: context, activeOwnerID: originalOwnerUID)

        let items = try context.fetch(FetchDescriptor<ExpenseItem>())
        let migratedItem = items.first { $0.title == "Tiền điện cũ" }

        XCTAssertEqual(migratedItem?.ownerUID, originalOwnerUID, "Dữ liệu cũ phải được gán an toàn cho chủ nhân ban đầu")
    }

    // MARK: - 7. Tài khoản mới B không được nhận vơ dữ liệu cũ

    func testLegacyDataNotClaimedByNewUserB() throws {
        let cat = try context.fetch(FetchDescriptor<ExpenseCategory>(predicate: #Predicate { $0.isDefault == true })).first!
        let originalOwnerUID = "UID_ORIGINAL_FOUNDER"
        let newUserB_UID = "UID_NEW_USER_B"

        // Đã ghi nhận chủ cũ
        UserDefaults.standard.set(originalOwnerUID, forKey: "snapspend_legacy_owner_uid")

        // Có một khoản chi mồ côi chưa có UID
        let unassignedExpense = ExpenseItem(amountVND: 300_000, category: cat, title: "Khoản chi lịch sử", ownerUID: "")
        context.insert(unassignedExpense)
        try context.save()

        // User B mới đăng nhập mở app
        DataOwnerMigrationService.shared.migrateLegacyDataIfNeeded(context: context, activeOwnerID: newUserB_UID)

        let items = try context.fetch(FetchDescriptor<ExpenseItem>())
        let migratedItem = items.first { $0.title == "Khoản chi lịch sử" }

        XCTAssertNotEqual(migratedItem?.ownerUID, newUserB_UID, "Tài khoản B mới tuyệt đối không được nhận vơ dữ liệu lịch sử")
        XCTAssertEqual(migratedItem?.ownerUID, "legacy_unassigned", "Bản ghi phải được chuyển vào legacy_unassigned")
    }

    // MARK: - 8. Chuyển đổi dữ liệu phiên Khách sang tài khoản người dùng an toàn

    func testTransferGuestExpensesToUserSafely() throws {
        let cat = try context.fetch(FetchDescriptor<ExpenseCategory>(predicate: #Predicate { $0.isDefault == true })).first!
        let targetUID = "UID_VERIFIED_ACCOUNT"

        // Phiên khách có 2 khoản chi
        let guest1 = ExpenseItem(amountVND: 25_000, category: cat, title: "Bánh mì", ownerUID: "guest_local")
        let guest2 = ExpenseItem(amountVND: 40_000, category: cat, title: "Trà sữa", ownerUID: "guest_local")
        context.insert(guest1)
        context.insert(guest2)
        try context.save()

        let guestCountBefore = DataOwnerMigrationService.shared.countGuestExpenses(context: context)
        XCTAssertEqual(guestCountBefore, 2)

        // Thực hiện hợp nhất vào tài khoản đăng nhập
        let transferredCount = DataOwnerMigrationService.shared.transferGuestExpensesToUser(
            targetOwnerID: targetUID,
            context: context
        )

        XCTAssertEqual(transferredCount, 2)
        let guestCountAfter = DataOwnerMigrationService.shared.countGuestExpenses(context: context)
        XCTAssertEqual(guestCountAfter, 0, "Dữ liệu khách phải được chuyển sạch")

        let userItems = try context.fetch(FetchDescriptor<ExpenseItem>(predicate: #Predicate { $0.ownerUID == targetUID }))
        XCTAssertEqual(userItems.count, 2, "Tài khoản đăng nhập phải nhận đủ 2 giao dịch")
    }
}
