# Tiến độ Dự án: SnapSpend (Codebase ViAnh)

> **Tệp đồng bộ tiến độ giữa Claude Code (Terminal) và Agent (Antigravity/Gemini/Codex)**  
> **Cập nhật lần cuối:** 2026-11-03 22:56  
> **Nền tảng:** iOS 17.0+ | SwiftUI | SwiftData | Swift 6 Concurrency  
> **Tên hiển thị App:** SnapSpend (`CFBundleDisplayName`) | **Bundle ID:** `com.gianghuy.snapspend`

---

## 1. TỔNG QUAN TRẠNG THÁI HIỆN TẠI

- **Mục tiêu sản phẩm:** Ứng dụng quản lý thu chi bằng hình ảnh trên iPhone theo phong cách Locket & SnapSpend (Mở app → chạm [+] → chụp ảnh gọn gàng → nhập nhanh tiền bằng bàn phím số/phím tắt → lưu trong 3 giây).
- **Trạng thái Build:**
  - `xcodebuild -scheme ViAnh -destination generic/platform=iOS Simulator`: ✅ **BUILD SUCCEEDED** (0 lỗi, biên dịch hoàn hảo toàn dự án)
  - `ViAnh.entitlements`: Đã kích hoạt `com.apple.developer.applesignin` (Sign in with Apple).
  - `GoogleService-Info.plist` & `GoogleService-Info (1).plist`: Đã cấu hình và đóng gói chính xác với Client ID thật từ Firebase cho `com.gianghuy.snapspend`.
  - `Info.plist`: Đã đăng ký URL Scheme thật `com.googleusercontent.apps.509543339422-vou9fk538v977uffeomhsmkd9jns9v32` cho Google Sign-In Callback.
  - `AuthService.swift`: Đã chuyển sang chuẩn PKCE Authorization Code Flow (RFC 7636 / RFC 8252), tự động đổi code lấy token và xác thực với Firebase Auth.

---

## 2. TIẾN ĐỘ CHI TIẾT CÁC ĐỢT NÂNG CẤP

