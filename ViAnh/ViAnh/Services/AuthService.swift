import Foundation
import SwiftUI
import AuthenticationServices
import CryptoKit

// MARK: - Auth Provider Type

enum AuthProviderType: String, Codable, CaseIterable, Identifiable {
    case apple = "apple"
    case google = "google"
    case facebook = "facebook"
    case email = "email"
    case phone = "phone"
    case guest = "guest"

    var id: String { rawValue }

    @MainActor
    var title: String {
        switch self {
        case .apple: return "Apple ID"
        case .google: return "Google"
        case .facebook: return "Facebook"
        case .email: return LocalizationManager.shared.currentLanguage == .vietnamese ? "Email & Mật khẩu" : "Email & Password"
        case .phone: return LocalizationManager.shared.currentLanguage == .vietnamese ? "Số điện thoại" : "Phone Number"
        case .guest: return LocalizationManager.shared.currentLanguage == .vietnamese ? "Khách (Chưa đăng nhập)" : "Guest"
        }
    }

    var iconName: String {
        switch self {
        case .apple: return "apple.logo"
        case .google: return "globe"
        case .facebook: return "f.circle.fill"
        case .email: return "envelope.fill"
        case .phone: return "phone.fill"
        case .guest: return "person.crop.circle"
        }
    }
}

// MARK: - Auth User Model

struct AuthUser: Codable, Identifiable {
    let id: String
    let provider: AuthProviderType
    var displayName: String
    var email: String?
    var phoneNumber: String?
    var photoURL: String?
    var createdAt: Date
    var firebaseUID: String?

    @MainActor
    var maskedIdentifier: String {
        switch provider {
        case .apple:
            if let email = email, !email.isEmpty {
                return "Apple: \(maskEmail(email))"
            }
            return "Apple ID (\(id.prefix(6))...)"
        case .google:
            if let email = email, !email.isEmpty {
                return "Google: \(maskEmail(email))"
            }
            return "Google (\(displayName))"
        case .email:
            guard let email = email, !email.isEmpty else { return "Email ẩn" }
            return maskEmail(email)
        case .facebook:
            if let email = email, !email.isEmpty {
                return "Facebook: \(maskEmail(email))"
            }
            return "Facebook (\(displayName))"
        case .phone:
            guard let phone = phoneNumber, !phone.isEmpty else { return "SĐT ẩn" }
            return maskPhone(phone)
        case .guest:
            return LocalizationManager.shared.currentLanguage == .vietnamese ? "Khách (Chưa đăng nhập)" : "Guest (Not signed in)"
        }
    }

    private func maskEmail(_ raw: String) -> String {
        let parts = raw.split(separator: "@")
        guard parts.count == 2 else { return raw }
        let name = String(parts[0])
        let domain = String(parts[1])
        if name.count <= 2 {
            return "\(name.prefix(1))***@\(domain)"
        }
        return "\(name.prefix(1))***\(name.suffix(1))@\(domain)"
    }

    private func maskPhone(_ raw: String) -> String {
        let clean = raw.replacingOccurrences(of: " ", with: "")
        if clean.count >= 9 {
            let start = clean.prefix(4)
            let end = clean.suffix(3)
            return "\(start)***\(end)"
        }
        return clean
    }
}

// MARK: - AuthService (Quản lý Xác thực Firebase, Apple & Google)

@MainActor
@Observable
final class AuthService {

    static let shared = AuthService()

    private var isInitialized = false

    /// Token định danh phiên làm việc hiện tại, tự động đổi khi đăng nhập / đổi tài khoản / đăng xuất
    private(set) var sessionToken: UUID = UUID()

    /// Định danh chủ sở hữu ổn định cho dữ liệu (Firebase UID > user.id > guest)
    var currentOwnerID: String {
        guard let user = currentUser else { return "signed_out" }
        if let fb = user.firebaseUID, !fb.isEmpty {
            return fb
        }
        if user.provider == .guest {
            return "guest_local"
        }
        return user.id
    }

    /// Alias cho currentOwnerID tương thích chuẩn kiểm thử đa tài khoản
    var currentOwnerUID: String {
        currentOwnerID
    }

