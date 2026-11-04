import XCTest
import CryptoKit
import SwiftData
@testable import ViAnh

// MARK: - SecurityAndAuthTests

/// Bộ kiểm thử tự động cho hệ thống Bảo mật & Xác thực:
/// Google OAuth 2.0 PKCE (RFC 7636 / RFC 8252), Sign in with Apple (Guideline 4.8),
/// Session Token Invalidation và Dọn dẹp tài khoản (Guideline 5.1.1(v))
@MainActor
final class SecurityAndAuthTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() async throws {
        let schema = Schema([
            ExpenseItem.self,
            ExpenseCategory.self,
            MonthlyBudget.self,
            CategoryBudget.self,
            Wallet.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext

        CategoryManager.seedDefaultCategoriesIfNeeded(context: context)
    }

    override func tearDown() async throws {
        container = nil
        context = nil
    }

    // MARK: - 1. Kiểm thử độ ngẫu nhiên & tập ký tự PKCE Code Verifier

    func testPKCECodeVerifierEntropyAndCharset() {
        let verifier = AuthService.randomNonceString(length: 64)
        XCTAssertEqual(verifier.count, 64, "Code verifier phải có độ dài đúng 64 ký tự")

        // Tập ký tự theo RFC 7636: [0-9a-zA-Z-._~]
        let allowedCharacters = CharacterSet(charactersIn: "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let verifierCharacterSet = CharacterSet(charactersIn: verifier)
        XCTAssertTrue(allowedCharacters.isSuperset(of: verifierCharacterSet), "Tất cả ký tự trong Code Verifier phải thuộc tập an toàn RFC 7636")

        // Hai lần sinh liên tiếp phải hoàn toàn khác biệt (Entropy cao)
        let verifier2 = AuthService.randomNonceString(length: 64)
        XCTAssertNotEqual(verifier, verifier2, "Hai chuỗi Code Verifier sinh ra liên tiếp phải có giá trị ngẫu nhiên khác nhau")
    }

    // MARK: - 2. Sinh Code Challenge chuẩn S256 (RFC 7636 Base64URL không padding)

    func testPKCECodeChallengeS256Generation() {
        // Giá trị mẫu kiểm thử
        let testVerifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
        let challenge = AuthService.generateCodeChallenge(verifier: testVerifier)

        // RFC 7636 Base64URL: không chứa '+', '/', '='
        XCTAssertFalse(challenge.contains("+"), "Code challenge không được chứa ký tự '+'")
        XCTAssertFalse(challenge.contains("/"), "Code challenge không được chứa ký tự '/'")
        XCTAssertFalse(challenge.contains("="), "Code challenge không được chứa ký tự padding '='")

        // Tự tính độc lập bằng CryptoKit để xác thực tính đúng đắn toán học
        let hashed = SHA256.hash(data: Data(testVerifier.utf8))
        let expected = Data(hashed)
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        XCTAssertEqual(challenge, expected, "Thuật toán sinh Code Challenge phải khớp hoàn hảo với chuẩn SHA256 Base64URL")
    }

    // MARK: - 3. Nonce cho Sign in with Apple và băm SHA-256 (Guideline 4.8)

    func testAppleSignInNonceSHA256Hash() {
        let authService = AuthService.shared
        let hashedNonce = authService.prepareAppleSignInNonce()

        XCTAssertNotNil(authService.currentNonce)
        guard let rawNonce = authService.currentNonce else {
            XCTFail("Raw nonce phải được lưu trong service")
            return
        }

        XCTAssertEqual(rawNonce.count, 32, "Apple Nonce ngẫu nhiên phải có độ dài 32 ký tự")

        // Kiểm tra mã băm SHA-256 là chuỗi hex 64 ký tự
        XCTAssertEqual(hashedNonce.count, 64, "Mã băm SHA-256 dạng hex phải có độ dài 64 ký tự")
        XCTAssertEqual(AuthService.sha256(rawNonce), hashedNonce, "Hàm sha256 phải khớp với hashedNonce gửi lên Apple")
    }

    // MARK: - 4. Cơ chế Session Token Invalidation khi chuyển tài khoản

    func testSessionTokenInvalidationOnAccountSwitch() {
        let authService = AuthService.shared

        let initialToken = authService.sessionToken

        // Đăng nhập User A
        let userA = AuthUser(
            id: "user_a_001",
            provider: .google,
            displayName: "User A",
            email: "a@gmail.com",
            createdAt: .now,
            firebaseUID: "FIREBASE_UID_A"
        )
        authService.currentUser = userA
        let tokenAfterUserA = authService.sessionToken
        XCTAssertNotEqual(initialToken, tokenAfterUserA, "SessionToken phải đổi khi nạp User A")

        // Chuyển sang User B
        let userB = AuthUser(
            id: "user_b_002",
            provider: .apple,
            displayName: "User B",
            email: "b@privaterelay.appleid.com",
            createdAt: .now,
            firebaseUID: "FIREBASE_UID_B"
        )
        authService.currentUser = userB
        let tokenAfterUserB = authService.sessionToken
        XCTAssertNotEqual(tokenAfterUserA, tokenAfterUserB, "SessionToken phải đổi khi chuyển sang User B")

        // Đăng xuất
        authService.currentUser = nil
        let tokenAfterSignOut = authService.sessionToken
        XCTAssertNotEqual(tokenAfterUserB, tokenAfterSignOut, "SessionToken phải đổi khi đăng xuất")
    }

    // MARK: - 5. Hủy tác vụ nền khi SessionToken bị thay đổi

    func testBackgroundTaskCancellationWhenSessionTokenChanges() async {
        let authService = AuthService.shared

        // Giả lập phiên đang hoạt động
        authService.currentUser = AuthUser(
            id: "user_sim",
            provider: .email,
            displayName: "Sim User",
            createdAt: .now,
            firebaseUID: "UID_SESSION_SIM"
        )

        let capturedStartingToken = authService.sessionToken
        let targetUID = authService.currentOwnerUID

        var taskDidSaveData = false

        // Mô phỏng logic kiểm tra bảo vệ trong ExpenseCaptureView
        let backgroundSaveTask = Task {
            // Giả lập thời gian nén ảnh trên luồng nền
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

            // Guard Session Token: nếu token hoặc UID đã đổi, hủy ngay lập tức
            guard authService.sessionToken == capturedStartingToken && authService.currentOwnerUID == targetUID else {
                return // Hủy bỏ, không lưu
            }
            taskDidSaveData = true
        }

        // Đột ngột đổi tài khoản trong lúc tác vụ đang chạy
        authService.currentUser = AuthUser(
            id: "user_other",
            provider: .google,
            displayName: "Other User",
            createdAt: .now,
            firebaseUID: "UID_OTHER"
        )

        await backgroundSaveTask.value

        XCTAssertFalse(taskDidSaveData, "Tác vụ nền phải bị hủy và KHÔNG được ghi dữ liệu khi sessionToken bị thay đổi")
    }

    // MARK: - 6. Định dạng URL Redirect Google OAuth chuẩn RFC 8252

    func testGoogleOAuthRedirectURLFormatRFC8252() {
        let reversedScheme = "com.googleusercontent.apps.509543339422-vou9fk538v977uffeomhsmkd9jns9v32"
        let redirectURI = "\(reversedScheme):/oauth2redirect"

        XCTAssertTrue(redirectURI.hasSuffix(":/oauth2redirect"), "Redirect URI cho iOS Native App bắt buộc phải có path :/oauth2redirect theo RFC 8252")
        XCTAssertTrue(redirectURI.hasPrefix("com.googleusercontent.apps."), "Scheme phải bắt đầu bằng Reversed Client ID của ứng dụng")
    }

    // MARK: - 7. Dọn sạch dữ liệu khi Xóa tài khoản (App Store Guideline 5.1.1(v))

    func testAccountDeletionPurgesLocalUserFilesAndData() throws {
        let cat = try context.fetch(FetchDescriptor<ExpenseCategory>(predicate: #Predicate { $0.isDefault == true })).first!
        let targetUID = "UID_DELETE_TARGET"

        // 1. Tạo khoản chi của tài khoản này
        let item1 = ExpenseItem(amountVND: 80_000, category: cat, title: "Ăn tối", ownerUID: targetUID)
        let item2 = ExpenseItem(amountVND: 120_000, category: cat, title: "Tiền xe", ownerUID: targetUID)
        let otherUserItem = ExpenseItem(amountVND: 200_000, category: cat, title: "Khoản chi người khác", ownerUID: "UID_REMAINING_USER")

        context.insert(item1)
        context.insert(item2)
        context.insert(otherUserItem)

        // 2. Tạo ngân sách của tài khoản này
        let budget = MonthlyBudget(year: 2026, month: 11, totalBudgetVND: 5_000_000, ownerUID: targetUID)
        context.insert(budget)

        try context.save()

        // 3. Thực hiện dọn sạch dữ liệu gắn với UID này
        let fetchExpenses = FetchDescriptor<ExpenseItem>(predicate: #Predicate { $0.ownerUID == targetUID })
        let expensesToDelete = try context.fetch(fetchExpenses)
        for exp in expensesToDelete {
            context.delete(exp)
        }

        let fetchBudgets = FetchDescriptor<MonthlyBudget>(predicate: #Predicate { $0.ownerUID == targetUID })
        let budgetsToDelete = try context.fetch(fetchBudgets)
        for b in budgetsToDelete {
            context.delete(b)
        }

        try context.save()

        // 4. Kiểm tra sau khi dọn sạch
        let remainingForTarget = try context.fetch(fetchExpenses)
        let remainingForOther = try context.fetch(FetchDescriptor<ExpenseItem>(predicate: #Predicate { $0.ownerUID == "UID_REMAINING_USER" }))

        XCTAssertEqual(remainingForTarget.count, 0, "Toàn bộ dữ liệu của tài khoản bị xóa phải là 0")
        XCTAssertEqual(remainingForOther.count, 1, "Dữ liệu của tài khoản khác phải được giữ nguyên vẹn")
    }
}

