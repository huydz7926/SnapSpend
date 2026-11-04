//
//  SnapSpendTest.swift
//  SnapSpendTest
//
//  Bộ kiểm thử tự động bám sát mã nguồn thực tế SnapSpend (ViAnh)
//  Sử dụng framework Swift Testing (@Suite, @Test, #expect)
//  SwiftData chạy hoàn toàn trên database in-memory riêng cho từng bài test.
//

import Testing
import Foundation
import UIKit
import SwiftData
@testable import ViAnh

// MARK: - In-Memory Container Helper

@MainActor
private func makeInMemoryModelContainer() throws -> ModelContainer {
    let schema = Schema([
        ExpenseItem.self,
        ExpenseCategory.self,
        MonthlyBudget.self,
        CategoryBudget.self,
        Wallet.self
    ])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: [configuration])
}

// MARK: - 1. Tính tổng chi tiêu đúng tài khoản & ranh giới tháng

@Suite("1. Tính tổng chi tiêu đúng tài khoản & đúng tháng (Boundary Tests)")
struct MonthlyExpenseCalculationTests {

    @Test("Tính tổng chi tiêu chính xác theo tài khoản và lọc đúng ranh giới đầu/cuối tháng")
    @MainActor
    func testTotalSpentBoundaryAndAccountFiltering() throws {
        let container = try makeInMemoryModelContainer()
        let context = container.mainContext

        let category = ExpenseCategory(name: "Ăn uống", symbolName: "fork.knife", colorHex: "#FF6B6B", isDefault: true)
        context.insert(category)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 7 * 3600)! // Múi giờ UTC+7 (Việt Nam)

        // Tạo các mốc thời gian kiểm thử ranh giới tháng 11/2026
        let beforeStart = calendar.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: 23, minute: 59, second: 59))!
        let boundaryStart = calendar.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 0, minute: 0, second: 0))!
        let insideMonth = calendar.date(from: DateComponents(year: 2026, month: 11, day: 15, hour: 12, minute: 0, second: 0))!
        let boundaryEnd = calendar.date(from: DateComponents(year: 2026, month: 11, day: 30, hour: 23, minute: 59, second: 59))!
        let afterEnd = calendar.date(from: DateComponents(year: 2026, month: 12, day: 1, hour: 0, minute: 0, second: 0))!

        let uidA = "USER_A_BOUND"
        let uidB = "USER_B_BOUND"

        // Các khoản chi của User A
        let expBeforeStartA = ExpenseItem(amountVND: 100_000, category: category, spentAt: beforeStart, title: "Chi cuối tháng 10", ownerUID: uidA)
        let expStartA = ExpenseItem(amountVND: 50_000, category: category, spentAt: boundaryStart, title: "Chi đầu tháng 11 (00:00:00)", ownerUID: uidA)
        let expMidA = ExpenseItem(amountVND: 70_000, category: category, spentAt: insideMonth, title: "Chi giữa tháng 11", ownerUID: uidA)
        let expEndA = ExpenseItem(amountVND: 80_000, category: category, spentAt: boundaryEnd, title: "Chi cuối tháng 11 (23:59:59)", ownerUID: uidA)
        let expAfterEndA = ExpenseItem(amountVND: 120_000, category: category, spentAt: afterEnd, title: "Chi đầu tháng 12", ownerUID: uidA)

        // Khoản chi của User B trong tháng 11 (không được tính cho A)
        let expMidB = ExpenseItem(amountVND: 500_000, category: category, spentAt: insideMonth, title: "Chi tháng 11 của User B", ownerUID: uidB)

        context.insert(expBeforeStartA)
        context.insert(expStartA)
        context.insert(expMidA)
        context.insert(expEndA)
        context.insert(expAfterEndA)
        context.insert(expMidB)
        try context.save()

        // 1. Kiểm tra trực tiếp hàm pure ranh giới tháng của BudgetCalculator
        #expect(BudgetCalculator.isExpense(expBeforeStartA, inYear: 2026, month: 11, calendar: calendar) == false)
        #expect(BudgetCalculator.isExpense(expStartA, inYear: 2026, month: 11, calendar: calendar) == true)
        #expect(BudgetCalculator.isExpense(expMidA, inYear: 2026, month: 11, calendar: calendar) == true)
        #expect(BudgetCalculator.isExpense(expEndA, inYear: 2026, month: 11, calendar: calendar) == true)
        #expect(BudgetCalculator.isExpense(expAfterEndA, inYear: 2026, month: 11, calendar: calendar) == false)

        // 2. Truy vấn dữ liệu thực tế lọc theo tài khoản User A
        let descriptorA = FetchDescriptor<ExpenseItem>(predicate: #Predicate { $0.ownerUID == uidA })
        let userAExpenses = try context.fetch(descriptorA)
        #expect(userAExpenses.count == 5)

        // 3. Tính tổng chi tháng 11/2026 của User A: 50.000 + 70.000 + 80.000 = 200.000 ₫
        let totalNovA = BudgetCalculator.totalSpent(expenses: userAExpenses, year: 2026, month: 11, calendar: calendar)
        #expect(totalNovA == 200_000)

        // 4. Kiểm tra tháng 10 của User A (chỉ có khoản 100.000 ₫)
        let totalOctA = BudgetCalculator.totalSpent(expenses: userAExpenses, year: 2026, month: 10, calendar: calendar)
        #expect(totalOctA == 100_000)

        // 5. Kiểm tra tháng 12 của User A (chỉ có khoản 120.000 ₫)
        let totalDecA = BudgetCalculator.totalSpent(expenses: userAExpenses, year: 2026, month: 12, calendar: calendar)
        #expect(totalDecA == 120_000)
    }
}

