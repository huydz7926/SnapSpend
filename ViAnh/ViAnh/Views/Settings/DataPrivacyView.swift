import SwiftUI

// MARK: - DataPrivacyView (Chính sách Bảo mật & Quyền riêng tư chính thức của SnapSpend)

struct DataPrivacyView: View {

    @Environment(\.dismiss) private var dismiss

    private let theme = ThemeManager.shared
    private let locManager = LocalizationManager.shared

    private var isVN: Bool {
        locManager.currentLanguage == .vietnamese
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header badge
                headerBadgeView

                // 1. Giới thiệu & Cam kết của SnapSpend
                policySection(
                    title: isVN ? "1. Giới thiệu & Cam kết bảo mật" : "1. Introduction & Commitment",
                    icon: "hand.raised.shield.fill"
                ) {
                    Text(isVN
                         ? "Chào mừng bạn đến với SnapSpend. Chúng tôi thấu hiểu rằng thông tin tài chính và hình ảnh chi tiêu cá nhân là những dữ liệu cực kỳ nhạy cảm. SnapSpend được thiết kế với triết lý 'Quyền riêng tư là ưu tiên số một' (Privacy by Design). Chính sách này giải thích rõ ràng và minh bạch về cách thức ứng dụng bảo vệ dữ liệu của bạn."
                         : "Welcome to SnapSpend. We understand that personal financial logs and expense photos are highly sensitive. SnapSpend is built on a 'Privacy by Design' philosophy. This policy transparently outlines how we safeguard your personal data.")
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                }

                // 2. Dữ liệu ứng dụng xử lý
                policySection(
                    title: isVN ? "2. Dữ liệu ứng dụng xử lý" : "2. Information Handled by SnapSpend",
                    icon: "tray.full.fill"
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        bulletPoint(
                            bold: isVN ? "Ảnh chụp chi tiêu & Hóa đơn:" : "Expense Photos & Receipts:",
                            desc: isVN
                            ? " Những bức ảnh bạn chụp trực tiếp từ camera hoặc chọn từ Thư viện ảnh khi ghi chép khoản chi. Ứng dụng chỉ xử lý ảnh bạn chủ động chọn và không quét bất kỳ hình ảnh nào khác trong máy."
                            : " Photos you capture with the camera or select from your photo library. We only process photos you explicitly choose and never scan other images."
                        )
                        bulletPoint(
                            bold: isVN ? "Nhật ký giao dịch & Ngân sách:" : "Financial Logs & Budgets:",
                            desc: isVN
                            ? " Số tiền, danh mục (Ăn uống, Di chuyển...), ngày giờ, ví tiền và ghi chú chi tiêu do bạn nhập."
                            : " Expense amounts, categories, timestamps, wallets, and personal notes entered by you."
                        )
                        bulletPoint(
                            bold: isVN ? "Thông tin tài khoản đăng nhập:" : "Account Information:",
                            desc: isVN
                            ? " Tên hiển thị và địa chỉ Email khi bạn đăng ký/đăng nhập bằng Apple ID, Facebook hoặc Email để nhận diện tài khoản."
                            : " Display name and Email address when signing in via Apple ID, Facebook, or Email."
                        )
                    }
                }

                // 3. Cơ chế Lưu trữ Cục bộ (Local-First)
                policySection(
                    title: isVN ? "3. Lưu trữ Cục bộ & Mã hóa trên iPhone" : "3. Local-First & Device Encryption",
                    icon: "lock.shield.fill"
                ) {
                    Text(isVN
                         ? "Toàn bộ hình ảnh và nhật ký chi tiêu của bạn được lưu trữ trực tiếp trên bộ nhớ thiết bị iPhone thông qua công nghệ SwiftData và Sandbox bảo mật của hệ điều hành iOS. Dữ liệu được bảo vệ an toàn bởi lớp mã hóa phần cứng của Apple (Apple Secure Enclave)."
                         : "All your expense photos and transaction history are stored directly on your iPhone using Apple's encrypted SwiftData and iOS Sandbox architecture, secured by Apple hardware-level protection.")
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                }

