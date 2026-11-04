import SwiftUI
import SwiftData
import Charts

// MARK: - Time Granularity

enum TimeGranularity: String, CaseIterable, Identifiable {
    case day = "day"
    case month = "month"
    case year = "year"

    var id: String { rawValue }

    @MainActor
    var title: String {
        let isVN = LocalizationManager.shared.currentLanguage == .vietnamese
        switch self {
        case .day: return isVN ? "Ngày" : "Day"
        case .month: return isVN ? "Tháng" : "Month"
        case .year: return isVN ? "Năm" : "Year"
        }
    }
}

// MARK: - AnalyticsView

struct AnalyticsView: View {

    @Query(sort: \ExpenseItem.spentAt, order: .reverse)
    private var allExpenses: [ExpenseItem]

    @Query(sort: \ExpenseCategory.sortOrder)
    private var categories: [ExpenseCategory]

    @Query(sort: \Wallet.sortOrder)
    private var wallets: [Wallet]

    private let authService = AuthService.shared

    private var currentOwnerUID: String {
        authService.currentOwnerID
    }

    /// Lọc toàn bộ giao dịch theo chủ tài khoản hiện tại
    private var userExpenses: [ExpenseItem] {
        guard !authService.isSignedOut else { return [] }
        return allExpenses.filter { $0.ownerUID == currentOwnerUID }
    }

    private var userCategories: [ExpenseCategory] {
        categories.filter { $0.isDefault || $0.ownerUID == currentOwnerUID }
    }

    private var userWallets: [Wallet] {
        wallets.filter { $0.isDefault || $0.ownerUID == currentOwnerUID }
    }

    @State private var granularity: TimeGranularity = .month
    @State private var selectedDate: Date = .now
    @State private var selectedWalletId: UUID? = nil
    @State private var selectedCategoryId: UUID? = nil
    @State private var showListView: Bool = false

    private let theme = ThemeManager.shared
    private let locManager = LocalizationManager.shared

    private var isVN: Bool {
        locManager.currentLanguage == .vietnamese
    }

    // MARK: - Date Range Calculation