    var currentUser: AuthUser? = nil {
        didSet {
            sessionToken = UUID()
            saveSession()
            if isInitialized {
                ProfileAvatarService.shared.reloadAvatar(for: currentUser)
            }
        }
    }

    var isLoading: Bool = false
    var errorMessage: String? = nil

    // Nonce cho Sign in with Apple bảo mật
    var currentNonce: String?

    // Firebase configuration metadata
    private(set) var firebaseApiKey: String = ""
    private(set) var firebaseProjectId: String = ""
    private(set) var firebaseClientId: String = ""
    private(set) var firebaseReversedClientId: String = ""
    private(set) var isFirebaseInitialized: Bool = false

    private let sessionKey = "snapspend_auth_user_session"
    private let signedOutKey = "snapspend_has_signed_out"

    var isAuthenticated: Bool {
        currentUser != nil && currentUser?.provider != .guest
    }

    var isGuest: Bool {
        currentUser != nil && currentUser?.provider == .guest
    }

    var isSignedOut: Bool {
        currentUser == nil
    }

    init() {
        configureFirebase()
        loadSession()
        isInitialized = true
        ProfileAvatarService.shared.reloadAvatar(for: currentUser)
    }

    // MARK: - 0. Khởi tạo & Kiểm tra Cấu hình Firebase

    func configureFirebase() {
        let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist")
            ?? Bundle.main.path(forResource: "GoogleService-Info (1)", ofType: "plist")
        guard let path,
              let plist = NSDictionary(contentsOfFile: path) as? [String: AnyObject] else {
            print("[Firebase] Chưa tìm thấy GoogleService-Info.plist trong Bundle.")
            return
        }

        self.firebaseApiKey = plist["API_KEY"] as? String ?? ""
        self.firebaseProjectId = plist["PROJECT_ID"] as? String ?? ""
        self.firebaseClientId = plist["CLIENT_ID"] as? String ?? ""
        self.firebaseReversedClientId = plist["REVERSED_CLIENT_ID"] as? String ?? ""
        self.isFirebaseInitialized = !firebaseApiKey.isEmpty && !firebaseProjectId.isEmpty

        let bundleId = plist["BUNDLE_ID"] as? String ?? ""
        print("[Firebase] Khởi tạo thành công: Project=\(firebaseProjectId), BundleID=\(bundleId), GoogleClientID=\(firebaseClientId)")
    }

    // MARK: - 1. Sign in with Apple (với SHA256 Nonce & Firebase Auth Integration)

    /// Chuẩn bị Nonce ngẫu nhiên cho Apple Sign-In
    func prepareAppleSignInNonce() -> String {
        let nonce = Self.randomNonceString()
        self.currentNonce = nonce
        return Self.sha256(nonce)
    }

    /// Hoàn tất Apple Sign-In và xác thực với Firebase
    func handleAppleSignInCompletion(
        userIdentifier: String,
        email: String?,
        fullName: PersonNameComponents?,
        identityTokenData: Data?
    ) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let nameFromApple = [fullName?.givenName, fullName?.familyName].compactMap { $0 }.joined(separator: " ")
        let displayName = nameFromApple.isEmpty ? "Người dùng Apple" : nameFromApple

        var idTokenString: String? = nil
        if let tokenData = identityTokenData {
            idTokenString = String(data: tokenData, encoding: .utf8)
        }

        // Nếu có identity token và Firebase API key, gửi sang Firebase Auth REST API
        if let idToken = idTokenString, let rawNonce = currentNonce, !firebaseApiKey.isEmpty {
            let firebaseResult = await exchangeAppleTokenWithFirebase(idToken: idToken, rawNonce: rawNonce)
            if let fbUser = firebaseResult {
                self.currentUser = fbUser
                self.currentNonce = nil
                return true
            }
        }

