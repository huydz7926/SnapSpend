import Foundation

// MARK: - CSVExportService

/// Xuất danh sách chi tiêu ra định dạng CSV với hỗ trợ UTF-8 (BOM cho Excel tiếng Việt)
@MainActor
struct CSVExportService {

    /// Chuyển đổi mảng ExpenseItem thành chuỗi CSV UTF-8
    static func generateCSV(from expenses: [ExpenseItem]) -> String {
        var csv = "\u{FEFF}" // UTF-8 BOM để Excel hiển thị đúng tiếng Việt
        csv += "ID,Ngày,Danh mục,Số tiền (VND),Tiêu đề,Ghi chú,Có ảnh\n"

        let sorted = expenses.sorted { $0.spentAt > $1.spentAt }

        for expense in sorted {
            let id = expense.id.uuidString
            let dateStr = DateHelpers.formatFullDateTime(expense.spentAt)
            let category = escapeField(expense.category.name)
            let amount = "\(expense.amountVND)"
            let title = escapeField(expense.title)
            let note = escapeField(expense.note)
            let hasImage = expense.imageFileName != nil ? "Có" : "Không"

            let row = "\(id),\(dateStr),\(category),\(amount),\(title),\(note),\(hasImage)\n"
            csv += row
        }

        return csv
    }

    /// Xuất ra file tạm thời trong thư mục temp và trả về URL file
    static func exportToFile(expenses: [ExpenseItem]) throws -> URL {
        let csvString = generateCSV(from: expenses)
        let fileName = "ViAnh_ChiTieu_\(Date().formatted(.iso8601.year().month().day())).csv"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        try csvString.write(to: tempURL, atomically: true, encoding: .utf8)
        return tempURL
    }

    /// Escape các ký tự đặc biệt: dấu phẩy, dấu ngoặc kép, xuống dòng
    static func escapeField(_ text: String) -> String {
        var escaped = text
        if escaped.contains("\"") {
            escaped = escaped.replacingOccurrences(of: "\"", with: "\"\"")
        }
        if escaped.contains(",") || escaped.contains("\n") || escaped.contains("\r") || escaped.contains("\"") {
            return "\"\(escaped)\""
        }
        return escaped
    }
}