| Đợt | Nội dung yêu cầu | Trạng thái | Tệp mã nguồn chính |
|:---:|---|:---:|---|
| **Đợt 1 → Đợt 7** | Camera 0.5x, Góc rộng selfie, Nhập tiền Techcombank, Đăng xuất, Tiếng Anh 100%, Xóa theme theo giờ (về System/Light/Dark). | ✅ **HOÀN THÀNH** | Toàn bộ các module cơ sở |
| **ĐỢT 8** | **TẬP TRUNG APPLE & GOOGLE SIGN-IN, FIREBASE AUTHENTICATION, TẠO TÀI KHOẢN EMAIL, TẠM ẨN FACEBOOK**<br>1. **Kiểm tra & Chuẩn hóa `GoogleService-Info.plist`**:<br>- File tải về từ Firebase Console đã có đầy đủ `CLIENT_ID`, `REVERSED_CLIENT_ID` và `BUNDLE_ID com.gianghuy.snapspend`.<br>- Cả hai bản `GoogleService-Info.plist` và `GoogleService-Info (1).plist` trong project đều đã được đồng bộ chuẩn 100%.<br>2. **Hoàn thiện URL Scheme & Callback**:<br>- `Info.plist` đã cấu hình `CFBundleURLSchemes` khớp chính xác với `REVERSED_CLIENT_ID`: `com.googleusercontent.apps.509543339422-vou9fk538v977uffeomhsmkd9jns9v32`.<br>- Hỗ trợ callback an toàn quay lại app sau khi người dùng đăng nhập trên trình duyệt.<br>3. **Nâng cấp Google Sign-In PKCE Flow (Khắc phục lỗi 400)**:<br>- Dùng chuẩn PKCE với `response_type=code` và `code_challenge` SHA-256 (RFC 7636).<br>- Tự động trao đổi auth code lấy Google ID Token tại endpoint `oauth2.googleapis.com/token`.<br>- Gửi ID Token sang Firebase Auth `signInWithIdp` để tạo/đồng bộ người dùng.<br>4. **Rà soát Client ID & Bundle ID hardcode**:<br>- Quét sạch toàn bộ mã nguồn: loại bỏ mọi chuỗi ID cũ hoặc placeholder.<br>- Đồng bộ bundle ID trong `CameraService.swift`, `Info.plist`, `REQUEST.md` sang `com.gianghuy.snapspend`.<br>5. **Biên dịch & Sẵn sàng thử nghiệm**:<br>- `xcodebuild` thành công 100% với 0 lỗi cảnh báo block. | ✅ **HOÀN THÀNH** | `GoogleService-Info.plist`<br>`Info.plist`<br>`ViAnh.entitlements`<br>`ViAnhApp.swift`<br>`AuthService.swift`<br>`AuthWelcomeView.swift`<br>`DataPrivacyView.swift` |
| **ĐỢT 9** | **AVATAR NGƯỜI DÙNG TỪ THƯ VIỆN, CROP VIEW TRÒN, QUẢN LÝ THEO UID VÀ BRANDING GOOGLE CLOUD**<br>1. **Avatar thông minh (`UserAvatarView`)**:<br>- Hiển thị avatar tròn ở header Trang chủ (`DashboardHeaderView`) và Hồ sơ (`SettingsView`).<br>- Fallback chữ cái đầu tên trên nền pastel tương phản cao, tự động thích ứng Dark/Light Mode.<br>- Menu hành động ngữ cảnh (Xem ảnh, Đổi ảnh, Xóa ảnh) chỉ hiển thị các thao tác hợp lệ.<br>2. **Bộ cắt ảnh đại diện (`AvatarCropView`)**:<br>- Hỗ trợ di chuyển (drag) và phóng to/thu nhỏ (pinch-to-zoom 1x–4x) trong khung xem trước hình tròn.<br>- Xử lý chuẩn hóa hướng (`UIImage.normalized()`), downsampling về 512x512 và nén JPEG 0.85 ngoài luồng giao diện (`Task.detached`).<br>- Hủy chọn/hủy crop giữ nguyên ảnh cũ.<br>3. **Lưu trữ & Phân tách theo tài khoản (`ProfileAvatarService`)**:<br>- Lưu tệp cục bộ theo Firebase UID (`avatar_firebase_<uid>.jpg`), đảm bảo đổi tài khoản hiển thị đúng ảnh.<br>- Tự động nạp photoURL từ tài khoản Google làm ảnh mặc định nếu chưa tự chọn ảnh.<br>- Đồng bộ reactive tức thì trên mọi màn hình khi đổi hoặc xóa ảnh.<br>4. **Google Cloud Branding & Xác minh thương hiệu**:<br>- Xác minh Client ID thuộc đúng dự án `snapspend-36c3c` (Project Number 509543339422).<br>- Hướng dẫn chi tiết cấu hình Google Auth Platform → Branding để đổi tên hiển thị sang `SnapSpend`. | ✅ **HOÀN THÀNH** | `ProfileAvatarService.swift`<br>`UserAvatarView.swift`<br>`AvatarCropView.swift`<br>`DashboardHeaderView.swift`<br>`SettingsView.swift`<br>`AuthService.swift` |

---

## 3. CÁC ĐIỂM LƯU Ý KHI TEST TRÊN IPHONE THẬT

1. **Sign in with Apple**:
   - Chạy trên thiết bị thật có đăng nhập iCloud: Chạm vào nút Apple, Face ID / Touch ID sẽ mở ra và đăng nhập ngay lập tức.
2. **Google Sign-In**:
   - Chạm vào nút **Tiếp tục với Google**, hệ thống mở Safari an toàn với tài khoản Google. Sau khi chọn tài khoản và bấm Cho phép, Safari tự động đóng lại và app hoàn tất đăng nhập Firebase.
3. **Đăng xuất & Thử luồng khác**:
   - Vào Cài đặt → xem thông tin tài khoản → bấm **Đăng xuất** → xác nhận → màn hình Welcome mở ra để thử phương thức tiếp theo.