    private var currentRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        switch granularity {
        case .day:
            let start = calendar.startOfDay(for: selectedDate)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? selectedDate
            return (start, end)
        case .month:
            let comps = calendar.dateComponents([.year, .month], from: selectedDate)
            let start = calendar.date(from: comps) ?? selectedDate
            let end = calendar.date(byAdding: .month, value: 1, to: start) ?? selectedDate
            return (start, end)
        case .year:
            let comps = calendar.dateComponents([.year], from: selectedDate)
            let start = calendar.date(from: comps) ?? selectedDate
            let end = calendar.date(byAdding: .year, value: 1, to: start) ?? selectedDate
            return (start, end)
        }
    }

    // MARK: - Filtered Expenses

    private var periodExpenses: [ExpenseItem] {
        let range = currentRange
        return userExpenses.filter { item in
            guard item.spentAt >= range.start && item.spentAt < range.end else { return false }
            if let wId = selectedWalletId, item.wallet?.id != wId { return false }
            if let cId = selectedCategoryId, item.category.id != cId { return false }
            return true
        }
    }

    private var totalExpenseVND: Int64 {
        periodExpenses.filter { $0.type == .expense }.reduce(0) { $0 + $1.amountVND }
    }

    private var totalIncomeVND: Int64 {
        periodExpenses.filter { $0.type == .income }.reduce(0) { $0 + $1.amountVND }
    }

    private var netVND: Int64 {
        totalIncomeVND - totalExpenseVND
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Thanh điều khiển Kỳ & Ngày tháng
                periodSelectorCard

                // Bộ lọc Ví & Danh mục
                filterChipsBar

                // Thẻ tổng quan Thu / Chi / Ròng
                summaryCards

                if periodExpenses.isEmpty {
                    EmptyStateView(
                        symbol: "chart.bar.xaxis",
                        title: isVN ? "Chưa có dữ liệu kỳ này" : "No data for this period",
                        message: isVN
                            ? "Bấm nút [+] ở dock để ghi lại các khoản thu chi đầu tiên của kỳ."
                            : "Tap [+] in dock to record your first transaction for this period."
                    )
                    .padding(.top, 30)
                } else {
                    // Chuyển đổi Biểu đồ / Danh sách chi tiết
                    viewModePicker

                    if showListView {
                        // Danh sách giao dịch
                        transactionsList
                    } else {
                        // Biểu đồ xu hướng theo mốc thời gian
                        trendChartCard

                        // Biểu đồ cơ cấu theo Danh mục (Donut Chart)
                        categoryDonutCard

                        // Top danh mục chi nhiều nhất
                        topCategoriesCard
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle(locManager.t("tab_analytics"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Period Selector Card

    private var periodSelectorCard: some View {
        VStack(spacing: 12) {
            // Segmented Picker
            Picker("Kỳ", selection: $granularity) {
                ForEach(TimeGranularity.allCases) { g in
                    Text(g.title).tag(g)
                }
            }
            .pickerStyle(.segmented)

            // Date Navigation < Ngày/Tháng/Năm >
            HStack {
                Button {
                    stepDate(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Spacer()

                Text(periodDisplayString)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(theme.textPrimary)

                Spacer()

                Button {
                    stepDate(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.textPrimary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.cardCornerRadius, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    private var periodDisplayString: String {
        let formatter = DateFormatter()
        formatter.locale = locManager.locale
        switch granularity {
        case .day:
            formatter.dateFormat = isVN ? "EEEE, dd/MM/yyyy" : "EEEE, MMM d, yyyy"
            return formatter.string(from: selectedDate).capitalized
        case .month:
            formatter.dateFormat = isVN ? "MMMM, yyyy" : "MMMM yyyy"
            return formatter.string(from: selectedDate).capitalized
        case .year:
            formatter.dateFormat = isVN ? "'Năm' yyyy" : "'Year' yyyy"
            return formatter.string(from: selectedDate)
        }
    }

    private func stepDate(by value: Int) {
        let calendar = Calendar.current
        var component: Calendar.Component = .month
        switch granularity {
        case .day:   component = .day
        case .month: component = .month
        case .year:  component = .year
        }
        if let next = calendar.date(byAdding: component, value: value, to: selectedDate) {
            withAnimation(theme.defaultSpring) {
                selectedDate = next
            }
            HapticManager.shared.selectionChanged()
        }
    }

    // MARK: - Filter Chips Bar

    private var filterChipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Filter Ví: Tất cả
                chipButton(title: isVN ? "Tất cả ví" : "All Wallets", isSelected: selectedWalletId == nil) {
                    selectedWalletId = nil
                }

                ForEach(userWallets) { w in
                    chipButton(title: w.name, isSelected: selectedWalletId == w.id) {
                        selectedWalletId = (selectedWalletId == w.id ? nil : w.id)
                    }
                }

                Divider()
                    .frame(height: 20)
                    .padding(.horizontal, 4)

                // Filter Danh mục: Tất cả
                chipButton(title: isVN ? "Tất cả mục" : "All Categories", isSelected: selectedCategoryId == nil) {
                    selectedCategoryId = nil
                }

                ForEach(userCategories) { cat in
                    chipButton(title: locManager.localizedCategoryName(cat.name), isSelected: selectedCategoryId == cat.id) {
                        selectedCategoryId = (selectedCategoryId == cat.id ? nil : cat.id)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func chipButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticManager.shared.selectionChanged()
            action()
        }) {
            Text(title)
                .font(.footnote.weight(isSelected ? .bold : .medium))
                .foregroundStyle(isSelected ? Color.white : theme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? theme.primaryAction : theme.surface)
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        HStack(spacing: 12) {
            // Chi tiêu
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text(isVN ? "↗ Chi tiêu" : "↗ Expense")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.expenseColor)
                }
                Text(totalExpenseVND.vndFormatted)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(theme.expenseColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)

            // Thu nhập
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text(isVN ? "↙ Thu nhập" : "↙ Income")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.incomeColor)
                }
                Text(totalIncomeVND.vndFormatted)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(theme.incomeColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
        }
    }

    // MARK: - View Mode Picker

    private var viewModePicker: some View {
        HStack {
            Text(showListView
                 ? (isVN ? "Danh sách giao dịch (\(periodExpenses.count))" : "Transactions (\(periodExpenses.count))")
                 : (isVN ? "Biểu đồ phân tích" : "Analytics Charts"))
                .font(.headline)
                .foregroundStyle(theme.textPrimary)

            Spacer()

            Button {
                withAnimation(theme.defaultSpring) {
                    showListView.toggle()
                }
                HapticManager.shared.selectionChanged()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showListView ? "chart.pie.fill" : "list.bullet")
                    Text(showListView
                         ? (isVN ? "Xem biểu đồ" : "View Charts")
                         : (isVN ? "Xem danh sách" : "View List"))
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(theme.primaryAction)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(theme.surface)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }

    // MARK: - Trend Chart Card

    private var trendChartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isVN ? "Xu hướng Thu / Chi" : "Income / Expense Trend")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(theme.textPrimary)

            let chartData = makeTrendData()

            Chart {
                ForEach(chartData) { d in
                    BarMark(
                        x: .value("Mốc", d.label),
                        y: .value("Số tiền", d.amount)
                    )
                    .foregroundStyle(by: .value("Loại", d.typeString))
                    .cornerRadius(4)
                }
            }
            .chartForegroundStyleScale([
                (isVN ? "Chi tiêu ↗" : "Expense ↗"): theme.expenseColor,
                (isVN ? "Thu nhập ↙" : "Income ↙"): theme.incomeColor
            ])
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(shortFormat(v))
                                .font(.caption2)
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .font(.caption2)
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .frame(height: 200)
        }
        .padding(16)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.cardCornerRadius, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    // MARK: - Category Donut Card

    private var categoryDonutCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isVN ? "Cơ cấu chi theo Danh mục" : "Breakdown by Category")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(theme.textPrimary)

            let catData = makeCategoryBreakdown()

            if catData.isEmpty {
                Text(isVN ? "Không có khoản chi nào trong kỳ này." : "No expenses in this period.")
                    .font(.footnote)
                    .foregroundStyle(theme.textSecondary)
            } else {
                Chart(catData) { item in
                    SectorMark(
                        angle: .value("Số tiền", item.amount),
                        innerRadius: .ratio(0.58),
                        angularInset: 1.5
                    )
                    .cornerRadius(5)
                    .foregroundStyle(item.category.color)
                }
                .frame(height: 200)
                .overlay {
                    VStack(spacing: 2) {
                        Text(isVN ? "Tổng chi" : "Total Spent")
                            .font(.caption2)
                            .foregroundStyle(theme.textSecondary)
                        Text(totalExpenseVND.vndFormatted)
                            .font(.system(.footnote, design: .rounded).weight(.bold))
                            .foregroundStyle(theme.textPrimary)
                    }
                }
            }
        }
        .padding(16)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.cardCornerRadius, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    // MARK: - Top Categories Card

    private var topCategoriesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isVN ? "Phân bổ chi tiết" : "Detailed Breakdown")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(theme.textPrimary)

            let catData = makeCategoryBreakdown()
            let total = Double(max(totalExpenseVND, 1))

            ForEach(catData) { item in
                let percent = (Double(item.amount) / total) * 100.0

                VStack(spacing: 6) {
                    HStack {
                        Image(systemName: item.category.symbolName)
                            .font(.subheadline)
                            .foregroundStyle(item.category.color)
                            .frame(width: 28, height: 28)
                            .background(item.category.color.opacity(0.15))
                            .clipShape(Circle())

                        Text(locManager.localizedCategoryName(item.category.name))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(theme.textPrimary)

                        Spacer()

                        Text(item.amount.vndFormatted)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(theme.textPrimary)

                        Text(String(format: "%.1f%%", percent))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(theme.textSecondary)
                            .frame(width: 44, alignment: .trailing)
                    }

                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(theme.separator.opacity(0.4))
                                .frame(height: 6)
                            Capsule()
                                .fill(item.category.color)
                                .frame(width: geo.size.width * CGFloat(min(percent / 100.0, 1.0)), height: 6)
                        }
                    }
                    .frame(height: 6)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: theme.cardCornerRadius, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }

    // MARK: - Transactions List

    private var transactionsList: some View {
        LazyVStack(spacing: 10) {
            ForEach(periodExpenses, id: \.id) { item in
                HStack(spacing: 12) {
                    // Thumbnail hoặc Icon
                    if let thumbName = item.thumbnailFileName {
                        AsyncThumbnailView(fileName: thumbName, category: item.category)
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    } else {
                        Image(systemName: item.category.symbolName)
                            .font(.title3)
                            .foregroundStyle(item.category.color)
                            .frame(width: 44, height: 44)
                            .background(item.category.color.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.displayTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.textPrimary)
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            Text(item.category.name)
                                .font(.caption2)
                                .foregroundStyle(theme.textSecondary)

                            if let wallet = item.wallet {
                                Text("• \(wallet.name)")
                                    .font(.caption2)
                                    .foregroundStyle(theme.textSecondary)
                            }

                            Text("• \(item.spentAt, style: .date)")
                                .font(.caption2)
                                .foregroundStyle(theme.textSecondary)
                        }
                    }

                    Spacer()

                    Text(item.type == .income ? "+ \(item.amountVND.vndFormatted)" : "- \(item.amountVND.vndFormatted)")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(item.type == .income ? theme.incomeColor : theme.expenseColor)
                }
                .padding(12)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }

    // MARK: - Helper Data Builders

    private struct TrendPoint: Identifiable {
        let id = UUID()
        let label: String
        let amount: Double
        let typeString: String
    }

    private func makeTrendData() -> [TrendPoint] {
        let calendar = Calendar.current
        var points: [TrendPoint] = []
        let expTag = isVN ? "Chi tiêu ↗" : "Expense ↗"
        let incTag = isVN ? "Thu nhập ↙" : "Income ↙"

        switch granularity {
        case .day:
            // Theo 4 khoảng giờ trong ngày: Sáng (6-12h), Chiều (12-18h), Tối (18-24h), Đêm (0-6h)
            let blocks = [
                (isVN ? "Đêm" : "Night", 0..<6),
                (isVN ? "Sáng" : "Morning", 6..<12),
                (isVN ? "Chiều" : "Afternoon", 12..<18),
                (isVN ? "Tối" : "Evening", 18..<24)
            ]
            for (title, range) in blocks {
                let inBlock = periodExpenses.filter {
                    let hour = calendar.component(.hour, from: $0.spentAt)
                    return range.contains(hour)
                }
                let exp = inBlock.filter { $0.type == .expense }.reduce(0) { $0 + $1.amountVND }
                let inc = inBlock.filter { $0.type == .income }.reduce(0) { $0 + $1.amountVND }
                points.append(TrendPoint(label: title, amount: Double(exp), typeString: expTag))
                points.append(TrendPoint(label: title, amount: Double(inc), typeString: incTag))
            }

        case .month:
            // Theo 4 tuần trong tháng (hoặc các mốc 1-7, 8-14, 15-21, 22-hết tháng)
            let weeks = [
                (isVN ? "T1 (1-7)" : "W1 (1-7)", 1...7),
                (isVN ? "T2 (8-14)" : "W2 (8-14)", 8...14),
                (isVN ? "T3 (15-21)" : "W3 (15-21)", 15...21),
                (isVN ? "T4 (22+)" : "W4 (22+)", 22...31)
            ]
            for (wTitle, dRange) in weeks {
                let inWeek = periodExpenses.filter {
                    let d = calendar.component(.day, from: $0.spentAt)
                    return dRange.contains(d)
                }
                let exp = inWeek.filter { $0.type == .expense }.reduce(0) { $0 + $1.amountVND }
                let inc = inWeek.filter { $0.type == .income }.reduce(0) { $0 + $1.amountVND }
                points.append(TrendPoint(label: wTitle, amount: Double(exp), typeString: expTag))
                points.append(TrendPoint(label: wTitle, amount: Double(inc), typeString: incTag))
            }

        case .year:
            // Theo 4 quý trong năm
            let quarters = [
                (isVN ? "Q1 (T1-3)" : "Q1 (M1-3)", 1...3),
                (isVN ? "Q2 (T4-6)" : "Q2 (M4-6)", 4...6),
                (isVN ? "Q3 (T7-9)" : "Q3 (M7-9)", 7...9),
                (isVN ? "Q4 (T10-12)" : "Q4 (M10-12)", 10...12)
            ]
            for (qTitle, mRange) in quarters {
                let inQuarter = periodExpenses.filter {
                    let m = calendar.component(.month, from: $0.spentAt)
                    return mRange.contains(m)
                }
                let exp = inQuarter.filter { $0.type == .expense }.reduce(0) { $0 + $1.amountVND }
                let inc = inQuarter.filter { $0.type == .income }.reduce(0) { $0 + $1.amountVND }
                points.append(TrendPoint(label: qTitle, amount: Double(exp), typeString: expTag))
                points.append(TrendPoint(label: qTitle, amount: Double(inc), typeString: incTag))
            }
        }

        return points
    }

    private struct CategoryBreakdownItem: Identifiable {
        var id: UUID { category.id }
        let category: ExpenseCategory
        let amount: Int64
    }

    private func makeCategoryBreakdown() -> [CategoryBreakdownItem] {
        let expensesOnly = periodExpenses.filter { $0.type == .expense }
        var map: [UUID: (category: ExpenseCategory, amount: Int64)] = [:]

        for item in expensesOnly {
            if let existing = map[item.category.id] {
                map[item.category.id] = (existing.category, existing.amount + item.amountVND)
            } else {
                map[item.category.id] = (item.category, item.amountVND)
            }
        }

        return map.values
            .map { CategoryBreakdownItem(category: $0.category, amount: $0.amount) }
            .sorted { $0.amount > $1.amount }
    }

    private func shortFormat(_ val: Double) -> String {
        if val >= 1_000_000 {
            return String(format: "%.1fM", val / 1_000_000)
        } else if val >= 1_000 {
            return String(format: "%.0fk", val / 1_000)
        } else {
            return "\(Int(val))"
        }
    }
}
