import SwiftUI
import SwiftData
import StoreKit

// MARK: - SettingsView (SnapSpend)

struct SettingsView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query private var allExpenses: [ExpenseItem]

    private var currentOwnerUID: String {
        authService.currentOwnerID
    }

    /// Lọc triệt để chỉ các giao dịch thuộc chủ tài khoản hiện tại
    private var userExpenses: [ExpenseItem] {
        guard !authService.isSignedOut else { return [] }
        return allExpenses.filter { $0.ownerUID == currentOwnerUID }
    }

    @AppStorage("app_language") private var appLanguage: String = "vi"
    @AppStorage("app_display_currency") private var appDisplayCurrency: String = "VND"
    @AppStorage("app_theme_mode") private var appThemeMode: String = "autoTime"
    @AppStorage("app_theme_palette") private var appThemePalette: String = "warmCream"

    @State private var budgetAlertEnabled = true
    @State private var dailyReminderEnabled = false
    @State private var showShareSheet = false
    @State private var csvURL: URL? = nil
    @State private var alertMessage: String? = nil

    @State private var showAuthSheet = false
    @State private var showSignOutConfirm = false
    @State private var showDeleteAccountConfirm = false

    private let theme = ThemeManager.shared
    private let locManager = LocalizationManager.shared
    private let currencyService = CurrencyExchangeService.shared
    private let authService = AuthService.shared

    private var isVN: Bool {
        locManager.currentLanguage == .vietnamese
    }

    var body: some View {
        List {
            accountSection
            languageAndThemeSection
            currencyAndLiveRatesSection
            categoriesSection
            notificationsSection
            dataExportSection
            reviewAndShareSection
            legalSection
        }
        .navigationTitle(locManager.t("tab_settings"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(locManager.t("action_done")) {
                    dismiss()
                }
                .font(.body.weight(.semibold))
            }
        }
        .sheet(isPresented: $showAuthSheet) {
            AuthWelcomeView()
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = csvURL {
                ShareActivityView(activityItems: [url])
            }
        }
        .modifier(SettingsAlertsModifier(
            isVN: isVN,
            cancelTitle: locManager.t("action_cancel"),
            showSignOutConfirm: $showSignOutConfirm,
            showDeleteAccountConfirm: $showDeleteAccountConfirm,
            alertMessage: $alertMessage,
            onSignOut: {
                authService.signOut()
                HapticManager.shared.notifyWarning()
                dismiss()
            },
            onDeleteAccount: {
                Task {
                    _ = await authService.deleteAccount()
                    HapticManager.shared.notifyWarning()
                    dismiss()
                }
            }
        ))
    }

    // MARK: - 0. Tài khoản SnapSpend

    private var accountSection: some View {
        Section(locManager.currentLanguage == .vietnamese ? "Tài khoản SnapSpend" : "SnapSpend Account") {
            if authService.isAuthenticated, let user = authService.currentUser {
                HStack(spacing: 14) {
                    UserAvatarView(size: 54, showActions: true, showCameraBadge: true)

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(user.displayName)
                                .font(.body.weight(.bold))
                                .foregroundStyle(theme.textPrimary)
                            Text(user.provider.title)
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(theme.primaryAction.opacity(0.1))
                                .foregroundStyle(theme.primaryAction)
                                .clipShape(Capsule())
                        }
                        Text(user.maskedIdentifier)
                            .font(.caption)
                            .foregroundStyle(theme.textSecondary)
                        Text(isVN ? "Chạm vào ảnh để đổi" : "Tap photo to change")
                            .font(.caption2)
                            .foregroundStyle(theme.primaryAction)
                    }
                }
                .padding(.vertical, 4)

                // Nút Đăng xuất
                Button(role: .destructive) {
                    showSignOutConfirm = true
                } label: {
                    Label(
                        locManager.currentLanguage == .vietnamese ? "Đăng xuất" : "Sign Out",
                        systemImage: "rectangle.portrait.and.arrow.right"
                    )
                    .foregroundStyle(theme.expenseColor)
                }

                // Nút Xóa tài khoản (Apple App Store Guideline 5.1.1(v))
                Button(role: .destructive) {
                    showDeleteAccountConfirm = true
                } label: {
                    Label(
                        locManager.currentLanguage == .vietnamese ? "Xóa tài khoản" : "Delete Account",
                        systemImage: "person.crop.circle.badge.minus"
                    )
                    .font(.footnote)
                    .foregroundStyle(theme.textSecondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.system(size: 32))
                            .foregroundStyle(theme.textSecondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(locManager.currentLanguage == .vietnamese ? "Chế độ Khách (Chưa đăng nhập)" : "Guest Mode (Not signed in)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(theme.textPrimary)
                            Text(locManager.currentLanguage == .vietnamese ? "Đăng nhập để đồng bộ và sao lưu an toàn." : "Sign in to backup and sync securely.")
                                .font(.caption)
                                .foregroundStyle(theme.textSecondary)
                        }
                    }

                    Button {
                        showAuthSheet = true
                    } label: {
                        Text(locManager.currentLanguage == .vietnamese ? "Đăng nhập / Tạo tài khoản" : "Sign In / Register")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 38)
                            .background(theme.primaryAction)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - 1. Ngôn ngữ & Giao diện

    private var languageAndThemeSection: some View {
        Section(locManager.currentLanguage == .vietnamese ? "Ngôn ngữ & Giao diện" : "Language & Appearance") {
            Picker(locManager.currentLanguage == .vietnamese ? "Ngôn ngữ" : "Language", selection: Binding(
                get: { locManager.currentLanguage },
                set: {
                    locManager.currentLanguage = $0
                    appLanguage = $0.rawValue
                    HapticManager.shared.selectionChanged()
                }
            )) {
                ForEach(AppLanguage.allCases) { lang in
                    Text(lang.title).tag(lang)
                }
            }

            Picker(locManager.currentLanguage == .vietnamese ? "Bảng màu chủ đạo" : "Color Palette", selection: Binding(
                get: { theme.palette },
                set: {
                    theme.palette = $0
                    appThemePalette = $0.rawValue
                    HapticManager.shared.selectionChanged()
                }
            )) {
                ForEach(AppThemePalette.allCases) { p in
                    Text(p.title).tag(p)
                }
            }

            Picker(locManager.currentLanguage == .vietnamese ? "Chế độ hiển thị" : "Display Mode", selection: Binding(
                get: { theme.mode },
                set: {
                    theme.mode = $0
                    appThemeMode = $0.rawValue
                    HapticManager.shared.selectionChanged()
                }
            )) {
                ForEach(AppThemeMode.allCases) { m in
                    Text(m.title).tag(m)
                }
            }
        }
    }

    // MARK: - 2. Tiền tệ & Tỷ giá Tự động

    private var currencyAndLiveRatesSection: some View {
        Section(locManager.currentLanguage == .vietnamese ? "Tiền tệ & Tỷ giá thị trường" : "Currency & Live Rates") {
            Picker(locManager.currentLanguage == .vietnamese ? "Tiền tệ hiển thị" : "Display Currency", selection: Binding(
                get: { currencyService.displayCurrency },
                set: {
                    currencyService.displayCurrency = $0
                    appDisplayCurrency = $0.rawValue
                    HapticManager.shared.selectionChanged()
                }
            )) {
                ForEach(SupportedCurrency.allCases) { curr in
                    Text(curr.title).tag(curr)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("1 USD ≈")
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                    Text(Int64(currencyService.usdToVndRate).vndFormatted)
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(theme.textPrimary)
                }

                HStack {
                    Text("1 EUR ≈")
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                    Spacer()
                    Text(Int64(currencyService.eurToVndRate).vndFormatted)
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(theme.textPrimary)
                }

                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.caption2)
                        .foregroundStyle(theme.textSecondary)
                    Text(locManager.currentLanguage == .vietnamese
                         ? "Cập nhật từ thị trường: \(DateHelpers.formatRelativeDateTime(currencyService.lastRateUpdate))"
                         : "Market rate updated: \(DateHelpers.formatRelativeDateTime(currencyService.lastRateUpdate))")
                        .font(.caption2)
                        .foregroundStyle(theme.textSecondary)

                    Spacer()

                    Button {
                        Task {
                            await currencyService.fetchLiveRates()
                            HapticManager.shared.notifySuccess()
                        }
                    } label: {
                        if currencyService.isFetchingRates {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text(locManager.currentLanguage == .vietnamese ? "Làm mới" : "Refresh")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(theme.primaryAction)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - 3. Quản lý Danh mục

    private var categoriesSection: some View {
        Section(locManager.currentLanguage == .vietnamese ? "Danh mục chi tiêu" : "Expense Categories") {
            NavigationLink(destination: CategoryManagementView()) {
                Label(
                    locManager.currentLanguage == .vietnamese ? "Quản lý Danh mục & Biểu tượng" : "Manage Categories & Icons",
                    systemImage: "tag.fill"
                )
            }
        }
    }

    // MARK: - 4. Thông báo & Nhắc nhở

    private var notificationsSection: some View {
        Section(locManager.currentLanguage == .vietnamese ? "Thông báo & Nhắc nhở" : "Notifications & Reminders") {
            Toggle(
                locManager.currentLanguage == .vietnamese ? "Cảnh báo vượt ngân sách" : "Over-budget Alerts",
                isOn: $budgetAlertEnabled
            )
            .onChange(of: budgetAlertEnabled) { _, newValue in
                if newValue {
                    Task { _ = await NotificationManager.shared.requestAuthorization() }
                }
            }

            Toggle(
                locManager.currentLanguage == .vietnamese ? "Nhắc ghi chép mỗi tối (20:00)" : "Daily Evening Reminder (20:00)",
                isOn: $dailyReminderEnabled
            )
            .onChange(of: dailyReminderEnabled) { _, newValue in
                Task {
                    if newValue {
                        _ = await NotificationManager.shared.requestAuthorization()
                    }
                    NotificationManager.shared.scheduleDailyReminder(isEnabled: newValue)
                }
            }
        }
    }

    // MARK: - 5. Dữ liệu & Xuất CSV

    private var dataExportSection: some View {
        Section(locManager.currentLanguage == .vietnamese ? "Dữ liệu & Sao lưu" : "Data & Export") {
            Button {
                exportCSV()
            } label: {
                HStack {
                    Label(
                        locManager.currentLanguage == .vietnamese ? "Xuất dữ liệu CSV (Excel)" : "Export CSV (Excel)",
                        systemImage: "square.and.arrow.up"
                    )
                    Spacer()
                    Text("\(userExpenses.count) \(locManager.t("label_photos"))")
                        .font(.caption)
                        .foregroundStyle(Color.secondary)
                }
            }
        }
    }

    // MARK: - 6. Đánh giá & Lan tỏa

    private var reviewAndShareSection: some View {
        Section(locManager.currentLanguage == .vietnamese ? "Đánh giá & Lan tỏa" : "Review & Share") {
            Button {
                requestReview()
            } label: {
                Label(
                    locManager.currentLanguage == .vietnamese ? "Đánh giá SnapSpend trên App Store" : "Rate SnapSpend on App Store",
                    systemImage: "star.fill"
                )
            }

            ShareLink(
                item: URL(string: "https://apps.apple.com/app/vianh-snapspend")!,
                subject: Text("SnapSpend"),
                message: Text(locManager.currentLanguage == .vietnamese
                              ? "Trải nghiệm ứng dụng quản lý thu chi bằng hình ảnh cực nhanh chỉ trong 3 giây!"
                              : "Visual expense tracking with photos in 3 seconds!")
            ) {
                Label(
                    locManager.currentLanguage == .vietnamese ? "Chia sẻ ứng dụng cho bạn bè" : "Share App with Friends",
                    systemImage: "square.and.arrow.up.fill"
                )
            }

            // Gửi ý kiến đóng góp qua email
            if let feedbackURL = URL(string: "mailto:huytx3z3@gmail.com?subject=SnapSpend%20Feedback") {
                Link(destination: feedbackURL) {
                    Label(
                        locManager.currentLanguage == .vietnamese ? "Gửi ý kiến đóng góp (huytx3z3@gmail.com)" : "Send Feedback (huytx3z3@gmail.com)",
                        systemImage: "envelope.badge.fill"
                    )
                }
            }
        }
    }

    // MARK: - 7. Thông tin & Pháp lý

    private var legalSection: some View {
        Section(locManager.currentLanguage == .vietnamese ? "Thông tin & Pháp lý" : "About & Legal") {
            NavigationLink(destination: DataPrivacyView()) {
                Label(
                    locManager.currentLanguage == .vietnamese ? "Chính sách & Quyền riêng tư" : "Privacy Policy",
                    systemImage: "lock.shield.fill"
                )
            }

            NavigationLink(destination: AboutView()) {
                Label(
                    locManager.currentLanguage == .vietnamese ? "Về SnapSpend" : "About SnapSpend",
                    systemImage: "info.circle.fill"
                )
            }
        }
    }

    // MARK: - Export Logic

    private func exportCSV() {
        guard !userExpenses.isEmpty else {
            alertMessage = locManager.currentLanguage == .vietnamese
                ? "Chưa có giao dịch nào để xuất CSV."
                : "No transactions to export."
            return
        }

        do {
            let url = try CSVExportService.exportToFile(expenses: userExpenses)
            self.csvURL = url
            self.showShareSheet = true
            HapticManager.shared.notifySuccess()
        } catch {
            alertMessage = locManager.currentLanguage == .vietnamese
                ? "Không thể tạo file CSV: \(error.localizedDescription)"
                : "Failed to create CSV file: \(error.localizedDescription)"
        }
    }

    private func requestReview() {
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }
}

// MARK: - ShareActivityView

struct ShareActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - SettingsAlertsModifier

private struct SettingsAlertsModifier: ViewModifier {
    let isVN: Bool
    let cancelTitle: String
    @Binding var showSignOutConfirm: Bool
    @Binding var showDeleteAccountConfirm: Bool
    @Binding var alertMessage: String?
    let onSignOut: () -> Void
    let onDeleteAccount: () -> Void

    func body(content: Content) -> some View {
        content
            .alert(
                isVN ? "Đăng xuất tài khoản?" : "Sign Out?",
                isPresented: $showSignOutConfirm
            ) {
                Button(isVN ? "Đăng xuất" : "Sign Out", role: .destructive, action: onSignOut)
                Button(cancelTitle, role: .cancel) {}
            } message: {
                Text(isVN
                     ? "Bạn có chắc chắn muốn đăng xuất? Dữ liệu chi tiêu trên máy vẫn được bảo toàn."
                     : "Are you sure you want to sign out? Your local expense data will be preserved.")
            }
            .alert(
                isVN ? "Xác nhận xóa tài khoản?" : "Delete Account?",
                isPresented: $showDeleteAccountConfirm
            ) {
                Button(isVN ? "Xóa vĩnh viễn" : "Delete Permanently", role: .destructive, action: onDeleteAccount)
                Button(cancelTitle, role: .cancel) {}
            } message: {
                Text(isVN
                     ? "Hành động này sẽ xóa dữ liệu tài khoản và đăng xuất phiên hiện tại."
                     : "This action will permanently delete account info and sign out your session.")
            }
            .alert(
                isVN ? "Thông báo" : "Notice",
                isPresented: Binding(
                    get: { alertMessage != nil },
                    set: { if !$0 { alertMessage = nil } }
                )
            ) {
                Button("OK") {}
            } message: {
                Text(alertMessage ?? "")
            }
    }
}