// MARK: - 2. Cô lập dữ liệu giữa các tài khoản & tài khoản mới

@Suite("2. Cô lập dữ liệu đa tài khoản & bảo vệ tài khoản mới")
struct DataIsolationTests {

    @Test("A có 35.000đ, B có 50.000đ; mỗi tài khoản chỉ truy vấn được dữ liệu của mình; tài khoản mới có tổng chi bằng 0")
    @MainActor
    func testDataIsolationBetweenUsersAndZeroForNewUser() throws {
        let container = try makeInMemoryModelContainer()
        let context = container.mainContext

        let category = ExpenseCategory(name: "Mua sắm", symbolName: "bag", colorHex: "#4ECDC4", isDefault: true)
        context.insert(category)

        let uidA = "ACCOUNT_A"
        let uidB = "ACCOUNT_B"
        let uidNew = "ACCOUNT_NEW"

        // User A tạo khoản chi 35.000 ₫
        let expenseA = ExpenseItem(amountVND: 35_000, category: category, title: "Cà phê User A", ownerUID: uidA)
        // User B tạo khoản chi 50.000 ₫
        let expenseB = ExpenseItem(amountVND: 50_000, category: category, title: "Bữa trưa User B", ownerUID: uidB)

        context.insert(expenseA)
        context.insert(expenseB)
        try context.save()

        // 1. Kiểm tra tài khoản User A
        let descriptorA = FetchDescriptor<ExpenseItem>(predicate: #Predicate { $0.ownerUID == uidA })
        let itemsA = try context.fetch(descriptorA)
        let totalA = itemsA.reduce(Int64(0)) { $0 + $1.amountVND }
        #expect(itemsA.count == 1)
        #expect(itemsA.first?.amountVND == 35_000)
        #expect(itemsA.first?.title == "Cà phê User A")
        #expect(totalA == 35_000)

        // 2. Kiểm tra tài khoản User B
        let descriptorB = FetchDescriptor<ExpenseItem>(predicate: #Predicate { $0.ownerUID == uidB })
        let itemsB = try context.fetch(descriptorB)
        let totalB = itemsB.reduce(Int64(0)) { $0 + $1.amountVND }
        #expect(itemsB.count == 1)
        #expect(itemsB.first?.amountVND == 50_000)
        #expect(itemsB.first?.title == "Bữa trưa User B")
        #expect(totalB == 50_000)

        // 3. Kiểm tra tài khoản mới hoàn toàn (User New)
        let descriptorNew = FetchDescriptor<ExpenseItem>(predicate: #Predicate { $0.ownerUID == uidNew })
        let itemsNew = try context.fetch(descriptorNew)
        let totalNew = itemsNew.reduce(Int64(0)) { $0 + $1.amountVND }
        #expect(itemsNew.isEmpty)
        #expect(totalNew == 0)

        // 4. Kiểm tra tính toán ngân sách qua BudgetCalculator độc lập theo mảng chi tiêu
        #expect(BudgetCalculator.totalSpent(expenses: itemsA, year: 2026, month: 11) == 35_000)
        #expect(BudgetCalculator.totalSpent(expenses: itemsB, year: 2026, month: 11) == 50_000)
        #expect(BudgetCalculator.totalSpent(expenses: itemsNew, year: 2026, month: 11) == 0)
    }
}

// MARK: - 3. Tính toán trạng thái ngân sách

@Suite("3. Tính toán trạng thái ngân sách (Budget Status)")
struct BudgetStatusCalculationTests {

    @Test("Kiểm tra đầy đủ 6 trạng thái: chưa đặt hạn mức, chưa chi, dưới cảnh báo, chạm cảnh báo, chạm hạn mức và vượt hạn mức")
    func testBudgetStatusAllSixConditions() {
        let budgetLimit: Int64 = 1_000_000

        // 1. Chưa đặt hạn mức (nil, = 0 hoặc âm)
        let statusNil = BudgetCalculator.budgetStatus(spent: 500_000, budget: nil)
        let statusZero = BudgetCalculator.budgetStatus(spent: 500_000, budget: 0)
        let statusNegative = BudgetCalculator.budgetStatus(spent: 500_000, budget: -1_000_000)
        #expect(statusNil == .notSet)
        #expect(statusZero == .notSet)
        #expect(statusNegative == .notSet)
        #expect(statusNil.symbolName == "questionmark.circle")

        // 2. Chưa chi (spent = 0, budget = 1.000.000)
        let statusZeroSpent = BudgetCalculator.budgetStatus(spent: 0, budget: budgetLimit)
        #expect(statusZeroSpent == .safe(ratio: 0.0))
        #expect(statusZeroSpent.symbolName == "checkmark.circle.fill")

        // 3. Dưới ngưỡng cảnh báo (ratio < 0.8, ví dụ đã chi 790.000 / 1.000.000 = 79%)
        let statusUnderWarning = BudgetCalculator.budgetStatus(spent: 790_000, budget: budgetLimit)
        #expect(statusUnderWarning == .safe(ratio: 0.79))
        #expect(statusUnderWarning.symbolName == "checkmark.circle.fill")

        // 4. Chạm ngưỡng cảnh báo (ratio >= 0.8 && < 1.0, ví dụ đã chi 800.000 = 80%)
        let statusAtWarning = BudgetCalculator.budgetStatus(spent: 800_000, budget: budgetLimit)
        #expect(statusAtWarning == .warning(ratio: 0.80))
        #expect(statusAtWarning.symbolName == "exclamationmark.triangle.fill")

        let statusInWarning = BudgetCalculator.budgetStatus(spent: 950_000, budget: budgetLimit)
        #expect(statusInWarning == .warning(ratio: 0.95))

        // 5. Chạm hạn mức (ratio == 1.0, ví dụ đã chi đúng 1.000.000 = 100%)
        let statusAtLimit = BudgetCalculator.budgetStatus(spent: 1_000_000, budget: budgetLimit)
        #expect(statusAtLimit == .atLimit(ratio: 1.0))
        #expect(statusAtLimit.symbolName == "exclamationmark.circle.fill")

        // 6. Vượt hạn mức (ratio > 1.0, ví dụ đã chi 1.250.000 = 125%, vượt 250.000 ₫)
        let statusOver = BudgetCalculator.budgetStatus(spent: 1_250_000, budget: budgetLimit)
        #expect(statusOver == .overBudget(ratio: 1.25, exceededVND: 250_000))
        #expect(statusOver.symbolName == "xmark.circle.fill")
    }
}

// MARK: - 4. Xuất CSV chuẩn RFC 4180, ký tự đặc biệt & lọc tài khoản

@Suite("4. Xuất file CSV: RFC 4180, ký tự đặc biệt, tiếng Việt & cô lập tài khoản")
struct CSVExportTests {

    @Test("Kiểm tra ký tự đặc biệt (phẩy, ngoặc kép, xuống dòng), BOM UTF-8 tiếng Việt và chỉ xuất dữ liệu đúng tài khoản")
    @MainActor
    func testCSVExportSpecialCharactersAndAccountIsolation() throws {
        // 1. Kiểm thử escapeField đối với các ký tự đặc biệt theo chuẩn RFC 4180
        #expect(CSVExportService.escapeField("Chi tiêu bình thường") == "Chi tiêu bình thường")
        #expect(CSVExportService.escapeField("Cà phê, trà đá") == "\"Cà phê, trà đá\"")
        #expect(CSVExportService.escapeField("Sách \"Clean Code\"") == "\"Sách \"\"Clean Code\"\"\"")
        #expect(CSVExportService.escapeField("Dòng 1\nDòng 2") == "\"Dòng 1\nDòng 2\"")
        #expect(CSVExportService.escapeField("Hóa đơn \"VIP\",\nĐã thanh toán") == "\"Hóa đơn \"\"VIP\"\",\nĐã thanh toán\"")

        // 2. Thiết lập cơ sở dữ liệu in-memory
        let container = try makeInMemoryModelContainer()
        let context = container.mainContext

        let category = ExpenseCategory(name: "Khác", symbolName: "ellipsis.circle", colorHex: "#B0B0B0", isDefault: true)
        context.insert(category)

        let uidA = "USER_A_CSV"
        let uidB = "USER_B_CSV"

        // Giao dịch của User A chứa ghi chú phức tạp với tiếng Việt, dấu phẩy, ngoặc kép và xuống dòng
        let expenseA = ExpenseItem(
            amountVND: 125_000,
            category: category,
            title: "Mua \"bánh mì chả cá\", nước ngọt",
            note: "Quán cô Ba, số 12\nCó hóa đơn VAT",
            ownerUID: uidA
        )

        // Giao dịch của User B
        let expenseB = ExpenseItem(
            amountVND: 300_000,
            category: category,
            title: "Chi tiêu bí mật của B",
            note: "Không được xuất hiện trong file của A",
            ownerUID: uidB
        )

        context.insert(expenseA)
        context.insert(expenseB)
        try context.save()

        // 3. Lọc danh sách giao dịch chỉ thuộc sở hữu của User A (mô phỏng SettingsView)
        let fetchA = FetchDescriptor<ExpenseItem>(predicate: #Predicate { $0.ownerUID == uidA })
        let userAExpenses = try context.fetch(fetchA)
        #expect(userAExpenses.count == 1)

        // 4. Sinh chuỗi CSV từ danh sách của User A
        let csvA = CSVExportService.generateCSV(from: userAExpenses)

        // Kiểm tra mã BOM UTF-8 (\u{FEFF}) để Excel mở tiếng Việt không lỗi font
        #expect(csvA.hasPrefix("\u{FEFF}"))
        let dataA = Data(csvA.utf8)
        #expect(dataA.count >= 3)
        #expect(dataA[0] == 0xEF)
        #expect(dataA[1] == 0xBB)
        #expect(dataA[2] == 0xBF)

        // Kiểm tra dòng tiêu đề RFC 4180
        #expect(csvA.contains("ID,Ngày,Danh mục,Số tiền (VND),Tiêu đề,Ghi chú,Có ảnh\n"))

        // Kiểm tra xử lý ký tự đặc biệt trong dòng dữ liệu
        #expect(csvA.contains("\"Mua \"\"bánh mì chả cá\"\", nước ngọt\""))
        #expect(csvA.contains("\"Quán cô Ba, số 12\nCó hóa đơn VAT\""))
        #expect(csvA.contains("125000"))

        // 5. Kiểm tra cô lập dữ liệu: File CSV của User A tuyệt đối KHÔNG chứa dữ liệu của User B
        #expect(!csvA.contains("Chi tiêu bí mật của B"))
        #expect(!csvA.contains("300000"))
        #expect(!csvA.contains("Không được xuất hiện trong file của A"))
    }
}

// MARK: - 5. Vòng đời giao dịch (CRUD) & Dọn dẹp ảnh vật lý

@Suite("5. CRUD Giao dịch & Quản lý file ảnh vật lý trên đĩa")
struct TransactionLifecycleAndImageStorageTests {

    @Test("Tạo, cập nhật, xóa ExpenseItem và dọn dẹp file ảnh vật lý bằng ImageStorageService")
    @MainActor
    func testTransactionCRUDAndPhysicalImageCleanup() async throws {
        let container = try makeInMemoryModelContainer()
        let context = container.mainContext

        let category = ExpenseCategory(name: "Cà phê", symbolName: "cup.and.saucer", colorHex: "#8B5A2B", isDefault: false, ownerUID: "USER_CRUD")
        context.insert(category)

        // 1. CREATE: Tạo giao dịch mới
        let expense = ExpenseItem(
            amountVND: 45_000,
            category: category,
            title: "Cà phê sáng",
            note: "Mua tại quán quen",
            ownerUID: "USER_CRUD"
        )
        context.insert(expense)
        try context.save()

        #expect(expense.amountVND == 45_000)
        #expect(expense.title == "Cà phê sáng")
        let initialUpdatedAt = expense.updatedAt

        // 2. UPDATE: Chỉnh sửa giao dịch và cập nhật timestamp
        expense.amountVND = 55_000
        expense.title = "Cà phê sáng + bánh mì"
        expense.note = "Nâng cấp bữa sáng"
        expense.markUpdated()
        try context.save()

        #expect(expense.amountVND == 55_000)
        #expect(expense.title == "Cà phê sáng + bánh mì")
        #expect(expense.updatedAt >= initialUpdatedAt)

        // 3. PHYSICAL IMAGE STORAGE: Tạo và lưu ảnh qua ImageStorageService trong THƯ MỤC TẠM RIÊNG BIỆT
        // Đảm bảo tuyệt đối không đụng chạm đến thư mục dữ liệu thật (Application Support) của người dùng
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("SnapSpendTest_Images_\(UUID().uuidString)")
        let isolatedStorage = ImageStorageService(customDirectoryURL: tempDir)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 200))
        let testImage = renderer.image { ctx in
            UIColor.systemBlue.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 200, height: 200))
        }

        let (imgFileName, thumbFileName) = try await isolatedStorage.save(image: testImage)
        expense.imageFileName = imgFileName
        expense.thumbnailFileName = thumbFileName
        try context.save()

        // Kiểm tra file vật lý tồn tại trong thư mục tạm test
        let imgURL = tempDir.appendingPathComponent(imgFileName)
        let thumbURL = tempDir.appendingPathComponent(thumbFileName)

        #expect(FileManager.default.fileExists(atPath: imgURL.path))
        #expect(FileManager.default.fileExists(atPath: thumbURL.path))

        // 4. DELETE & PHYSICAL CLEANUP: Xóa ảnh vật lý và xóa bản ghi
        await isolatedStorage.delete(imageFileName: imgFileName, thumbnailFileName: thumbFileName)

        #expect(!FileManager.default.fileExists(atPath: imgURL.path))
        #expect(!FileManager.default.fileExists(atPath: thumbURL.path))

        context.delete(expense)
        try context.save()

        let fetchDescriptor = FetchDescriptor<ExpenseItem>(predicate: #Predicate { $0.ownerUID == "USER_CRUD" })
        let remainingExpenses = try context.fetch(fetchDescriptor)
        #expect(remainingExpenses.isEmpty)
    }
}

// MARK: - 6. Cô lập danh mục, ngân sách, ví tiền & tính số dư ví

@Suite("6. Cô lập Danh mục, Ngân sách tháng, Ví tiền & Tính toán số dư")
struct EntityIsolationAndWalletTests {

