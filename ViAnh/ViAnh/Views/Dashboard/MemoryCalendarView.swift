import SwiftUI

// MARK: - Daily Expenses Summary

struct DayExpenseSummary {
    let date: Date
    let expenses: [ExpenseItem]

    var count: Int { expenses.count }

    var photoCount: Int {
        expenses.filter { $0.thumbnailFileName != nil }.count
    }

    var totalExpense: Int64 {
        expenses.filter { $0.isExpense }.reduce(0) { $0 + $1.amountVND }
    }

    var totalIncome: Int64 {
        expenses.filter { $0.isIncome }.reduce(0) { $0 + $1.amountVND }
    }

    /// Số ròng hiển thị trên ô lịch: Chi là số âm (-460k)
    var netAmountVND: Int64 {
        totalIncome - totalExpense
    }

    /// Ảnh đại diện ưu tiên ảnh của giao dịch mới nhất có ảnh
    var representativeThumbnail: String? {
        expenses.first { $0.thumbnailFileName != nil }?.thumbnailFileName
    }
}

// MARK: - MemoryCalendarView (Chuẩn Ảnh 2)

struct MemoryCalendarView: View {

    var year: Int
    var month: Int
    var expenses: [ExpenseItem]
    var allExpenses: [ExpenseItem] // Toàn bộ expenses để tính chuỗi streak chính xác
    var isMoneyHidden: Bool

    /// Callback khi chạm vào nút + trên ô ngày trống
    var onAddForDate: (Date) -> Void
    /// Callback khi chạm vào ô ngày đã có giao dịch
    var onSelectDay: (Date, [ExpenseItem]) -> Void

    @State private var tappedEmptyDayId: String? = nil
    @State private var showStreakDetailSheet = false

    private let theme = ThemeManager.shared
    private let locManager = LocalizationManager.shared
    private let calendar = Calendar.current

    private var monthHeaderTitle: String {
        if locManager.currentLanguage == .vietnamese {
            return "tháng \(month) \(String(year))"
        } else {
            let names = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
            let name = (month >= 1 && month <= 12) ? names[month - 1] : "Month \(month)"
            return "\(name) \(String(year))"
        }
    }

    // Tính chuỗi streak và tổng ảnh
    private var streakSummary: StreakSummary {
        StreakService.calculate(expenses: allExpenses)
    }

    // Gom nhóm giao dịch theo ngày trong tháng
    private var dailySummaryMap: [Int: DayExpenseSummary] {
        var map: [Int: [ExpenseItem]] = [:]

        for expense in expenses {
            let expYear = calendar.component(.year, from: expense.spentAt)
            let expMonth = calendar.component(.month, from: expense.spentAt)
            if expYear == year && expMonth == month {
                let day = calendar.component(.day, from: expense.spentAt)
                map[day, default: []].append(expense)
            }
        }

        var result: [Int: DayExpenseSummary] = [:]
        for (day, items) in map {
            if let firstDate = items.first?.spentAt {
                result[day] = DayExpenseSummary(date: firstDate, expenses: items)
            }
        }
        return result
    }

    private var calendarGrid: [CalendarDayItem] {
        MonthGridBuilder.buildMonthGrid(year: year, month: month)
    }

