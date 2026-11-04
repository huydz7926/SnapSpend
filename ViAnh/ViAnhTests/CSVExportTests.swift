import XCTest
@testable import ViAnh

final class CSVExportTests: XCTestCase {

    func testEscapeFieldNoSpecialCharacters() {
        let input = "Ăn trưa bình thường"
        let output = CSVExportService.escapeField(input)
        XCTAssertEqual(output, "Ăn trưa bình thường")
    }

    func testEscapeFieldWithComma() {
        let input = "Cà phê, trà đá"
        let output = CSVExportService.escapeField(input)
        XCTAssertEqual(output, "\"Cà phê, trà đá\"")
    }

    func testEscapeFieldWithQuotes() {
        let input = "Món \"đặc biệt\""
        let output = CSVExportService.escapeField(input)
        XCTAssertEqual(output, "\"Món \"\"đặc biệt\"\"\"")
    }

    func testEscapeFieldWithNewline() {
        let input = "Dòng 1\nDòng 2"
        let output = CSVExportService.escapeField(input)
        XCTAssertEqual(output, "\"Dòng 1\nDòng 2\"")
    }

    func testGenerateCSVStartsWithBOM() {
        let cat = ExpenseCategory(name: "Ăn uống", symbolName: "fork.knife", colorHex: "#FF6B6B")
        let item = ExpenseItem(
            amountVND: 45_000,
            category: cat,
            spentAt: Date.now,
            title: "Phở bò",
            note: "Nhiều hành, ít bánh"
        )

        let csv = CSVExportService.generateCSV(from: [item])

        // Bắt đầu bằng UTF-8 BOM
        XCTAssertTrue(csv.hasPrefix("\u{FEFF}"), "CSV must start with UTF-8 BOM for Excel Vietnamese compatibility")
        XCTAssertTrue(csv.contains("ID,Ngày,Danh mục,Số tiền (VND),Tiêu đề,Ghi chú,Có ảnh"))
        XCTAssertTrue(csv.contains("45000"))
        XCTAssertTrue(csv.contains("Phở bò"))
        XCTAssertTrue(csv.contains("\"Nhiều hành, ít bánh\""))
    }
}