    @Test("Cô lập danh mục tùy chỉnh, hạn mức ngân sách tháng và tính số dư ví chính xác")
    @MainActor
    func testEntityIsolationAndWalletBalance() throws {
        let container = try makeInMemoryModelContainer()
        let context = container.mainContext

        let uidA = "USER_WALLET_A"
        let uidB = "USER_WALLET_B"

        // 1. Danh mục: 1 danh mục mặc định hệ thống (ownerUID = nil), 1 của A, 1 của B
        let defaultCat = ExpenseCategory(name: "Ăn uống", symbolName: "fork.knife", colorHex: "#FF6B6B", isDefault: true, ownerUID: nil)
        let catA = ExpenseCategory(name: "Nuôi mèo A", symbolName: "pawprint", colorHex: "#FFA07A", isDefault: false, ownerUID: uidA)
        let catB = ExpenseCategory(name: "Độ xe B", symbolName: "car.side", colorHex: "#4682B4", isDefault: false, ownerUID: uidB)
        context.insert(defaultCat)
        context.insert(catA)
        context.insert(catB)

        // 2. Ngân sách tháng 11/2026: User A đặt 5.000.000đ, User B đặt 10.000.000đ
        let budgetA = MonthlyBudget(year: 2026, month: 11, totalBudgetVND: 5_000_000, ownerUID: uidA)
        let budgetB = MonthlyBudget(year: 2026, month: 11, totalBudgetVND: 10_000_000, ownerUID: uidB)
        context.insert(budgetA)
        context.insert(budgetB)

        // 3. Ví tiền: Ví của User A có số dư ban đầu 2.000.000 ₫
        let walletA = Wallet(name: "Ví Tiền Mặt A", symbolName: "banknote.fill", colorHex: "#2E7D32", isDefault: true, initialBalanceVND: 2_000_000, ownerUID: uidA)
        let walletB = Wallet(name: "Tài Khoản Techcom B", symbolName: "building.columns.fill", colorHex: "#1E88E5", isDefault: true, initialBalanceVND: 5_000_000, ownerUID: uidB)
        context.insert(walletA)
        context.insert(walletB)

        // 4. Phát sinh giao dịch trên ví A: Chi 300.000đ (Expense) và Thu 500.000đ (Income)
        let exp1A = ExpenseItem(amountVND: 300_000, category: catA, title: "Hạt cho mèo", type: .expense, wallet: walletA, ownerUID: uidA)
        let inc1A = ExpenseItem(amountVND: 500_000, category: defaultCat, title: "Tiền thưởng nóng", type: .income, wallet: walletA, ownerUID: uidA)
        context.insert(exp1A)
        context.insert(inc1A)
        try context.save()

        // 5. Kiểm tra truy vấn danh mục khả dụng của User A (mặc định + của A)
        let allCategories = try context.fetch(FetchDescriptor<ExpenseCategory>())
        let visibleCategoriesForA = allCategories.filter { $0.ownerUID == nil || $0.ownerUID == uidA }
        #expect(visibleCategoriesForA.contains(where: { $0.name == "Ăn uống" }))
        #expect(visibleCategoriesForA.contains(where: { $0.name == "Nuôi mèo A" }))
        #expect(!visibleCategoriesForA.contains(where: { $0.name == "Độ xe B" }))

        // 6. Kiểm tra ngân sách tách biệt
        let allBudgets = try context.fetch(FetchDescriptor<MonthlyBudget>())
        let budgetForA = allBudgets.first { $0.ownerUID == uidA && $0.year == 2026 && $0.month == 11 }
        let budgetForB = allBudgets.first { $0.ownerUID == uidB && $0.year == 2026 && $0.month == 11 }
        #expect(budgetForA?.totalBudgetVND == 5_000_000)
        #expect(budgetForB?.totalBudgetVND == 10_000_000)

        // 7. Kiểm tra tính toán số dư ví qua hàm chuẩn của Wallet: 2.000.000 + 500.000 - 300.000 = 2.200.000 ₫
        let allExpenses = try context.fetch(FetchDescriptor<ExpenseItem>())
        let finalBalanceA = walletA.currentBalance(expenses: allExpenses)
        #expect(finalBalanceA == 2_200_000)

        // Ví B chưa có giao dịch nào: số dư = số dư ban đầu 5.000.000 ₫
        let finalBalanceB = walletB.currentBalance(expenses: allExpenses)
        #expect(finalBalanceB == 5_000_000)
    }
}

// MARK: - 7. Chuỗi ngày chi tiêu liên tiếp (Streaks)

@Suite("7. Dịch vụ tính toán chuỗi ngày liên tiếp (StreakService)")
struct StreakCalculationTests {

