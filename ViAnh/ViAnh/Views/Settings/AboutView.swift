import SwiftUI

// MARK: - AboutView (Về SnapSpend)

struct AboutView: View {

    private let theme = ThemeManager.shared
    private let locManager = LocalizationManager.shared

    private var isVN: Bool {
        locManager.currentLanguage == .vietnamese
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Logo & Tên ứng dụng
                VStack(spacing: 12) {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 92, height: 92)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .shadow(color: Color.black.opacity(0.12), radius: 12, y: 6)

                    VStack(spacing: 4) {
                        Text("SnapSpend")
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .foregroundStyle(theme.textPrimary)

                        Text(isVN ? "Phiên bản 1.0.0 (Build 2026.11)" : "Version 1.0.0 (Build 2026.11)")
                            .font(.subheadline)
                            .foregroundStyle(theme.textSecondary)

                        Text(isVN
                             ? "Quản lý chi tiêu bằng hình ảnh trong 3 giây"
                             : "Visual expense diary in 3 seconds")
                            .font(.footnote)
                            .foregroundStyle(theme.textSecondary)
                    }
                }
                .padding(.top, 16)

                // Tính năng nổi bật
                VStack(alignment: .leading, spacing: 14) {
                    featureBullet(
                        icon: "camera.fill",
                        title: isVN ? "Ghi chép siêu tốc bằng ảnh" : "Visual Expense Logging",
                        desc: isVN ? "Chụp hóa đơn hoặc món đồ và lưu ngay trong 3 giây." : "Snap receipts or items in 3 seconds."
                    )
                    featureBullet(
                        icon: "dollarsign.circle.fill",
                        title: isVN ? "Nhập tiền thông minh" : "Smart Money Input",
                        desc: isVN ? "Bàn phím tự nhiên kiểu Techcombank với phím tắt 000." : "Natural numeric keypad with 000 quick chips."
                    )
                    featureBullet(
                        icon: "chart.pie.fill",
                        title: isVN ? "Kiểm soát ngân sách đa ngưỡng" : "Multi-threshold Budgeting",
                        desc: isVN ? "Cảnh báo thông minh khi đạt 80%, 100% và khi vượt ngưỡng." : "Live warnings when reaching 80%, 100% or exceeded."
                    )
                    featureBullet(
                        icon: "lock.shield.fill",
                        title: isVN ? "Quyền riêng tư tối đa" : "Privacy by Design",
                        desc: isVN ? "Lưu trữ SwiftData offline trên máy, không thương mại hóa dữ liệu." : "Offline local-first SwiftData storage, zero tracking."
                    )
                }
                .padding(20)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(theme.separator, lineWidth: 1)
                }
                .padding(.horizontal, 20)

                // Mục Gửi ý kiến đóng góp trực tiếp
                VStack(spacing: 12) {
                    Text(isVN ? "Bạn có ý kiến đóng góp hoặc cần hỗ trợ?" : "Have feedback or need assistance?")
                        .font(.footnote)
                        .foregroundStyle(theme.textSecondary)

                    if let emailURL = URL(string: "mailto:huytx3z3@gmail.com?subject=SnapSpend%20Feedback") {
                        Link(destination: emailURL) {
                            HStack(spacing: 8) {
                                Image(systemName: "envelope.fill")
                                Text(isVN ? "Gửi ý kiến tới: huytx3z3@gmail.com" : "Email us: huytx3z3@gmail.com")
                                    .fontWeight(.semibold)
                            }
                            .font(.system(size: 15))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(theme.primaryAction)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: theme.primaryAction.opacity(0.25), radius: 6, y: 2)
                        }
                    }
                }
                .padding(.horizontal, 20)

                // Bản quyền
                Text("© 2026 SnapSpend · Made with ❤️ for iOS 17+")
                    .font(.caption2)
                    .foregroundStyle(theme.textSecondary)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
            }
        }
        .background(theme.background.ignoresSafeArea())
        .navigationTitle(isVN ? "Về SnapSpend" : "About SnapSpend")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func featureBullet(icon: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(theme.primaryAction)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.textPrimary)

                Text(desc)
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }
}
