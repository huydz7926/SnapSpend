# 🛡️ PHẦN 4: SECURITY & COMPLIANCE (BẢO MẬT & TUÂN THỦ APP STORE)

> **Dự án:** SnapSpend  
> **Tiêu chuẩn bảo mật:** OAuth 2.0 PKCE (RFC 7636) | RFC 8252 BCP | Apple App Store Review Guidelines  
> **Cơ chế phòng thủ:** Cách ly dữ liệu đa người dùng (Multi-tenant Data Isolation) | Chống tấn công giả mạo (Replay Protection) | Quản lý phiên an toàn (Session Token Invalidation)  

---

## 1. Tổng quan Kiến trúc Bảo mật

Ứng dụng quản lý tài chính đòi hỏi tính riêng tư và bảo mật dữ liệu ở mức độ cao nhất. SnapSpend được thiết kế với mô hình phòng thủ 4 lớp:
1. **Lớp Xác thực (Authentication):** Triển khai chuẩn PKCE cho Google Sign-In và SHA-256 Nonce cho Apple Sign-In.
2. **Lớp Cách ly Dữ liệu (Data Isolation):** Mọi giao dịch, ngân sách, danh mục và ảnh đều được gắn chặt với Firebase UID của người dùng.
3. **Lớp Phiên làm việc (Session Management):** Khi đăng xuất hoặc đổi tài khoản, token phiên (`sessionToken`) lập tức thay đổi, hủy bỏ toàn bộ tác vụ nền đang chạy để chống ghi nhầm chéo tài khoản.
4. **Lớp Quyền hạn (Permissions & Entitlements):** Khai báo minh bạch mục đích truy cập Camera và Thư viện ảnh, tích hợp capability `com.apple.developer.applesignin`.

---

## 2. Bản đồ Cấu trúc Module Security

```
4_Security/
├── Services/
│   ├── AuthService.swift               # Triển khai thuật toán mã hóa SHA-256, PKCE Code Challenge, quản lý phiên
│   ├── ProfileAvatarService.swift      # Quản lý avatar độc lập theo UID (`avatar_firebase_<uid>.jpg`)
│   └── DataOwnerMigrationService.swift # Bảo vệ dữ liệu lịch sử, chống nhận vơ dữ liệu khi đổi tài khoản
│
├── Entitlements/
│   └── ViAnh.entitlements              # Kích hoạt Sign in with Apple trên Apple Developer
│
└── Compliance/
    └── DataPrivacyView.swift           # Màn hình Chính sách Bảo mật & Nút Xóa vĩnh viễn tài khoản trong app
```

---

## 3. Các Giải pháp Kỹ thuật Bảo mật Trọng yếu

### 3.1. Chống Tấn công Đánh cắp Mã Ủy quyền: PKCE (RFC 7636)
- **Vấn đề trên thiết bị di động:** Giao thức OAuth truyền thống dễ bị các ứng dụng độc hại đăng ký trùng Custom URL Scheme để đánh cắp `auth_code`.
- **Giải pháp trong `AuthService.swift`:**
  1. Tạo chuỗi ngẫu nhiên bảo mật cao `codeVerifier` (độ dài 64 ký tự).
  2. Băm bằng thuật toán SHA-256: `codeChallenge = Base64URL(SHA256(codeVerifier))`.
  3. Gửi `codeChallenge` sang Google khi xin cấp quyền.
  4. Khi nhận mã `code`, chỉ client nào sở hữu `codeVerifier` gốc ban đầu mới có thể đổi lấy Token từ Google. Kẻ tấn công nếu chặn được `code` cũng không thể giải mã và không thể đăng nhập.

### 3.2. Chống Tấn công Phát lại (Replay Attacks): Sign in with Apple Nonce
- Tạo `nonce` ngẫu nhiên 32 ký tự, băm SHA-256 truyền vào `ASAuthorizationAppleIDRequest`.
- Apple ký nonce này vào trong JWT Token. Khi gửi sang Firebase, Firebase xác thực chữ ký số của Apple, đảm bảo token chỉ được sử dụng đúng 1 lần duy nhất cho phiên yêu cầu đó.

### 3.3. Giải pháp Cách ly Tuyệt đối Dữ liệu (`ownerUID`)
- **Triệt tiêu lỗi rò rỉ dữ liệu khi đổi tài khoản:**
  - Thuộc tính `ownerUID` được áp dụng cho mọi bản ghi trong cơ sở dữ liệu (`ExpenseItem`, `MonthlyBudget`, `ExpenseCategory`, `Wallet`).
  - Mọi câu lệnh truy vấn SwiftData (`#Predicate`), tính toán tổng thu chi trên Dashboard, thống kê Analytics, xuất file CSV đều lọc nghiêm ngặt: `item.ownerUID == currentOwnerUID`.
  - Khi Tài khoản A đăng xuất và Tài khoản B đăng nhập, B lập tức thấy số dư bằng 0 ₫ và không thể nhìn thấy bất kỳ khoản chi tiêu hay hình ảnh hóa đơn nào của A.
  - Khi A đăng nhập lại, toàn bộ dữ liệu của A hiển thị nguyên vẹn.

### 3.4. Chống Lỗi Ghi Chéo Bất đồng bộ (Race Condition Prevention)
- Khi chụp ảnh hoặc nhập số tiền lớn, tác vụ nén ảnh chạy trên luồng nền (`Task.detached`).
- Nếu trong lúc ảnh đang nén mà người dùng bấm Đăng xuất hoặc chuyển tài khoản khác, hệ thống sẽ kiểm tra `sessionToken`.
- Nếu phát hiện `sessionToken` đã thay đổi, hệ thống hủy bỏ (abort) ngay lập tức tác vụ lưu, bảo đảm không bao giờ ghi nhầm hóa đơn của phiên cũ sang tài khoản mới.

---

## 4. Danh mục Tuân thủ App Store Review Guidelines

| Tiêu chuẩn của Apple | Yêu cầu | Triển khai thực tế trong SnapSpend | Trạng thái |
|---|---|---|:---:|
| **Guideline 4.8** | Bắt buộc có Sign in with Apple nếu app có đăng nhập bên thứ ba (Google) | Nút Apple Sign-in đặt ở vị trí trang trọng nhất, hỗ trợ Face ID / Touch ID | ✅ **ĐẠT** |
| **Guideline 5.1.1(v)** | Bắt buộc có tính năng Xóa tài khoản trực tiếp trong ứng dụng | Nút "Xóa tài khoản" trong Cài đặt với hộp thoại cảnh báo 2 lớp và xóa sạch dữ liệu cục bộ | ✅ **ĐẠT** |
| **Guideline 5.1.1** | Phải có Chính sách Quyền riêng tư minh bạch | Màn hình `DataPrivacyView` giải thích chi tiết mục đích sử dụng Camera, Ảnh và cung cấp email hỗ trợ `huytx3z3@gmail.com` | ✅ **ĐẠT** |
| **Usage Descriptions** | Khai báo lý do xin quyền người dùng trong `Info.plist` | Đã khai báo chi tiết `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`, `NSPhotoLibraryAddUsageDescription` | ✅ **ĐẠT** |
| **App Store Assets** | Biểu tượng ứng dụng đủ kích thước, không chứa kênh trong suốt | Đã đóng gói `AppIcon` đầy đủ các kích thước (1024x1024, 180x180, 120x120), kiểm tra trực tiếp trên `.xcarchive` thành công | ✅ **ĐẠT** |

