import SwiftUI
import AuthenticationServices

// MARK: - Auth Mode Enum

private enum AuthMode {
    case welcome
    case email
}

// MARK: - AuthWelcomeView (Màn hình Chào mừng & Đăng nhập SnapSpend)

struct AuthWelcomeView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var mode: AuthMode = .welcome
    @State private var isRegisterMode = false

    // Email form state
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showForgotPasswordAlert = false
    @State private var showGoogleConfigAlert = false

    // Legal sheet
    @State private var showPrivacySheet = false

    private let authService = AuthService.shared
    private let theme = ThemeManager.shared
    private let locManager = LocalizationManager.shared

    private var isVN: Bool {
        locManager.currentLanguage == .vietnamese
    }

    var body: some View {
        NavigationStack {
            ZStack {
                theme.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 26) {
                        // Header Logo & Branding
                        appHeaderView
                            .padding(.top, 20)

                        // Nội dung theo từng chế độ đăng nhập
                        switch mode {
                        case .welcome:
                            welcomeButtonsView
                        case .email:
                            emailAuthFormView
                        }

                        // Hiển thị thông báo lỗi bảo mật nếu có
                        if let error = authService.errorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(theme.expenseColor)
                                Text(error)
                                    .font(.footnote)
                                    .foregroundStyle(theme.expenseColor)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(theme.expenseColor.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .transition(.opacity.combined(with: .scale))
                        }

                        // Điều khoản & Chính sách bảo mật SnapSpend
                        legalTermsFooterView
                            .padding(.top, 6)

                        Spacer(minLength: 32)
                    }
                    .padding(.horizontal, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if mode != .welcome {
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                mode = .welcome
                                authService.errorMessage = nil
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text(isVN ? "Quay lại" : "Back")
                            }
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(theme.primaryAction)
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if !authService.isSignedOut {
                        Button(locManager.t("action_cancel")) {
                            dismiss()
                        }
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                    }
                }
            }
            .sheet(isPresented: $showPrivacySheet) {
                NavigationStack {
                    DataPrivacyView()
                }
            }
            .alert(
                isVN ? "Khôi phục mật khẩu" : "Reset Password",
                isPresented: $showForgotPasswordAlert
            ) {
                Button("OK") {}
            } message: {
                Text(isVN
                     ? "Nếu email \(email) đã được đăng ký, hướng dẫn đặt lại mật khẩu an toàn đã được gửi đến hòm thư của bạn."
                     : "If the email \(email) is registered, password reset instructions have been sent to your inbox.")
            }
            .alert(
                isVN ? "Đăng nhập Google" : "Google Sign-In",
                isPresented: $showGoogleConfigAlert
            ) {
                Button(isVN ? "Đăng nhập thử nghiệm" : "Test Sign-In") {
                    authService.signInWithTestGoogleAccount()
                    HapticManager.shared.notifySuccess()
                    dismiss()
                }
                Button(isVN ? "Đóng" : "Cancel", role: .cancel) {}
            } message: {
                Text(isVN
                     ? "Lỗi 401 trên ảnh là do file GoogleService-Info.plist tải về từ Firebase chưa có Google OAuth CLIENT_ID (do Bundle ID lúc tạo trên Firebase chưa khớp com.gianghuy.snapspend).\n\nBạn có thể bấm \"Đăng nhập thử nghiệm\" để vào app kiểm tra tính năng ngay lập tức."
                     : "Google OAuth CLIENT_ID is missing in GoogleService-Info.plist. Tap \"Test Sign-In\" to test the app immediately.")
            }
        }
    }

    // MARK: - App Header (Logo & Brand)

    private var appHeaderView: some View {
        VStack(spacing: 12) {
            Image("AppLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: Color.black.opacity(0.12), radius: 12, y: 6)

            VStack(spacing: 6) {
                Text("SnapSpend")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundStyle(theme.textPrimary)

                Text(isVN
                     ? "Quản lý chi tiêu bằng hình ảnh trong 3 giây"
                     : "Visual expense tracking in 3 seconds")
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - 1. Welcome Buttons (Apple, Google, Email, Guest - Tạm ẩn Facebook)

    private var welcomeButtonsView: some View {
        VStack(spacing: 14) {
            // 1. Sign in with Apple (Chuẩn Apple HIG & Nonce Security)
            SignInWithAppleButton(.signIn) { request in
                let hashedNonce = authService.prepareAppleSignInNonce()
                request.requestedScopes = [.fullName, .email]
                request.nonce = hashedNonce
            } onCompletion: { result in
                handleAppleSignInResult(result)
            }
            .signInWithAppleButtonStyle(theme.isDarkModeEffective ? .white : .black)
            .frame(height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Color.black.opacity(0.08), radius: 6, y: 2)

            // 2. Tiếp tục với Google (Chuẩn Google Branding & Firebase Integration)
            Button {
                handleGoogleSignIn()
            } label: {
                HStack(spacing: 12) {
                    googleLogoView
                    Text(isVN ? "Tiếp tục với Google" : "Continue with Google")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(theme.separator, lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.04), radius: 4, y: 1)
            }
            .buttonStyle(.plain)

            // 3. Tiếp tục với Email & Mật khẩu
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    mode = .email
                    authService.errorMessage = nil
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "envelope.fill")
                        .font(.body)
                        .foregroundStyle(theme.textSecondary)
                    Text(isVN ? "Tiếp tục với Email" : "Continue with Email")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(theme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(theme.separator, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)

            // Phân cách hoặc
            HStack {
                Rectangle()
                    .fill(theme.separator)
                    .frame(height: 0.5)
                Text(isVN ? "hoặc" : "or")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
                    .padding(.horizontal, 10)
                Rectangle()
                    .fill(theme.separator)
                    .frame(height: 0.5)
            }
            .padding(.vertical, 4)

            // 4. Tiếp tục với tư cách Khách (Dùng thử ngay)
            Button {
                authService.continueAsGuest()
                HapticManager.shared.notifySuccess()
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.circle")
                    Text(isVN ? "Dùng thử ngay không cần tài khoản" : "Explore SnapSpend as Guest")
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(theme.primaryAction)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
        }
    }

    // Biểu tượng Google Logo 4 màu sắc nét
    private var googleLogoView: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 24, height: 24)

            Text("G")
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(hex: "#4285F4") ?? .blue,
                            Color(hex: "#EA4335") ?? .red,
                            Color(hex: "#FBBC05") ?? .yellow,
                            Color(hex: "#34A853") ?? .green
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }

    // MARK: - 2. Email Auth Form

    private var emailAuthFormView: some View {
        VStack(spacing: 16) {
            // Segment Đăng nhập / Đăng ký
            Picker("", selection: $isRegisterMode) {
                Text(isVN ? "Đăng nhập" : "Sign In").tag(false)
                Text(isVN ? "Tạo tài khoản" : "Create Account").tag(true)
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 4)
            .onChange(of: isRegisterMode) { _, _ in
                authService.errorMessage = nil
            }

            // Họ và tên (khi Đăng ký)
            if isRegisterMode {
                VStack(alignment: .leading, spacing: 6) {
                    Text(isVN ? "Họ và tên" : "Full Name")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.textSecondary)

                    TextField(isVN ? "Nguyễn Văn A" : "John Appleseed", text: $fullName)
                        .textContentType(.name)
                        .autocorrectionDisabled()
                        .padding(14)
                        .background(theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.separator, lineWidth: 1))
                }
            }

            // Email Field
            VStack(alignment: .leading, spacing: 6) {
                Text("Email")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.textSecondary)

                TextField("name@example.com", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding(14)
                    .background(theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.separator, lineWidth: 1))
            }

            // Password Field
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(isVN ? "Mật khẩu" : "Password")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.textSecondary)

                    Spacer()

                    if !isRegisterMode {
                        Button {
                            showForgotPasswordAlert = true
                        } label: {
                            Text(isVN ? "Quên mật khẩu?" : "Forgot?")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(theme.primaryAction)
                        }
                    }
                }

                SecureField(isVN ? "Tối thiểu 6 ký tự" : "Minimum 6 characters", text: $password)
                    .textContentType(isRegisterMode ? .newPassword : .password)
                    .padding(14)
                    .background(theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.separator, lineWidth: 1))
            }

            // Confirm Password Field (khi đăng ký)
            if isRegisterMode {
                VStack(alignment: .leading, spacing: 6) {
                    Text(isVN ? "Xác nhận mật khẩu" : "Confirm Password")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.textSecondary)

                    SecureField(isVN ? "Nhập lại mật khẩu" : "Re-enter password", text: $confirmPassword)
                        .textContentType(.newPassword)
                        .padding(14)
                        .background(theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme.separator, lineWidth: 1))
                }
            }

            // Nút Xác nhận
            Button {
                Task {
                    if isRegisterMode {
                        if fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            authService.errorMessage = isVN ? "Vui lòng nhập họ và tên của bạn." : "Please enter your full name."
                            return
                        }
                        if password != confirmPassword {
                            authService.errorMessage = isVN ? "Mật khẩu xác nhận không khớp." : "Passwords do not match."
                            return
                        }
                    }

                    let success: Bool
                    if isRegisterMode {
                        success = await authService.signUpWithEmail(fullName: fullName, email: email, password: password)
                    } else {
                        success = await authService.signInWithEmail(email: email, password: password)
                    }
                    if success {
                        HapticManager.shared.notifySuccess()
                        dismiss()
                    }
                }
            } label: {
                HStack {
                    if authService.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text(isRegisterMode
                             ? (isVN ? "Tạo tài khoản SnapSpend" : "Create SnapSpend Account")
                             : (isVN ? "Đăng nhập" : "Sign In"))
                            .font(.system(size: 16, weight: .bold))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(theme.primaryAction)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: theme.primaryAction.opacity(0.3), radius: 6, y: 2)
            }
            .buttonStyle(.plain)
            .disabled(authService.isLoading || email.isEmpty || password.isEmpty || (isRegisterMode && fullName.isEmpty))
            .opacity((email.isEmpty || password.isEmpty || (isRegisterMode && fullName.isEmpty)) ? 0.6 : 1.0)

            // Nút chuyển đổi nhanh giữa Đăng nhập và Đăng ký
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isRegisterMode.toggle()
                    authService.errorMessage = nil
                }
            } label: {
                Text(isRegisterMode
                     ? (isVN ? "Đã có tài khoản? Đăng nhập ngay" : "Already have an account? Sign In")
                     : (isVN ? "Chưa có tài khoản? Tạo tài khoản mới" : "New to SnapSpend? Create an account"))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(theme.primaryAction)
                    .padding(.top, 4)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Legal Footer

    private var legalTermsFooterView: some View {
        VStack(spacing: 4) {
            Text(isVN
                 ? "Bằng việc tiếp tục, bạn đồng ý với Điều khoản dịch vụ & Chính sách bảo mật của SnapSpend."
                 : "By continuing, you agree to SnapSpend's Terms of Service & Privacy Policy.")
                .font(.caption2)
                .foregroundStyle(theme.textSecondary)
                .multilineTextAlignment(.center)

            Button {
                showPrivacySheet = true
            } label: {
                Text(isVN ? "Xem Chính sách bảo mật & Quyền riêng tư" : "View Privacy Policy & Terms")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(theme.primaryAction)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Actions

    private func handleAppleSignInResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
                let userIdentifier = appleIDCredential.user
                let email = appleIDCredential.email
                let fullName = appleIDCredential.fullName
                let identityToken = appleIDCredential.identityToken

                Task {
                    let success = await authService.handleAppleSignInCompletion(
                        userIdentifier: userIdentifier,
                        email: email,
                        fullName: fullName,
                        identityTokenData: identityToken
                    )
                    if success {
                        HapticManager.shared.notifySuccess()
                        dismiss()
                    }
                }
            }
        case .failure(let error):
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                authService.errorMessage = error.localizedDescription
            }
        }
    }

    private func handleGoogleSignIn() {
        if !authService.hasRealGoogleClientId {
            showGoogleConfigAlert = true
            return
        }
        Task {
            let success = await authService.signInWithGoogle()
            if success {
                HapticManager.shared.notifySuccess()
                dismiss()
            }
        }
    }
}