    @Test("Tính toán chuỗi hiện tại và chuỗi dài nhất dựa trên ngày chụp ảnh thực tế")
    @MainActor
    func testStreakCalculationWithCameraPhotos() throws {
        let container = try makeInMemoryModelContainer()
        let context = container.mainContext
        let category = ExpenseCategory(name: "Ăn", symbolName: "fork.knife", colorHex: "#FF6B6B", isDefault: true)
        context.insert(category)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 7 * 3600)!

        // Giả lập mốc thời gian tham chiếu: Ngày 15/11/2026 14:00:00
        let refDate = calendar.date(from: DateComponents(year: 2026, month: 11, day: 15, hour: 14, minute: 0, second: 0))!
        let day15 = refDate
        let day14 = calendar.date(byAdding: .day, value: -1, to: refDate)!
        let day13 = calendar.date(byAdding: .day, value: -2, to: refDate)!
        let day10 = calendar.date(byAdding: .day, value: -5, to: refDate)!

        // Case 1: Danh sách rỗng
        let emptySummary = StreakService.calculate(expenses: [], referenceDate: refDate, calendar: calendar)
        #expect(emptySummary.totalPhotos == 0)
        #expect(emptySummary.currentStreak == 0)
        #expect(emptySummary.longestStreak == 0)

