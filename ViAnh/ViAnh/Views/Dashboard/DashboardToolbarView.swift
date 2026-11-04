import SwiftUI

// MARK: - Period Mode

enum DashboardPeriodMode: String, CaseIterable, Identifiable {
    case day = "day"
    case month = "month"

    var id: String { rawValue }

    @MainActor
    var title: String {
        let isVN = LocalizationManager.shared.currentLanguage == .vietnamese
        switch self {
        case .day: return isVN ? "Ngày" : "Day"
        case .month: return isVN ? "Tháng" : "Month"
        }
    }
}

// MARK: - DashboardToolbarView

/// Thanh công cụ: Nút gạt Ngày/Tháng, 3 nút xanh lam nhạt, dải kỳ thời gian cuộn ngang, nút Hôm nay
struct DashboardToolbarView: View {

    @Binding var periodMode: DashboardPeriodMode
    @Binding var isMoneyHidden: Bool
    @Binding var isGridLayout: Bool
    @Binding var showFilterSheet: Bool
    var hasActiveFilters: Bool = false

    @Binding var selectedDay: Int
    @Binding var selectedMonth: Int // 1...12
    @Binding var selectedYear: Int

    var onJumpToToday: () -> Void

    private let theme = ThemeManager.shared
    private let locManager = LocalizationManager.shared

