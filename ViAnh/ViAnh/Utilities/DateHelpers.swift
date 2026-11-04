import Foundation

// MARK: - DateHelpers

@MainActor
struct DateHelpers {

    static let vietnamLocale = Locale(identifier: "vi_VN")
    static let vietnamCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "vi_VN")
        cal.timeZone = TimeZone.current
        return cal
    }()

    // MARK: - Formatters

    private static var currentLocale: Locale {
        LocalizationManager.shared.locale
    }

    private static var dayMonthFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = currentLocale
        f.dateFormat = "dd/MM"
        return f
    }

    private static var fullDateFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = currentLocale
        f.dateFormat = "dd/MM/yyyy"
        return f
    }

    private static var fullDateTimeFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = currentLocale
        f.dateFormat = "dd/MM/yyyy HH:mm"
        return f
    }

    private static var monthYearFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = currentLocale
        f.dateFormat = "MMMM, yyyy"
        return f
    }

    // MARK: - Public Helper Methods

    /// "Hôm nay", "Hôm qua", hoặc "dd/MM/yyyy"
    static func relativeDayString(from date: Date, calendar: Calendar = .current) -> String {
        let isVN = LocalizationManager.shared.currentLanguage == .vietnamese
        if calendar.isDateInToday(date) {
            return isVN ? "Hôm nay" : "Today"
        } else if calendar.isDateInYesterday(date) {
            return isVN ? "Hôm qua" : "Yesterday"
        } else {
            return fullDateFormatter.string(from: date)
        }
    }

    /// "Hôm nay, 14:30" hoặc "Hôm qua, 23:07" hoặc "12/03, 08:15"
    static func formatRelativeDateTime(_ date: Date, calendar: Calendar = .current) -> String {
        let isVN = LocalizationManager.shared.currentLanguage == .vietnamese
        let timeFormatter = DateFormatter()
        timeFormatter.locale = currentLocale
        timeFormatter.dateFormat = "HH:mm"
        let timeStr = timeFormatter.string(from: date)

        if calendar.isDateInToday(date) {
            let prefix = isVN ? "Hôm nay" : "Today"
            return "\(prefix), \(timeStr)"
        } else if calendar.isDateInYesterday(date) {
            let prefix = isVN ? "Hôm qua" : "Yesterday"
            return "\(prefix), \(timeStr)"
        } else {
            let df = DateFormatter()
            df.locale = currentLocale
            df.dateFormat = "dd/MM, "
            return df.string(from: date) + timeStr
        }
    }

    /// "dd/MM/yyyy"
    static func formatFullDate(_ date: Date) -> String {
        fullDateFormatter.string(from: date)
    }

    /// "dd/MM/yyyy HH:mm"
    static func formatFullDateTime(_ date: Date) -> String {
        fullDateTimeFormatter.string(from: date)
    }

    /// "Tháng M, yyyy" hoặc "Month yyyy"
    static func formatMonthYear(year: Int, month: Int) -> String {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        var cal = Calendar(identifier: .gregorian)
        cal.locale = currentLocale
        let date = cal.date(from: components) ?? Date.now
        let str = monthYearFormatter.string(from: date)
        return str.prefix(1).uppercased() + str.dropFirst()
    }

    /// Ranh giới tháng [startOfMonth, startOfNextMonth)
    static func monthRange(year: Int, month: Int, calendar: Calendar = .current) -> (start: Date, end: Date)? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        components.hour = 0
        components.minute = 0
        components.second = 0

        guard let start = calendar.date(from: components),
              let end = calendar.date(byAdding: .month, value: 1, to: start) else {
            return nil
        }
        return (start, end)
    }
}