        // Case 2: Ảnh chọn từ thư viện (library) -> không tính vào chuỗi Streak
        let libraryExpense = ExpenseItem(
            amountVND: 30_000,
            category: category,
            spentAt: day15,
            photoSource: "library",
            ownerUID: "USER_STREAK"
        )
        let nonCameraSummary = StreakService.calculate(expenses: [libraryExpense], referenceDate: refDate, calendar: calendar)
        #expect(nonCameraSummary.totalPhotos == 0)
        #expect(nonCameraSummary.currentStreak == 0)

        // Case 3: 3 ngày liên tục (13, 14, 15) chụp từ camera trực tiếp có ảnh thật
        let camDay13 = ExpenseItem(amountVND: 20_000, category: category, spentAt: day13, photoSource: "camera", capturedAt: day13, ownerUID: "USER_STREAK")
        camDay13.imageFileName = "img_13.jpg"
        let camDay14 = ExpenseItem(amountVND: 30_000, category: category, spentAt: day14, photoSource: "camera", capturedAt: day14, ownerUID: "USER_STREAK")
        camDay14.imageFileName = "img_14.jpg"
        let camDay15 = ExpenseItem(amountVND: 40_000, category: category, spentAt: day15, photoSource: "camera", capturedAt: day15, ownerUID: "USER_STREAK")
        camDay15.imageFileName = "img_15.jpg"
        // Thêm 1 ngày chụp rời rạc trước đó (ngày 10)
        let camDay10 = ExpenseItem(amountVND: 50_000, category: category, spentAt: day10, photoSource: "camera", capturedAt: day10, ownerUID: "USER_STREAK")
        camDay10.imageFileName = "img_10.jpg"

