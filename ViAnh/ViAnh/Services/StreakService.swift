import Foundation

// MARK: - StreakSummary

struct StreakSummary {
    let totalPhotos: Int
    let currentStreak: Int
    let longestStreak: Int
}

// MARK: - StreakService

/// Dịch vụ tính toán số ảnh và chuỗi ngày liên tục theo quy tắc SnapSpend
struct StreakService {

    /// Tính tổng số ảnh và chuỗi ngày chụp liên tục
    static func calculate(
        expenses: [ExpenseItem],
        referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> StreakSummary {
        // 1. Tổng ảnh chụp thực tế đã lưu thành công trong app
        let cameraPhotos = expenses.filter { $0.isCameraPhoto }
        let totalPhotos = cameraPhotos.count

        // 2. Lấy danh sách các ngày chụp thực tế duy nhất (start of day)
        var captureDays = Set<Date>()
        for item in cameraPhotos {
            let captureDate = item.effectiveCaptureDate
            let startOfDay = calendar.startOfDay(for: captureDate)
            captureDays.insert(startOfDay)
        }

        guard !captureDays.isEmpty else {
            return StreakSummary(totalPhotos: 0, currentStreak: 0, longestStreak: 0)
        }

        // 3. Tính Chuỗi hiện tại (current streak)
        // Kéo dài đến hôm nay, hoặc đến hôm qua nếu hôm nay chưa chụp
        let todayStart = calendar.startOfDay(for: referenceDate)
        let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart

        var currentStreak = 0
        var checkDay: Date? = nil

        if captureDays.contains(todayStart) {
            checkDay = todayStart
        } else if captureDays.contains(yesterdayStart) {
            checkDay = yesterdayStart
        }

        if let anchor = checkDay {
            var cursor = anchor
            while captureDays.contains(cursor) {
                currentStreak += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
                cursor = prev
            }
        }

        // 4. Tính Chuỗi dài nhất trong lịch sử (longest streak)
        var longestStreak = 0
        var currentRun = 0
        var previousDay: Date? = nil

        let ascendingDays = captureDays.sorted(by: <)
        for day in ascendingDays {
            if let prev = previousDay {
                if let nextExpected = calendar.date(byAdding: .day, value: 1, to: prev),
                   calendar.isDate(day, inSameDayAs: nextExpected) {
                    currentRun += 1
                } else {
                    currentRun = 1
                }
            } else {
                currentRun = 1
            }
            previousDay = day
            if currentRun > longestStreak {
                longestStreak = currentRun
            }
        }

        return StreakSummary(
            totalPhotos: totalPhotos,
            currentStreak: currentStreak,
            longestStreak: longestStreak
        )
    }
}

