import SwiftUI

// MARK: - DashboardHeaderView

/// Header trang chủ: Lời chào theo giờ kèm biểu tượng, tên in đậm và avatar viền hồng pastel
struct DashboardHeaderView: View {

    var userName: String = ""
    var currentDate: Date = Date.now
    var onOpenSettings: (() -> Void)? = nil

    private let theme = ThemeManager.shared
    private let locManager = LocalizationManager.shared
    private let authService = AuthService.shared

    private var effectiveUserName: String {
        if !userName.isEmpty { return userName }
        if let name = authService.currentUser?.displayName, !name.isEmpty {
            return name
        }
        return locManager.currentLanguage == .vietnamese ? "Bạn" : "You"
    }

    private var greetingText: (title: String, icon: String) {
        let hour = Calendar.current.component(.hour, from: currentDate)
        let isVN = locManager.currentLanguage == .vietnamese
        switch hour {
        case 5..<12:
            return (isVN ? "Chào buổi sáng" : "Good morning", "☀️")
        case 12..<18:
            return (isVN ? "Chào buổi chiều" : "Good afternoon", "🌤️")
        default:
            return (isVN ? "Chào buổi tối" : "Good evening", "🌙")
        }
    }

    private var initialLetter: String {
        guard let first = effectiveUserName.trimmingCharacters(in: .whitespaces).first else {
            return "S"
        }
        return String(first).uppercased()
    }

    var body: some View {
        HStack(alignment: .center) {
            // Bên trái: Lời chào + Tên
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(greetingText.title)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.textSecondary)

                    Text(greetingText.icon)
                        .font(.system(size: 14))
                }

                Text(effectiveUserName)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.textPrimary)
            }

            Spacer()

            // Bên phải: Nút bánh răng cài đặt & Avatar tròn viền hồng pastel #F8BBD0
            HStack(spacing: 10) {
                if let onOpenSettings = onOpenSettings {
                    Button {
                        HapticManager.shared.selectionChanged()
                        onOpenSettings()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(theme.textSecondary)
                            .frame(width: 40, height: 40)
                            .background(theme.surface)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.04), radius: 4, y: 2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(locManager.t("tab_settings"))
                }

                // Avatar người dùng thông minh
                UserAvatarView(size: 44, showActions: true)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

#Preview {
    DashboardHeaderView()
}