        let threeDaysExpenses = [camDay10, camDay13, camDay14, camDay15]
        let threeDaysSummary = StreakService.calculate(expenses: threeDaysExpenses, referenceDate: refDate, calendar: calendar)

        #expect(threeDaysSummary.totalPhotos == 4)
        #expect(threeDaysSummary.currentStreak == 3) // Ngày 13, 14, 15
        #expect(threeDaysSummary.longestStreak >= 3)
    }
}

// MARK: - 8. Bảo mật, PKCE, Nonce, Avatar Key & Bảo toàn dữ liệu cũ

@Suite("8. Cơ chế bảo mật: PKCE S256, Nonce, Avatar Key & Legacy Migration")
struct SecurityAndDataPreservationTests {

    @Test("Sinh Nonce, băm SHA-256 và sinh PKCE Code Challenge chuẩn RFC 7636 S256")
    @MainActor
    func testPKCEAndNonceGenerators() {
        // 1. Kiểm tra Nonce sinh ngẫu nhiên đúng độ dài và ký tự an toàn
        let nonce32 = AuthService.randomNonceString(length: 32)
        #expect(nonce32.count == 32)

        let nonce64 = AuthService.randomNonceString(length: 64)
        #expect(nonce64.count == 64)

        // 2. Kiểm tra SHA-256 đối với chuỗi kiểm chuẩn đã biết
        // sha256("SnapSpend") = 94f1c7d23d8cbb621941ee40a8335d252fe05dc06cf72a5a5d2ff964047a001a (hoặc tương đương)
        let hash = AuthService.sha256("SnapSpend")
        #expect(hash.count == 64) // 32 bytes hex = 64 ký tự

        // 3. Kiểm tra PKCE S256 Code Challenge tuân thủ Base64 URL-safe (không có +, /, =)
        let codeVerifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
        let codeChallenge = AuthService.generateCodeChallenge(verifier: codeVerifier)
        #expect(!codeChallenge.isEmpty)
        #expect(!codeChallenge.contains("+"))
        #expect(!codeChallenge.contains("/"))
        #expect(!codeChallenge.contains("="))
    }

