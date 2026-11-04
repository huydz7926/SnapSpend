import Foundation

// MARK: - Calendar Day Item

struct CalendarDayItem: Identifiable, Equatable {
    let id: String
    let date: Date?
    let dayNumber: Int?
    let isCurrentMonth: Bool
    let isToday: Bool

    static func == (lhs: CalendarDayItem, rhs: CalendarDayItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - MonthGridBuilder

/// Tính toán ma trận lịch 7 cột (Thứ 2 đến Chủ nhật) chuẩn xác cho bất kỳ tháng/năm nào
@MainActor
struct MonthGridBuilder {

    /// Tiêu đề 7 cột thứ theo ngôn ngữ hiện tại
    static var weekdayHeaders: [String] {
        if LocalizationManager.shared.currentLanguage == .english {
            return ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        } else {
            return ["T2", "T3", "T4", "T5", "T6", "T7", "CN"]
        }
    }

    /// Tạo danh sách các ô ngày trong tháng (bao gồm các ô đệm đầu và cuối)
    static func buildMonthGrid(
        year: Int,
        month: Int,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> [CalendarDayItem] {
        var cal = calendar
        cal.locale = Locale(identifier: "vi_VN")
        cal.firstWeekday = 2 // Thứ 2 là ngày đầu tuần

        var startComps = DateComponents()
        startComps.year = year
        startComps.month = month
        startComps.day = 1
        startComps.hour = 0
        startComps.minute = 0
        startComps.second = 0

        guard let monthStart = cal.date(from: startComps),
              let dayRange = cal.range(of: .day, in: .month, for: monthStart) else {
            return []
        }

        let totalDaysInMonth = dayRange.count

        // Xác định thứ của ngày 1 trong tháng
        // Trong Gregorian: CN = 1, T2 = 2, T3 = 3, T4 = 4, T5 = 5, T6 = 6, T7 = 7
        // Với tuần bắt đầu từ T2:
        // T2 (weekday 2) -> 0 ô đệm
        // T3 (weekday 3) -> 1 ô đệm
        // ...
        // T7 (weekday 7) -> 5 ô đệm
        // CN (weekday 1) -> 6 ô đệm
        let weekday = cal.component(.weekday, from: monthStart)
        let leadingPadding = (weekday + 5) % 7

        var grid: [CalendarDayItem] = []

        // 1. Các ô đệm đầu tháng (thuộc tháng trước)
        for i in 0..<leadingPadding {
            grid.append(
                CalendarDayItem(
                    id: "leading-\(year)-\(month)-\(i)",
                    date: nil,
                    dayNumber: nil,
                    isCurrentMonth: false,
                    isToday: false
                )
            )
        }

        // 2. Các ngày trong tháng
        let today = Date.now
        for day in 1...totalDaysInMonth {
            var dayComps = startComps
            dayComps.day = day
            let dayDate = cal.date(from: dayComps)
            let isToday = dayDate.map { cal.isDate($0, inSameDayAs: today) } ?? false

            grid.append(
                CalendarDayItem(
                    id: "day-\(year)-\(month)-\(day)",
                    date: dayDate,
                    dayNumber: day,
                    isCurrentMonth: true,
                    isToday: isToday
                )
            )
        }

        // 3. Các ô đệm cuối tháng để đủ tròn hàng 7 cột
        let remainder = grid.count % 7
        if remainder > 0 {
            let trailingPadding = 7 - remainder
            for i in 0..<trailingPadding {
                grid.append(
                    CalendarDayItem(
                        id: "trailing-\(year)-\(month)-\(i)",
                        date: nil,
                        dayNumber: nil,
                        isCurrentMonth: false,
                        isToday: false
                    )
                )
            }
        }

        return grid
    }
}