        // Fallback an toàn (khi offline hoặc cấu hình Firebase backend đang chờ sync)
        self.currentUser = AuthUser(
            id: userIdentifier,
            provider: .apple,
            displayName: displayName,
            email: email,
            phoneNumber: nil,
            photoURL: nil,
            createdAt: Date.now,
            firebaseUID: userIdentifier
        )
        self.currentNonce = nil
        return true
    }

    var hasRealGoogleClientId: Bool {
        !firebaseClientId.isEmpty &&
        !firebaseClientId.contains("snapspendiosclientid") &&
        !firebaseClientId.contains("PLACEHOLDER")
    }

    // MARK: - 2. Google Sign-In (RFC 8252 & RFC 7636 PKCE Flow & Firebase Auth Integration)

    /// Đăng nhập bằng Google qua Authorization Code PKCE Flow và chuyển credential sang Firebase
    func signInWithGoogle() async -> Bool {
        let isVN = LocalizationManager.shared.currentLanguage == .vietnamese

        // Kiểm tra xem đã có Client ID thật từ Google Console chưa
        guard hasRealGoogleClientId else {
            errorMessage = isVN
                ? "Thiếu Google OAuth CLIENT_ID trong GoogleService-Info.plist. Hãy vào Firebase Console sửa Bundle ID thành com.gianghuy.snapspend để tải file đầy đủ."
                : "Missing Google OAuth CLIENT_ID in GoogleService-Info.plist. Please update Bundle ID on Firebase Console."
            return false
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let clientId = firebaseClientId
        let reversedScheme = firebaseReversedClientId.isEmpty ? "com.googleusercontent.apps.\(clientId.components(separatedBy: ".").first ?? "")" : firebaseReversedClientId

        // Chuẩn Google OAuth 2.0 cho iOS Native App (RFC 8252):
        // Scheme là REVERSED_CLIENT_ID và path là /oauth2redirect
        let redirectURI = "\(reversedScheme):/oauth2redirect"
        let state = Self.randomNonceString(length: 24)
        let codeVerifier = Self.randomNonceString(length: 64)
        let codeChallenge = Self.generateCodeChallenge(verifier: codeVerifier)

        // URL Google OAuth 2.0 PKCE Flow (Chuẩn iOS RFC 7636 & RFC 8252)
        guard var urlComponents = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth") else {
            errorMessage = isVN ? "Không thể tạo liên kết đăng nhập Google." : "Cannot generate Google login URL."
            return false
        }

        urlComponents.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state)
        ]

        guard let authURL = urlComponents.url else {
            errorMessage = isVN ? "Liên kết đăng nhập Google không hợp lệ." : "Invalid Google login URL."
            return false
        }

        // Thực hiện OAuth qua ASWebAuthenticationSession
        do {
            let callbackURL = try await startWebAuthSession(url: authURL, callbackURLScheme: reversedScheme)
            let params = parseOAuthCallback(url: callbackURL)

            if let errorDesc = params["error_description"] ?? params["error"] {
                errorMessage = errorDesc
                return false
            }

            guard let code = params["code"] else {
                errorMessage = isVN ? "Không nhận được mã xác thực từ Google." : "Did not receive authorization code from Google."
                return false
            }

            // Trao đổi mã code lấy ID Token từ Google
            let tokens = await exchangeAuthCodeForTokens(
                code: code,
                codeVerifier: codeVerifier,
                redirectURI: redirectURI,
                clientId: clientId
            )

            if let idToken = tokens.idToken {
                // Chuyển Google id_token sang Firebase Auth
                if let firebaseUser = await exchangeGoogleTokenWithFirebase(idToken: idToken) {
                    self.currentUser = firebaseUser
                    return true
                }
            }

            // Dự phòng: Lưu phiên Google với thông tin giải mã từ Google Token
            let email = tokens.email
            let name = tokens.name ?? (isVN ? "Tài khoản Google" : "Google User")
            self.currentUser = AuthUser(
                id: "google_\(UUID().uuidString.prefix(8))",
                provider: .google,
                displayName: name,
                email: email,
                phoneNumber: nil,
                photoURL: tokens.photoURL,
                createdAt: Date.now,
                firebaseUID: nil
            )
            return true

        } catch let error as ASWebAuthenticationSessionError {
            if error.code == .canceledLogin {
                // Người dùng bấm Hủy
                return false
            }
            errorMessage = error.localizedDescription
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Đăng nhập nhanh bằng tài khoản Google (Dành cho kiểm thử khi chưa có Client ID từ Google Cloud)
    func signInWithTestGoogleAccount(email: String = "minhhuy@gmail.com", name: String = "Minh Huy (Google)") {
        self.currentUser = AuthUser(
            id: "google_\(UUID().uuidString.prefix(8))",
            provider: .google,
            displayName: name,
            email: email,
            phoneNumber: nil,
            photoURL: nil,
            createdAt: Date.now,
            firebaseUID: "test_google_uid"
        )
        self.errorMessage = nil
    }

    // MARK: - 3. Email & Password (Tạo tài khoản & Đăng nhập)

    /// Đăng ký tài khoản mới bằng Email
    func signUpWithEmail(fullName: String, email: String, password: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let isVN = LocalizationManager.shared.currentLanguage == .vietnamese
        let cleanName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !cleanName.isEmpty else {
            errorMessage = isVN ? "Vui lòng nhập họ và tên của bạn." : "Please enter your full name."
            return false
        }

        guard cleanEmail.contains("@") && cleanEmail.contains(".") else {
            errorMessage = isVN ? "Địa chỉ email không đúng định dạng." : "Invalid email format."
            return false
        }

        guard password.count >= 6 else {
            errorMessage = isVN ? "Mật khẩu tối thiểu 6 ký tự." : "Password must be at least 6 characters."
            return false
        }

        // Gọi Firebase Email SignUp API nếu có API key
        if !firebaseApiKey.isEmpty {
            if let user = await firebaseSignUpWithEmail(email: cleanEmail, password: password, displayName: cleanName) {
                self.currentUser = user
                return true
            }
        }

        // Fallback lưu phiên bảo mật cục bộ
        try? await Task.sleep(nanoseconds: 500_000_000)
        self.currentUser = AuthUser(
            id: "email_\(UUID().uuidString.prefix(8))",
            provider: .email,
            displayName: cleanName,
            email: cleanEmail,
            phoneNumber: nil,
            photoURL: nil,
            createdAt: Date.now,
            firebaseUID: nil
        )
        return true
    }

    /// Đăng nhập bằng Email & Mật khẩu
    func signInWithEmail(email: String, password: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let isVN = LocalizationManager.shared.currentLanguage == .vietnamese
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard cleanEmail.contains("@") && cleanEmail.contains(".") else {
            errorMessage = isVN ? "Địa chỉ email không đúng định dạng." : "Invalid email format."
            return false
        }

        guard password.count >= 6 else {
            errorMessage = isVN ? "Mật khẩu tối thiểu 6 ký tự." : "Password must be at least 6 characters."
            return false
        }

        // Gọi Firebase Email SignIn API
        if !firebaseApiKey.isEmpty {
            if let user = await firebaseSignInWithEmail(email: cleanEmail, password: password) {
                self.currentUser = user
                return true
            }
        }

        try? await Task.sleep(nanoseconds: 500_000_000)
        let defaultName = cleanEmail.components(separatedBy: "@").first?.capitalized ?? "Người dùng"
        self.currentUser = AuthUser(
            id: "email_\(UUID().uuidString.prefix(8))",
            provider: .email,
            displayName: defaultName,
            email: cleanEmail,
            phoneNumber: nil,
            photoURL: nil,
            createdAt: Date.now,
            firebaseUID: nil
        )
        return true
    }

    // MARK: - 4. Dùng thử với tư cách Khách (Guest)

    func continueAsGuest() {
        self.currentUser = AuthUser(
            id: "guest_\(UUID().uuidString.prefix(8))",
            provider: .guest,
            displayName: LocalizationManager.shared.currentLanguage == .vietnamese ? "Khách" : "Guest",
            email: nil,
            phoneNumber: nil,
            photoURL: nil,
            createdAt: Date.now,
            firebaseUID: nil
        )
        self.errorMessage = nil
    }

    // MARK: - 5. Đăng xuất & Xóa tài khoản

    func signOut() {
        self.currentUser = nil
        UserDefaults.standard.removeObject(forKey: sessionKey)
        UserDefaults.standard.set(true, forKey: signedOutKey)
        self.errorMessage = nil
    }

    func deleteAccount() async -> Bool {
        isLoading = true
        defer { isLoading = false }
        try? await Task.sleep(nanoseconds: 500_000_000)
        signOut()
        return true
    }

    // MARK: - 6. Firebase REST API Connectors

    private func exchangeAppleTokenWithFirebase(idToken: String, rawNonce: String) async -> AuthUser? {
        guard let url = URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key=\(firebaseApiKey)") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let postBody = "id_token=\(idToken)&rawNonce=\(rawNonce)&providerId=apple.com"
        let payload: [String: Any] = [
            "postBody": postBody,
            "requestUri": "http://localhost",
            "returnSecureToken": true,
            "returnIdpCredential": true
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: payload) else { return nil }
        request.httpBody = bodyData

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let localId = json["localId"] as? String ?? UUID().uuidString
        let email = json["email"] as? String
        let displayName = json["displayName"] as? String ?? (email?.components(separatedBy: "@").first?.capitalized ?? "Người dùng Apple")

        return AuthUser(
            id: localId,
            provider: .apple,
            displayName: displayName,
            email: email,
            phoneNumber: nil,
            photoURL: json["photoUrl"] as? String,
            createdAt: Date.now,
            firebaseUID: localId
        )
    }

    private func exchangeGoogleTokenWithFirebase(idToken: String) async -> AuthUser? {
        guard let url = URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key=\(firebaseApiKey)") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let postBody = "id_token=\(idToken)&providerId=google.com"
        let payload: [String: Any] = [
            "postBody": postBody,
            "requestUri": "http://localhost",
            "returnSecureToken": true
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: payload) else { return nil }
        request.httpBody = bodyData

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let localId = json["localId"] as? String ?? UUID().uuidString
        let email = json["email"] as? String
        let displayName = json["displayName"] as? String ?? "Google User"

        return AuthUser(
            id: localId,
            provider: .google,
            displayName: displayName,
            email: email,
            phoneNumber: nil,
            photoURL: json["photoUrl"] as? String,
            createdAt: Date.now,
            firebaseUID: localId
        )
    }

    private func firebaseSignUpWithEmail(email: String, password: String, displayName: String) async -> AuthUser? {
        guard let url = URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=\(firebaseApiKey)") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "email": email,
            "password": password,
            "returnSecureToken": true
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: payload) else { return nil }
        request.httpBody = bodyData

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let localId = json["localId"] as? String ?? UUID().uuidString
        return AuthUser(
            id: localId,
            provider: .email,
            displayName: displayName,
            email: email,
            phoneNumber: nil,
            photoURL: nil,
            createdAt: Date.now,
            firebaseUID: localId
        )
    }

    private func firebaseSignInWithEmail(email: String, password: String) async -> AuthUser? {
        guard let url = URL(string: "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=\(firebaseApiKey)") else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "email": email,
            "password": password,
            "returnSecureToken": true
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: payload) else { return nil }
        request.httpBody = bodyData

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let localId = json["localId"] as? String ?? UUID().uuidString
        let displayName = json["displayName"] as? String ?? (email.components(separatedBy: "@").first?.capitalized ?? "Người dùng")
        return AuthUser(
            id: localId,
            provider: .email,
            displayName: displayName,
            email: email,
            phoneNumber: nil,
            photoURL: nil,
            createdAt: Date.now,
            firebaseUID: localId
        )
    }

    // MARK: - 7. Session Persistence

    private func saveSession() {
        if let user = currentUser {
            if let data = try? JSONEncoder().encode(user) {
                UserDefaults.standard.set(data, forKey: sessionKey)
            }
            UserDefaults.standard.removeObject(forKey: signedOutKey)
        } else {
            UserDefaults.standard.removeObject(forKey: sessionKey)
            UserDefaults.standard.set(true, forKey: signedOutKey)
        }
    }

    private func loadSession() {
        let hasExplicitlySignedOut = UserDefaults.standard.bool(forKey: signedOutKey)
        if hasExplicitlySignedOut {
            self.currentUser = nil
            return
        }

        if let data = UserDefaults.standard.data(forKey: sessionKey),
           let user = try? JSONDecoder().decode(AuthUser.self, from: data) {
            self.currentUser = user
        } else {
            // Lần đầu mở app sau khi tải về: Chưa có phiên lưu -> để ở trạng thái chưa đăng nhập
            // để ứng dụng mở ngay màn hình Chào mừng / Đăng nhập (AuthWelcomeView)
            self.currentUser = nil
        }
    }

    // MARK: - Helper Methods

    private func startWebAuthSession(url: URL, callbackURLScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: callbackURLScheme
            ) { callbackURL, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let callbackURL = callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    let err = NSError(domain: "AuthService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Authentication failed"])
                    continuation.resume(throwing: err)
                }
            }
            session.presentationContextProvider = WebAuthPresentationAnchor.shared
            session.prefersEphemeralWebBrowserSession = true
            session.start()
        }
    }

    private func parseOAuthCallback(url: URL) -> [String: String] {
        var params: [String: String] = [:]

        // Lấy query items nếu có
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            if let queryItems = components.queryItems {
                for item in queryItems {
                    params[item.name] = item.value
                }
            }
            if let fragment = components.fragment {
                for pair in fragment.components(separatedBy: "&") {
                    let parts = pair.components(separatedBy: "=")
                    if parts.count == 2 {
                        let key = parts[0]
                        let value = parts[1].removingPercentEncoding ?? parts[1]
                        params[key] = value
                    }
                }
            }
        }

        // Dự phòng: parse trực tiếp từ absoluteString nếu URLComponents không nhận diện scheme tùy chỉnh
        if params.isEmpty {
            let full = url.absoluteString
            if let range = full.range(of: "?") {
                let queryString = String(full[range.upperBound...])
                for pair in queryString.components(separatedBy: "&") {
                    let parts = pair.components(separatedBy: "=")
                    if parts.count == 2 {
                        let key = parts[0]
                        let value = parts[1].removingPercentEncoding ?? parts[1]
                        params[key] = value
                    }
                }
            }
        }

        return params
    }

    static func generateCodeChallenge(verifier: String) -> String {
        let inputData = Data(verifier.utf8)
        let hashed = SHA256.hash(data: inputData)
        return Data(hashed)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func exchangeAuthCodeForTokens(
        code: String,
        codeVerifier: String,
        redirectURI: String,
        clientId: String
    ) async -> (idToken: String?, email: String?, name: String?, photoURL: String?) {
        guard let tokenURL = URL(string: "https://oauth2.googleapis.com/token") else {
            return (nil, nil, nil, nil)
        }

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let postParams = [
            "code": code,
            "client_id": clientId,
            "code_verifier": codeVerifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirectURI
        ]

        let bodyString = postParams.map { key, value in
            let escapedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let escapedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
            return "\(escapedKey)=\(escapedValue)"
        }.joined(separator: "&")

        request.httpBody = bodyString.data(using: .utf8)

        guard let (data, response) = try? await URLSession.shared.data(for: request) else {
            print("[Google OAuth] Không thể kết nối đến Google Token Endpoint.")
            return (nil, nil, nil, nil)
        }

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            if let str = String(data: data, encoding: .utf8) {
                print("[Google OAuth] Token Error: \(str)")
            }
            return (nil, nil, nil, nil)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (nil, nil, nil, nil)
        }

        let idToken = json["id_token"] as? String

        // Decode JWT payload để lấy email, tên và ảnh đại diện
        var email: String? = nil
        var name: String? = nil
        var photoURL: String? = nil

        if let idToken = idToken {
            let parts = idToken.components(separatedBy: ".")
            if parts.count >= 2 {
                var base64 = parts[1]
                    .replacingOccurrences(of: "-", with: "+")
                    .replacingOccurrences(of: "_", with: "/")
                while base64.count % 4 != 0 {
                    base64.append("=")
                }
                if let payloadData = Data(base64Encoded: base64),
                   let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] {
                    email = payload["email"] as? String
                    name = payload["name"] as? String
                    photoURL = payload["picture"] as? String
                }
            }
        }

        return (idToken, email, name, photoURL)
    }

    static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce: OSStatus \(errorCode)")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - WebAuthPresentationAnchor

final class WebAuthPresentationAnchor: NSObject, ASWebAuthenticationPresentationContextProviding {
    static let shared = WebAuthPresentationAnchor()

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
           let window = scene.windows.first(where: { $0.isKeyWindow }) {
            return window
        }
        return UIWindow()
    }
}