    private let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)

    var body: some View {
        VStack(spacing: 16) {
            // Khung Lịch Tháng (Ảnh 2: Nền thẻ bo góc 24pt)
            VStack(spacing: 12) {
                // Header Tháng (ví dụ: "tháng 11 2026" hoặc "November 2026")
                HStack {
                    Text(monthHeaderTitle)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(theme.textPrimary)

                    Spacer()
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 2)

                // Header 7 cột (T2 -> CN)
                HStack(spacing: 0) {
                    ForEach(MonthGridBuilder.weekdayHeaders, id: \.self) { header in
                        Text(header)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(header == "CN" ? theme.expenseColor : theme.textSecondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 4)

                // Grid 7 cột
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(calendarGrid) { item in
                        if item.isCurrentMonth, let dayNum = item.dayNumber, let dayDate = item.date {
                            calendarCell(
                                dayNumber: dayNum,
                                date: dayDate,
                                summary: dailySummaryMap[dayNum],
                                itemId: item.id
                            )
                        } else {
                            // Ô đệm mờ ngoài tháng: Chấm tròn nhỏ xám mờ theo mẫu Ảnh 2
                            Circle()
                                .fill(theme.separator.opacity(0.3))
                                .frame(width: 8, height: 8)
                                .frame(maxWidth: .infinity, minHeight: 46)
                        }
                    }
                }
            }
            .padding(18)
            .background {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(theme.surface)
                    .shadow(color: Color.black.opacity(0.04), radius: 10, y: 4)
                    .overlay {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(theme.separator.opacity(0.5), lineWidth: 0.5)
                    }
            }
            .padding(.horizontal, 16)

            // Thẻ thống kê dưới lịch (Ảnh 2: "📸 … ảnh | 🔥 Chuỗi … ngày")
            streakBadgeCard
                .padding(.horizontal, 16)
        }
        .sheet(isPresented: $showStreakDetailSheet) {
            streakDetailSheet
        }
    }

    // MARK: - Calendar Cell (Ảnh 2)

    private func calendarCell(
        dayNumber: Int,
        date: Date,
        summary: DayExpenseSummary?,
        itemId: String
    ) -> some View {
        let hasExpenses = summary != nil && summary!.count > 0
        let isToday = calendar.isDateInToday(date)
        let isSelectedEmpty = tappedEmptyDayId == itemId

        return Button {
            HapticManager.shared.selectionChanged()
            if hasExpenses, let sum = summary {
                onSelectDay(date, sum.expenses)
            } else {
                if isSelectedEmpty || isToday {
                    onAddForDate(date)
                } else {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        tappedEmptyDayId = itemId
                    }
                }
            }
        } label: {
            ZStack(alignment: .bottomTrailing) {
                // Background & Thumbnail
                if hasExpenses, let sum = summary {
                    if let thumb = sum.representativeThumbnail {
                        // Ô có ảnh thumbnail + Viền hồng/accent theo Ảnh 2
                        AsyncThumbnailView(fileName: thumb)
                            .aspectRatio(1, contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .stroke(Color(hex: "#FF4081") ?? Color.pink, lineWidth: 2)
                            }
                    } else {
                        // Có chi tiêu nhưng không có ảnh
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(theme.primaryAction.opacity(0.12))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .overlay {
                                Image(systemName: "tag.fill")
                                    .font(.caption2)
                                    .foregroundStyle(theme.primaryAction)
                            }
                    }

                    // Badge số ảnh (Ảnh 2: ví dụ badge "673" hoặc số ảnh của ngày)
                    if sum.photoCount > 1 {
                        Text("\(sum.photoCount)")
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1.5)
                            .background(Color(hex: "#FF4081") ?? Color.pink)
                            .clipShape(Capsule())
                            .offset(x: -3, y: -3)
                    }
                } else {
                    // Ngày trống: Nút [+] nếu là hôm nay hoặc khi được chạm; hoặc ô bo góc xám mờ
                    if isToday || isSelectedEmpty {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(Color(hex: "#FF4081")?.opacity(0.1) ?? Color.pink.opacity(0.1))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .overlay {
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .stroke(Color(hex: "#FF4081") ?? Color.pink, lineWidth: 1.8)
                            }
                            .overlay {
                                Image(systemName: "plus")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(Color(hex: "#FF4081") ?? Color.pink)
                            }
                    } else {
                        // Ô ngày trống bình thường (Ảnh 2: ô bo góc xám mờ nhẹ)
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(theme.isDarkModeEffective ? Color(white: 0.18) : theme.separator.opacity(0.35))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .overlay(alignment: .topLeading) {
                                Text("\(dayNumber)")
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundStyle(theme.textSecondary.opacity(0.6))
                                    .padding(4)
                            }
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Streak Badge Card (Ảnh 2: "📸 … ảnh | 🔥 Chuỗi … ngày")

    private var streakBadgeCard: some View {
        Button {
            showStreakDetailSheet = true
            HapticManager.shared.selectionChanged()
        } label: {
            HStack(spacing: 12) {
                // Số ảnh
                HStack(spacing: 5) {
                    Text("📸")
                        .font(.subheadline)
                    Text("\(streakSummary.totalPhotos) \(locManager.t("label_photos"))")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(theme.textPrimary)
                }

                Text("|")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary.opacity(0.5))

                // Chuỗi ngày
                HStack(spacing: 5) {
                    Text("🔥")
                        .font(.subheadline)
                    Text(locManager.currentLanguage == .vietnamese
                         ? "chuỗi \(streakSummary.currentStreak) ngày"
                         : "\(streakSummary.currentStreak)-day streak")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(theme.textPrimary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background {
                Capsule()
                    .fill(theme.surface)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, y: 3)
                    .overlay {
                        Capsule()
                            .stroke(theme.separator.opacity(0.5), lineWidth: 0.5)
                    }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Streak Detail Sheet

    private var streakDetailSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Icon lớn
                ZStack {
                    Circle()
                        .fill(Color(hex: "#FF4081")?.opacity(0.15) ?? Color.pink.opacity(0.15))
                        .frame(width: 80, height: 80)
                    Text("🔥")
                        .font(.system(size: 44))
                }
                .padding(.top, 20)

                VStack(spacing: 6) {
                    Text(locManager.currentLanguage == .vietnamese ? "Chuỗi ghi chép bằng ảnh" : "Photo Expense Streak")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(theme.textPrimary)
                    Text(locManager.currentLanguage == .vietnamese
                         ? "Mỗi ngày chụp và lưu ít nhất một bức ảnh chi tiêu để duy trì chuỗi."
                         : "Capture and save at least one expense photo daily to maintain your streak.")
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                // Hai thẻ thống kê
                HStack(spacing: 16) {
                    VStack(spacing: 6) {
                        Text("\(streakSummary.currentStreak)")
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color(hex: "#FF4081") ?? Color.pink)
                        Text(locManager.currentLanguage == .vietnamese ? "Chuỗi hiện tại" : "Current Streak")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    VStack(spacing: 6) {
                        Text("\(streakSummary.longestStreak)")
                            .font(.system(size: 36, weight: .heavy, design: .rounded))
                            .foregroundStyle(theme.primaryAction)
                        Text(locManager.currentLanguage == .vietnamese ? "Chuỗi dài nhất" : "Longest Streak")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .padding(.horizontal, 24)

                // Tổng số ảnh đã chụp
                HStack {
                    Label(
                        locManager.currentLanguage == .vietnamese ? "Tổng ảnh đã chụp và lưu" : "Total Saved Photos",
                        systemImage: "camera.fill"
                    )
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.textPrimary)
                    Spacer()
                    Text("\(streakSummary.totalPhotos) \(locManager.t("label_photos"))")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(theme.primaryAction)
                }
                .padding(16)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, 24)

                Spacer()
            }
            .background(theme.background.ignoresSafeArea())
            .navigationTitle(locManager.t("tab_memories"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(locManager.t("action_done")) { showStreakDetailSheet = false }
                        .font(.body.weight(.semibold))
                }
            }
        }
        .presentationDetents([.medium])
    }
}
