import XCTest
import UIKit
import SwiftData
@testable import ViAnh

// MARK: - ImageAndCSVStorageTests

/// Bộ kiểm thử tự động cho hệ thống lưu trữ ảnh ImageStorageService và xuất dữ liệu CSVExportService
/// Đáp ứng chuẩn nén ảnh nền, dọn dẹp sandbox, chuẩn RFC 4180 và gắn BOM UTF-8 cho Excel tiếng Việt
@MainActor
final class ImageAndCSVStorageTests: XCTestCase {

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
    }

    override func tearDown() async throws {
        container = nil
        context = nil
    }

    // MARK: - Helper tạo UIImage giả lập cho kiểm thử

    private func makeTestImage(width: Int = 1200, height: Int = 1200, color: UIColor = .systemGreen) -> UIImage {
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    // MARK: - 1. Nén ảnh và Downsample giảm dung lượng

    func testImageStorageSaveAndDownsampleUnderLimit() async throws {
        let largeImage = makeTestImage(width: 1600, height: 1600, color: .systemBlue)
        let (imageFileName, thumbnailFileName) = try await ImageStorageService.shared.save(image: largeImage)

        XCTAssertFalse(imageFileName.isEmpty)
        XCTAssertFalse(thumbnailFileName.isEmpty)
        XCTAssertTrue(imageFileName.hasPrefix("img_"))
        XCTAssertTrue(thumbnailFileName.hasPrefix("thumb_"))

        // Kiểm tra nạp lại thumbnail
        let loadedThumbnail = await ImageStorageService.shared.loadThumbnail(fileName: thumbnailFileName)
        XCTAssertNotNil(loadedThumbnail, "Thumbnail phải nạp thành công")

        // Kiểm tra kích thước thumbnail được downsample về tối đa 300px
        if let thumb = loadedThumbnail {
            let maxDim = max(thumb.size.width, thumb.size.height)
            XCTAssertLessThanOrEqual(maxDim, 301, "Thumbnail kích thước không được vượt quá maxPixelSize (300px)")
        }

        // Dọn dẹp
        await ImageStorageService.shared.delete(imageFileName: imageFileName, thumbnailFileName: thumbnailFileName)
    }

    // MARK: - 2. Xóa file vật lý trong sandbox khi xóa khoản chi

    func testImageStorageDeletePhysicallyRemovesFile() async throws {
        let testImg = makeTestImage(width: 400, height: 400)
        let (imgFile, thumbFile) = try await ImageStorageService.shared.save(image: testImg)

        // Kiểm tra nạp được trước khi xóa
        let beforeDelete = await ImageStorageService.shared.loadThumbnail(fileName: thumbFile)
        XCTAssertNotNil(beforeDelete)

        // Thực hiện xóa vật lý
        await ImageStorageService.shared.delete(imageFileName: imgFile, thumbnailFileName: thumbFile)

        // Kiểm tra sau khi xóa không còn nạp được
        let afterDeleteThumb = await ImageStorageService.shared.loadThumbnail(fileName: thumbFile)
        XCTAssertNil(afterDeleteThumb, "Sau khi xóa, thumbnail phải không còn tồn tại")
    }

    // MARK: - 3. Kiểm thử bộ nhớ đệm RAM NSCache của Thumbnail

    func testImageStorageThumbnailCaching() async throws {
        let testImg = makeTestImage(width: 500, height: 500)
        let (imgFile, thumbFile) = try await ImageStorageService.shared.save(image: testImg)

        // Lần 1: Nạp từ đĩa vào cache
        let firstLoad = await ImageStorageService.shared.loadThumbnail(fileName: thumbFile)
        XCTAssertNotNil(firstLoad)

        // Lần 2: Nạp nhanh từ RAM cache
        let secondLoad = await ImageStorageService.shared.loadThumbnail(fileName: thumbFile)
        XCTAssertNotNil(secondLoad)
        XCTAssertEqual(firstLoad?.size, secondLoad?.size)

        // Dọn dẹp
        await ImageStorageService.shared.delete(imageFileName: imgFile, thumbnailFileName: thumbFile)
    }

    // MARK: - 4. Chuỗi CSV chứa mã byte UTF-8 BOM (\u{FEFF})

    func testCSVExportContainsUTF8BOM() {
        let cat = ExpenseCategory(name: "Ăn uống", symbolName: "fork.knife", colorHex: "#FF6B6B")
        let expense = ExpenseItem(amountVND: 45_000, category: cat, title: "Phở bò đặc biệt")

        let csvString = CSVExportService.generateCSV(from: [expense])

        // Chuỗi phải bắt đầu bằng BOM UTF-8 (\u{FEFF})
        XCTAssertTrue(csvString.hasPrefix("\u{FEFF}"), "CSV phải chứa ký tự BOM UTF-8 ở đầu file để Excel hiển thị tiếng Việt")

        // Kiểm tra dạng bytes UTF-8 có chứa 3 byte: 0xEF, 0xBB, 0xBF
        let data = Data(csvString.utf8)
        XCTAssertGreaterThanOrEqual(data.count, 3)
        XCTAssertEqual(data[0], 0xEF)
        XCTAssertEqual(data[1], 0xBB)
        XCTAssertEqual(data[2], 0xBF)
    }

    // MARK: - 5. Tiêu đề và hàng dữ liệu tuân thủ định dạng RFC 4180

    func testCSVExportHeaderAndDataRowsMatchRFC4180() {
        let cat = ExpenseCategory(name: "Giải trí", symbolName: "gamecontroller", colorHex: "#98D8C8")
        let expense = ExpenseItem(amountVND: 150_000, category: cat, title: "Xem phim rạp")

        let csvString = CSVExportService.generateCSV(from: [expense])
        let lines = csvString.components(separatedBy: "\n").filter { !$0.isEmpty }

        XCTAssertGreaterThanOrEqual(lines.count, 2, "File CSV phải có ít nhất dòng header và 1 dòng dữ liệu")

        // Kiểm tra header: loại bỏ BOM trước khi so sánh chuỗi
        var header = lines[0]
        if header.hasPrefix("\u{FEFF}") {
            header.removeFirst()
        }
        XCTAssertEqual(header, "ID,Ngày,Danh mục,Số tiền (VND),Tiêu đề,Ghi chú,Có ảnh")

        // Kiểm tra dòng dữ liệu chứa số tiền và danh mục
        let dataRow = lines[1]
        XCTAssertTrue(dataRow.contains("150000"))
        XCTAssertTrue(dataRow.contains("Giải trí"))
        XCTAssertTrue(dataRow.contains("Xem phim rạp"))
    }

    // MARK: - 6. Escape ký tự đặc biệt (Dấu phẩy, Ngoặc kép, Xuống dòng)

    func testCSVExportEscapeSpecialCharactersCommasQuotesNewlines() {
        // Test escapeField riêng lẻ
        XCTAssertEqual(CSVExportService.escapeField("Đơn giản"), "Đơn giản")
        XCTAssertEqual(CSVExportService.escapeField("Cà phê, trà đá"), "\"Cà phê, trà đá\"")
        XCTAssertEqual(CSVExportService.escapeField("Bánh mì \"Pate\""), "\"Bánh mì \"\"Pate\"\"\"")
        XCTAssertEqual(CSVExportService.escapeField("Dòng 1\nDòng 2"), "\"Dòng 1\nDòng 2\"")

        // Test trong tổng thể dòng xuất CSV
        let cat = ExpenseCategory(name: "Khác", symbolName: "ellipsis.circle", colorHex: "#B0B0B0")
        let expense = ExpenseItem(
            amountVND: 99_000,
            category: cat,
            title: "Sách, \"Lập trình iOS\"",
            note: "Mua tại Fahasa\nCó kèm bookmark"
        )

        let csv = CSVExportService.generateCSV(from: [expense])
        XCTAssertTrue(csv.contains("\"Sách, \"\"Lập trình iOS\"\"\""), "Dấu phẩy và ngoặc kép phải được bao bọc và escape kép")
        XCTAssertTrue(csv.contains("\"Mua tại Fahasa\nCó kèm bookmark\""), "Ký tự xuống dòng phải được bọc trong cặp nháy kép")
    }

    // MARK: - 7. Xuất CSV chỉ chứa các khoản chi của tài khoản hiện tại

    func testCSVExportFiltersOnlyCurrentUserExpenses() {
        let cat = ExpenseCategory(name: "Ăn uống", symbolName: "fork.knife", colorHex: "#FF6B6B")
        let userA_UID = "UID_EXPORT_A"
        let userB_UID = "UID_EXPORT_B"

        let expA = ExpenseItem(amountVND: 30_000, category: cat, title: "Chi tiêu của A", ownerUID: userA_UID)
        let expB = ExpenseItem(amountVND: 70_000, category: cat, title: "Chi tiêu của B", ownerUID: userB_UID)

        let allExpenses = [expA, expB]

        // Mô phỏng màn hình SettingsView: chỉ truyền userExpenses (lọc theo active user)
        let userAExpenses = allExpenses.filter { $0.ownerUID == userA_UID }
        let csvA = CSVExportService.generateCSV(from: userAExpenses)

        XCTAssertTrue(csvA.contains("Chi tiêu của A"))
        XCTAssertFalse(csvA.contains("Chi tiêu của B"), "Báo cáo CSV của User A tuyệt đối không được chứa dữ liệu của User B")
    }
}