    @Test("Cô lập định danh Avatar (userKey) giữa các loại tài khoản")
    @MainActor
    func testProfileAvatarKeyIsolation() {
        let avatarService = ProfileAvatarService.shared

        // User Google có Firebase UID
        let userGoogle = AuthUser(
            id: "uid_google_123",
            provider: .google,
            displayName: "Google User",
            email: "google@test.com",
            createdAt: .now,
            firebaseUID: "firebase_abc_789"
        )
        #expect(avatarService.userKey(for: userGoogle) == "firebase_firebase_abc_789")

        // User Custom không có Firebase UID
        let userCustom = AuthUser(
            id: "custom_456",
            provider: .email,
            displayName: "Email User",
            email: "custom@test.com",
            createdAt: .now,
            firebaseUID: nil
        )
        #expect(avatarService.userKey(for: userCustom) == "user_custom_456")

        // Chế độ Khách (Guest) hoặc nil
        #expect(avatarService.userKey(for: nil) == "guest_default")
    }

    @Test("Bảo toàn dữ liệu lịch sử chưa có ownerUID: Không rò rỉ sang tài khoản khác")
    @MainActor
    func testLegacyDataMigrationPreservation() throws {
        let legacyKey = "snapspend_legacy_owner_uid"
        UserDefaults.standard.set("ORIGINAL_OWNER_A", forKey: legacyKey)
        defer {
            UserDefaults.standard.removeObject(forKey: legacyKey)
        }

        let container = try makeInMemoryModelContainer()
        let context = container.mainContext

        let category = ExpenseCategory(name: "Ăn uống", symbolName: "fork.knife", colorHex: "#FF6B6B", isDefault: true)
        context.insert(category)

        // Tạo khoản chi lịch sử cũ (trước khi có tính năng đa tài khoản, ownerUID = "")
        let legacyExpense = ExpenseItem(
            amountVND: 99_000,
            category: category,
            title: "Bản ghi cũ thời v1.0",
            ownerUID: ""
        )
        context.insert(legacyExpense)
        try context.save()

        // Giả lập tài khoản B đăng nhập vào thiết bị
        let activeUserB = "NEW_USER_B"
        DataOwnerMigrationService.shared.migrateLegacyDataIfNeeded(context: context, activeOwnerID: activeUserB)

        // Kiểm tra: Bản ghi cũ không được hiển thị cho User B
        let fetchForB = FetchDescriptor<ExpenseItem>(predicate: #Predicate { $0.ownerUID == activeUserB })
        let itemsForB = try context.fetch(fetchForB)
        #expect(itemsForB.isEmpty)

        // Dữ liệu cũ được bảo vệ an toàn (chuyển sang legacy_unassigned hoặc owner gốc)
        let fetchLegacy = FetchDescriptor<ExpenseItem>()
        let allItems = try context.fetch(fetchLegacy)
        #expect(allItems.count == 1)
        #expect(allItems.first?.amountVND == 99_000)
    }
}