                // 4. Quyền truy cập thiết bị (Permissions)
                policySection(
                    title: isVN ? "4. Quyền truy cập thiết bị (Camera & Ảnh)" : "4. Device Permissions",
                    icon: "camera.fill"
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        bulletPoint(
                            bold: isVN ? "• Camera:" : "• Camera:",
                            desc: isVN ? " Chỉ kích hoạt khi bạn bấm nút thêm chi tiêu để chụp hóa đơn/món đồ trong 3 giây." : " Only accessed when you tap to capture a quick receipt or item photo."
                        )
                        bulletPoint(
                            bold: isVN ? "• Thư viện ảnh (Photo Library):" : "• Photo Library:",
                            desc: isVN ? " Dùng để chọn ảnh cũ từ album và lưu ảnh kỷ niệm chi tiêu theo yêu cầu của bạn." : " Used to import existing receipts or save memory photos at your request."
                        )
                        bulletPoint(
                            bold: isVN ? "• Thông báo (Notifications):" : "• Notifications:",
                            desc: isVN ? " Gửi lời nhắc ghi chép chi tiêu buổi tối (20:00) hoặc cảnh báo khi vượt 80% ngân sách tháng." : " Delivers evening expense reminders (20:00) or over-budget alerts."
                        )
                    }
                }

                // 5. Cam kết KHÔNG bán dữ liệu
                policySection(
                    title: isVN ? "5. Cam kết tuyệt đối không bán dữ liệu" : "5. Zero Data Commercialization",
                    icon: "xmark.shield.fill"
                ) {
                    Text(isVN
                         ? "SnapSpend cam kết KHÔNG bán, KHÔNG cho thuê, KHÔNG chia sẻ dữ liệu tài chính hay hành vi tiêu dùng của bạn cho bất kỳ nhà quảng cáo, môi giới dữ liệu hoặc bên thứ ba nào vì mục đích thương mại."
                         : "SnapSpend strictly DOES NOT sell, rent, monetize, or disclose your financial records and spending habits to any third-party advertisers or data brokers.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(theme.incomeColor)
                }

                // 6. Dịch vụ Xác thực Bên thứ ba
                policySection(
                    title: isVN ? "6. Dịch vụ Xác thực & Đăng nhập" : "6. Third-Party Authentication",
                    icon: "key.fill"
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        bulletPoint(bold: "Sign in with Apple:", desc: isVN ? " Sử dụng công nghệ xác thực ẩn danh bảo mật cao nhất của Apple." : " High-security private sign-in provided by Apple.")
                        bulletPoint(bold: "Facebook Login:", desc: isVN ? " Đăng nhập tiện lợi thông qua giao thức bảo mật OAuth 2.0 của Meta." : " Standard OAuth 2.0 authentication via Meta Developers.")
                        bulletPoint(bold: "Email & Mật khẩu:", desc: isVN ? " Dữ liệu mật khẩu được mã hóa an toàn, không lưu trữ dạng văn bản thô." : " Secure encrypted credentials, never stored in plaintext.")
                    }
                }

                // 7. Quyền của Người dùng & Xuất dữ liệu
                policySection(
                    title: isVN ? "7. Toàn quyền Kiểm soát & Xuất dữ liệu" : "7. Your Rights & Data Portability",
                    icon: "person.crop.circle.badge.checkmark"
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        bulletPoint(
                            bold: isVN ? "• Xuất file CSV (Excel):" : "• Export CSV (Excel):",
                            desc: isVN ? " Bạn có thể sao lưu và xuất toàn bộ lịch sử chi tiêu ra file CSV bất cứ khi nào bạn muốn từ mục Cài đặt." : " Export complete transaction history to CSV (Excel) anytime via Settings."
                        )
                        bulletPoint(
                            bold: isVN ? "• Xóa tài khoản vĩnh viễn (Apple Guideline 5.1.1(v)):" : "• Account & Data Deletion:",
                            desc: isVN ? " Bạn có quyền xóa bất kỳ giao dịch nào hoặc bấm 'Xóa tài khoản' để xóa sạch 100% dữ liệu khỏi hệ thống." : " Delete individual logs or permanently purge all account data via 'Delete Account' in Settings."
                        )
                    }
                }

                // 8. Kênh Hỗ trợ & Thông tin Liên hệ
                policySection(
                    title: isVN ? "8. Kênh Hỗ trợ & Liên hệ SnapSpend" : "8. Support & Contact",
                    icon: "envelope.circle.fill"
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(isVN
                             ? "Nếu bạn có bất kỳ câu hỏi, góp ý hoặc yêu cầu hỗ trợ về quyền riêng tư, vui lòng liên hệ trực tiếp với chúng tôi:"
                             : "For questions, feedback, or data privacy requests, please contact our team directly:")
                            .font(.subheadline)
                            .foregroundStyle(theme.textSecondary)

                        HStack(spacing: 8) {
                            Image(systemName: "envelope.fill")
                                .foregroundStyle(theme.primaryAction)
                            Text("Email hỗ trợ:")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(theme.textPrimary)
                            Text("huytx3z3@gmail.com")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(theme.primaryAction)
                        }

                        Text(isVN ? "Ứng dụng: SnapSpend – Quản lý thu chi bằng hình ảnh" : "Application: SnapSpend – Visual Expense Tracker")
                            .font(.caption)
                            .foregroundStyle(theme.textSecondary)
                    }
                }

                Spacer(minLength: 24)
            }
            .padding(20)
        }
        .background(theme.background)
        .navigationTitle(isVN ? "Chính sách Quyền riêng tư" : "Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(locManager.t("action_done")) {
                    dismiss()
                }
                .font(.body.weight(.semibold))
            }
        }
    }

    // MARK: - Header Badge

    private var headerBadgeView: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(theme.incomeColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "lock.shield.fill")
                    .font(.title3)
                    .foregroundStyle(theme.incomeColor)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(isVN ? "Cam kết Quyền riêng tư SnapSpend" : "SnapSpend Privacy Commitment")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(theme.textPrimary)
                Text(isVN ? "Bản phát hành chính thức 2026" : "Official 2026 Release")
                    .font(.caption2)
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(theme.separator, lineWidth: 1))
    }

    // MARK: - Policy Section Helper

    private func policySection<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(theme.primaryAction)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)
            }

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(theme.separator, lineWidth: 1))
    }

    // MARK: - Bullet Point Helper

    private func bulletPoint(bold: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(theme.primaryAction)
            Text(.init("**\(bold)**\(desc)"))
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)
        }
    }
}
