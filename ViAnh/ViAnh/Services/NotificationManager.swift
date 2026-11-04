import Foundation
import UserNotifications

// MARK: - NotificationManager

@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()

    override private init() {
        super.init()
        center.delegate = self
    }

    // MARK: - Permission

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            UserDefaults.standard.set(granted, forKey: "notifications_authorized")
            return granted
        } catch {
            print("Lỗi xin quyền thông báo: \(error.localizedDescription)")
            return false
        }
    }

    func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }

    // MARK: - Daily Reminder

    func scheduleDailyReminder(hour: Int = 20, minute: Int = 0, isEnabled: Bool) {
        center.removePendingNotificationRequests(withIdentifiers: ["daily_expense_reminder"])

        guard isEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Ghi chép chi tiêu hôm nay"
        content.body = "Dành 3 giây chụp lại các khoản chi hôm nay để giữ ngân sách luôn trong tầm tay nhé!"
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "daily_expense_reminder", content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                print("Lỗi đặt lịch nhắc nhở: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Budget Threshold Checks

    /// Kiểm tra xem khoản chi mới/sửa có đẩy ngân sách chạm ngưỡng (80%) hoặc vượt ngưỡng (100%) hay không
    func checkBudgetThresholds(
        expenses: [ExpenseItem],
        budget: MonthlyBudget?,
        triggerExpense: ExpenseItem
    ) {
        guard let budget = budget else { return }

        let calendar = Calendar.current
        let year = calendar.component(.year, from: triggerExpense.spentAt)
        let month = calendar.component(.month, from: triggerExpense.spentAt)

        guard year == budget.year && month == budget.month else { return }

        // Tính tổng chi tiêu thực tế trong tháng
        let monthExpenses = expenses.filter {
            let y = calendar.component(.year, from: $0.spentAt)
            let m = calendar.component(.month, from: $0.spentAt)
            return y == year && m == month && $0.type == .expense
        }
        var totalSpent: Int64 = 0
        for item in monthExpenses {
            totalSpent += item.amountVND
        }

        // 1. Kiểm tra ngân sách tổng
        if let totalLimit = budget.totalBudgetVND, totalLimit > 0 {
            evaluateAndNotify(
                currentSpent: totalSpent,
                limit: totalLimit,
                targetName: "Tổng ngân sách tháng \(month)/\(year)",
                dedupKey: "budget_\(year)_\(month)_total"
            )
        }

        // 2. Kiểm tra ngân sách danh mục của chính khoản chi này
        let targetCatId = triggerExpense.category.id
        if let catBudget = budget.categoryBudgets.first(where: { $0.category.id == targetCatId }),
           catBudget.amountVND > 0 {
            var catSpent: Int64 = 0
            for item in monthExpenses {
                if item.category.id == targetCatId {
                    catSpent += item.amountVND
                }
            }
            evaluateAndNotify(
                currentSpent: catSpent,
                limit: catBudget.amountVND,
                targetName: "Ngân sách [\(catBudget.category.name)]",
                dedupKey: "budget_\(year)_\(month)_cat_\(targetCatId.uuidString)"
            )
        }
    }

    private func evaluateAndNotify(
        currentSpent: Int64,
        limit: Int64,
        targetName: String,
        dedupKey: String
    ) {
        let lastNotifiedLevel = UserDefaults.standard.integer(forKey: dedupKey) // 0: chưa báo, 1: 80%, 2: 100%+

        if currentSpent >= limit && lastNotifiedLevel < 2 {
            // Đã chạm hoặc vượt 100%
            sendNotification(
                title: "⚠️ Cảnh báo ngân sách!",
                body: "\(targetName) đã chạm ngưỡng/vượt hạn mức! Đã chi: \(currentSpent.vndFormatted) / \(limit.vndFormatted)."
            )
            UserDefaults.standard.set(2, forKey: dedupKey)
        } else if currentSpent >= (limit * 8 / 10) && currentSpent < limit && lastNotifiedLevel < 1 {
            // Đã chạm ngưỡng 80%
            let percent = (Double(currentSpent) / Double(limit)) * 100.0
            sendNotification(
                title: "⚡ Cảnh báo chi tiêu (80%)",
                body: "\(targetName) đã đạt \(String(format: "%.0f%%", percent)) hạn mức (\(currentSpent.vndFormatted) / \(limit.vndFormatted))."
            )
            UserDefaults.standard.set(1, forKey: dedupKey)
        }
    }

    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                print("Lỗi gửi thông báo ngân sách: \(error.localizedDescription)")
            }
        }
    }

    // Hiển thị notification ngay cả khi app đang ở foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        return [.banner, .sound, .badge]
    }
}