    var body: some View {
        VStack(spacing: 12) {
            // Hàng 1: Nút gạt Ngày/Tháng + Nút Hôm nay + 3 nút công cụ xanh lam nhạt
            HStack {
                // Segment Ngày | Tháng
                periodModeToggle

                // Nút "Hôm nay"
                Button {
                    onJumpToToday()
                    HapticManager.shared.selectionChanged()
                } label: {
                    Text(locManager.t("action_today"))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.primaryAction)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(theme.primaryAction.opacity(0.12))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Spacer()

                // 3 nút công cụ xanh lam nhạt
                HStack(spacing: 8) {
                    // 1. Ẩn / Hiện tiền
                    toolbarCircleButton(
                        systemName: isMoneyHidden ? "eye.slash.fill" : "eye.fill",
                        accessibilityLabel: isMoneyHidden
                            ? (locManager.currentLanguage == .vietnamese ? "Hiện số tiền" : "Show amount")
                            : (locManager.currentLanguage == .vietnamese ? "Ẩn số tiền" : "Hide amount")
                    ) {
                        isMoneyHidden.toggle()
                        HapticManager.shared.selectionChanged()
                    }

                    // 2. Đổi bố cục Lịch / Danh sách
                    toolbarCircleButton(
                        systemName: isGridLayout ? "calendar" : "rectangle.grid.1x2",
                        accessibilityLabel: locManager.currentLanguage == .vietnamese ? "Đổi bố cục xem" : "Change view layout"
                    ) {
                        isGridLayout.toggle()
                        HapticManager.shared.selectionChanged()
                    }

                    // 3. Bộ lọc Danh mục / Ví
                    ZStack(alignment: .topTrailing) {
                        toolbarCircleButton(
                            systemName: "line.3.horizontal.decrease",
                            accessibilityLabel: locManager.currentLanguage == .vietnamese ? "Bộ lọc" : "Filter"
                        ) {
                            showFilterSheet = true
                            HapticManager.shared.selectionChanged()
                        }

                        if hasActiveFilters {
                            Circle()
                                .fill(theme.primaryAction)
                                .frame(width: 8, height: 8)
                                .offset(x: 2, y: -2)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)

            // Hàng 2: Thanh kỳ thời gian cuộn ngang (Tháng hoặc Ngày)
            if periodMode == .month {
                monthPickerStrip
            } else {
                dayPickerStrip
            }
        }
    }

    // MARK: - Period Mode Toggle (Capsule)

    private var periodModeToggle: some View {
        HStack(spacing: 0) {
            ForEach(DashboardPeriodMode.allCases) { mode in
                let isSelected = periodMode == mode
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        periodMode = mode
                    }
                    HapticManager.shared.selectionChanged()
                } label: {
                    Text(mode.title)
                        .font(.system(size: 13, weight: isSelected ? .semibold : .regular, design: .rounded))
                        .foregroundStyle(isSelected ? theme.textPrimary : theme.textSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(theme.surface)
                                    .shadow(color: Color.black.opacity(0.06), radius: 4, y: 1)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color(hex: "#EAE5DC")?.opacity(0.6) ?? Color.gray.opacity(0.15))
        .clipShape(Capsule())
    }

    // MARK: - Toolbar Circle Button (Nền xanh lam nhạt #E3F2FD)

    private func toolbarCircleButton(
        systemName: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color(hex: "#E3F2FD") ?? Color.blue.opacity(0.12))
                    .frame(width: 36, height: 36)

                Image(systemName: systemName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color(hex: "#1976D2") ?? Color.blue)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Month Picker Strip

    private var monthPickerStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(1...12, id: \.self) { m in
                        let isSelected = m == selectedMonth

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedMonth = m
                            }
                            HapticManager.shared.selectionChanged()
                        } label: {
                            VStack(spacing: 4) {
                                Text(monthLabel(for: m))
                                    .font(.system(size: 14, weight: isSelected ? .bold : .medium, design: .rounded))
                                    .foregroundStyle(isSelected ? theme.primaryAction : theme.textSecondary)

                                // Gạch chân xanh lá cho mục được chọn
                                Rectangle()
                                    .fill(isSelected ? theme.primaryAction : Color.clear)
                                    .frame(height: 2.5)
                                    .clipShape(Capsule())
                            }
                        }
                        .buttonStyle(.plain)
                        .id(m)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
            .onAppear {
                proxy.scrollTo(selectedMonth, anchor: .center)
            }
        }
    }

    private func monthLabel(for m: Int) -> String {
        if locManager.currentLanguage == .english {
            let names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
            if m >= 1 && m <= 12 { return names[m - 1] }
            return "M\(m)"
        } else {
            return "Thg \(m)"
        }
    }

    // MARK: - Day Picker Strip

    private var daysInCurrentMonth: Int {
        var comp = DateComponents()
        comp.year = selectedYear
        comp.month = selectedMonth
        let date = Calendar.current.date(from: comp) ?? Date.now
        return Calendar.current.range(of: .day, in: .month, for: date)?.count ?? 30
    }

    private func weekdayLabel(for day: Int) -> String {
        var comp = DateComponents()
        comp.year = selectedYear
        comp.month = selectedMonth
        comp.day = day
        guard let date = Calendar.current.date(from: comp) else { return "\(day)" }
        let weekday = Calendar.current.component(.weekday, from: date)
        let isVN = locManager.currentLanguage == .vietnamese
        switch weekday {
        case 1: return isVN ? "CN" : "Sun"
        case 2: return isVN ? "Thứ 2" : "Mon"
        case 3: return isVN ? "Thứ 3" : "Tue"
        case 4: return isVN ? "Thứ 4" : "Wed"
        case 5: return isVN ? "Thứ 5" : "Thu"
        case 6: return isVN ? "Thứ 6" : "Fri"
        case 7: return isVN ? "Thứ 7" : "Sat"
        default: return ""
        }
    }

    private var dayPickerStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(1...daysInCurrentMonth, id: \.self) { d in
                        let isSelected = d == selectedDay

                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                selectedDay = d
                            }
                            HapticManager.shared.selectionChanged()
                        } label: {
                            VStack(spacing: 3) {
                                Text(weekdayLabel(for: d))
                                    .font(.system(size: 10, weight: isSelected ? .bold : .medium, design: .rounded))
                                    .foregroundStyle(isSelected ? Color.white.opacity(0.9) : theme.textSecondary)

                                Text("\(d)")
                                    .font(.system(size: 15, weight: isSelected ? .heavy : .semibold, design: .rounded))
                                    .foregroundStyle(isSelected ? Color.white : theme.textPrimary)
                            }
                            .frame(width: 52, height: 46)
                            .background(isSelected ? theme.primaryAction : theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(color: Color.black.opacity(isSelected ? 0.15 : 0.04), radius: isSelected ? 4 : 2, y: 1)
                        }
                        .buttonStyle(.plain)
                        .id(d)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
            .onAppear {
                proxy.scrollTo(selectedDay, anchor: .center)
            }
        }
    }
}
