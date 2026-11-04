# SnapSpend — Kế Hoạch Kiểm Thử & Trạng Thái Bằng Chứng Thực Tế (TESTING.md)

> **Dự án:** SnapSpend (Tên hiển thị: SnapSpend, Bundle ID: `com.gianghuy.snapspend`)  
> **Nền tảng:** iOS 17.0+ | SwiftUI | SwiftData | Swift Concurrency | Swift Testing  
> **Codebase:** `ViAnh` | **Target test:** `SnapSpendTest` | **Test Plan:** `ViAnh.xctestplan`  
> **Cập nhật lần cuối:** 2026-11-04  
> **Trạng thái thực tế:** **10 / 10 Tests tự động PASSED** (0 failure) | **Debug & Release Build SUCCEEDED** | **Checklist kiểm thử thủ công sẵn sàng**  

---

## 1. NGUYÊN TẮC ĐÁNH GIÁ & PHÂN LOẠI TRẠNG THÁI

Nhằm đảm bảo tính trung thực kỹ thuật tuyệt đối cho hồ sơ năng lực và chuẩn bị phát hành App Store, tài liệu phân định rõ ràng giữa kết quả test tự động đã chạy thực tế và các kịch bản cần kiểm thử trên thiết bị vật lý:

| Ký Hiệu Trạng Thái | Ý Nghĩa Kỹ Thuật | Tiêu Chí Đánh Giá |
|:---:|---|---|
| 🟢 **AUTO_VERIFIED** | Đã kiểm thử tự động đạt (100%) | Test gọi trực tiếp code production thật, chạy và PASS trên iOS Simulator, có file `.xcresult` xác thực. |
| 🟡 **PARTIAL_VERIFIED** | Đã xác minh tự động một phần | Logic tính toán / helper đã pass test tự động, nhưng luồng giao diện tổng thể hoặc cache UI cần test thêm trên máy. |
| 🔵 **BUILD_VERIFIED** | Đã kiểm chứng qua đóng gói | Cấu hình plist, asset catalog và cấu trúc bundle đã được xác nhận qua lệnh build/archive. |
| 📱 **MANUAL_PENDING** | Chờ kiểm thử thủ công | Phụ thuộc phần cứng vật lý (ống kính camera, Face ID, Safari web sheet) hoặc thao tác cử chỉ người dùng. |

> **Cam kết chất lượng:** Không chuyển các mục chưa chạy sang trạng thái `PASS` chỉ dựa trên việc đọc mã nguồn (code inspection). Các mục phụ thuộc phần cứng được giữ nguyên ở trạng thái `MANUAL_PENDING` để người dùng thực hiện trên iPhone thật.

---

## 2. BẢNG MA TRẬN 45 KỊCH BẢN KIỂM THỬ (TC-01 ĐẾN TC-45)

| Mã TC | Phân Tầng | Tên Kịch Bản Kiểm Thử | Phương Thức Kiểm Tra | Trạng Thái Bằng Chứng | Ghi Chú & Bằng Chứng Thực Tế |
|:---:|:---:|---|:---:|:---:|---|
| **TC-01** | Core/Auth | Khởi động app khi đã có phiên lưu | Thủ công / UI | 📱 **MANUAL_PENDING** | Đã sửa logic `loadSession()`; cần kill app và mở lại trên iPhone thật. |
| **TC-02** | Core/Auth | Khởi động app lần đầu (Fresh Install) | Thủ công / UI | 📱 **MANUAL_PENDING** | Đã sửa hiển thị `AuthWelcomeView` toàn màn hình khi mới tải; cần test cài mới. |
| **TC-03** | Frontend/Media | Chọn ảnh thư viện → Crop 512x512 → Lưu | Thủ công / UI | 📱 **MANUAL_PENDING** | Thao tác cử chỉ Pinch/Zoom 1x-4x trên UI `AvatarCropView`. |
| **TC-04** | Backend/Media | Đóng app và mở lại sau khi lưu avatar | Thủ công / UI | 📱 **MANUAL_PENDING** | Xác minh tệp `avatar_<uid>.jpg` nạp từ Application Support sau khi khởi động lại. |
| **TC-05** | Security/Auth | Đổi tài khoản (User A sang User B) | Tự động một phần + UI | 🟡 **PARTIAL_VERIFIED** | `testProfileAvatarKeyIsolation()` pass; cần test luồng đổi tài khoản và cache trên UI thật. |
| **TC-06** | Backend/Media | Bấm Xóa ảnh đại diện | Thủ công / UI | 📱 **MANUAL_PENDING** | Xóa tệp vật lý, hoàn trả avatar ký tự đầu tên pastel. |
| **TC-07** | System/Support | Gửi ý kiến hỗ trợ tới `huytx3z3@gmail.com` | Thủ công / UI | 📱 **MANUAL_PENDING** | Mở Mail compose sheet hoặc URL scheme mailto:. |
| **TC-08** | Security/OAuth | Tham số Google OAuth PKCE S256 | Tự động một phần + UI | 🟡 **PARTIAL_VERIFIED** | `testPKCEAndNonceGenerators()` pass; cần test URL request và callback thật qua Safari. |
| **TC-09** | Data/Isolation | User A tạo khoản chi 35.000 ₫ | Test tự động SwiftData | 🟢 **AUTO_VERIFIED** | `testDataIsolationBetweenUsersAndZeroForNewUser()` pass (lọc đúng 35.000 ₫ của A). |
| **TC-10** | Data/Isolation | Đăng xuất A, đăng nhập B hoàn toàn mới | Tự động một phần + UI | 🟡 **PARTIAL_VERIFIED** | Query UID B trả về rỗng & tổng chi = 0 ₫; cần kiểm tra luồng đổi session trên UI thật. |
| **TC-11** | Data/Isolation | User B tạo khoản chi 50.000 ₫ | Test tự động SwiftData | 🟢 **AUTO_VERIFIED** | `testDataIsolationBetweenUsersAndZeroForNewUser()` pass (tổng chi B = 50.000 ₫). |
| **TC-12** | Data/Isolation | Đăng xuất B, đăng nhập lại User A | Tự động một phần + UI | 🟡 **PARTIAL_VERIFIED** | Tổng chi A độc lập; cần kiểm tra khôi phục phiên khi chuyển đổi lại trên app thật. |
| **TC-13** | Data/Isolation | Đăng nhập lại User B | Tự động một phần + UI | 🟡 **PARTIAL_VERIFIED** | Dữ liệu B độc lập; cần kiểm tra khôi phục phiên khi chuyển đổi lại trên app thật. |
| **TC-14** | Security/Race | Hủy lưu ảnh nền khi đổi tài khoản nhanh | Thủ công + Code fix | 📱 **MANUAL_PENDING** | Đã bổ sung xóa file mồ côi trong `ExpenseCaptureView`; cần test thao tác nhanh trên máy. |
| **TC-15** | Data/Migration | Bảo toàn dữ liệu cũ chưa có `ownerUID` | Test tự động SwiftData | 🟢 **AUTO_VERIFIED** | `testLegacyDataMigrationPreservation()` pass (gán an toàn, không rò rỉ sang user mới). |
| **TC-16** | App Store | Đóng gói AppIcon iPhone 120x120 PNG | Build / Asset Catalog | 🔵 **BUILD_VERIFIED** | File `AppIcon60x60@2x.png` (120x120, không alpha) đã nằm trong payload. |
| **TC-17** | App Store | `CFBundleIconName = AppIcon` trong Info.plist | Build / Info.plist | 🔵 **BUILD_VERIFIED** | Đã cấu hình và kiểm chứng qua lệnh build Debug & Release. |
| **TC-18** | Frontend/Input | Gợi ý chip VND thông minh (SmartVNDChips) | Thủ công / UI | 📱 **MANUAL_PENDING** | Gõ 35 hiển thị gợi ý 35k, 350k, 3.5tr trên bàn phím số. |
| **TC-19** | Frontend/Input | Nút cộng dồn ngân sách +500k, +1M, +2M | Thủ công / UI | 📱 **MANUAL_PENDING** | Giao diện `BudgetSetupView` cộng dồn lũy tiến mượt mà. |
| **TC-20** | Frontend/Input | Ca biên nhập liệu 0 ₫ và số âm | Thủ công / UI | 📱 **MANUAL_PENDING** | Nút Lưu bị disabled khi `currentAmountVND <= 0`. |
| **TC-21** | Frontend/Input | Giới hạn tối đa tránh tràn số Int64 | Thủ công / UI | 📱 **MANUAL_PENDING** | Bàn phím chặn tối đa 11 chữ số, chống tràn > 999 tỷ đồng. |
| **TC-22** | Frontend/Input | Chống bấm đúp nút Lưu (Double-tap) | Thủ công / UI | 📱 **MANUAL_PENDING** | Cờ `isSaving` khóa tương tác ngay sau cú chạm đầu tiên. |
| **TC-23** | Frontend/Perm | Xử lý từ chối quyền truy cập Camera | Phụ thuộc phần cứng | 📱 **MANUAL_PENDING** | Hiển thị view thông báo lịch sự kèm nút mở Cài đặt iOS. |
| **TC-24** | Backend/Media | Nén ảnh nền JPEG quality 0.8 | Tự động một phần + UI | 🟡 **PARTIAL_VERIFIED** | `save(image:)` chạy trên actor nền trong thư mục test; cần đo dung lượng camera thật. |
| **TC-25** | Backend/Media | Chuẩn hóa hướng xoay EXIF camera | Phụ thuộc phần cứng | 📱 **MANUAL_PENDING** | Chụp thực tế các hướng Portrait/Landscape bằng camera iPhone. |
| **TC-26** | Backend/Media | Sinh thumbnail 300px Image I/O | Tự động một phần + UI | 🟡 **PARTIAL_VERIFIED** | Đã kiểm tra tệp `thumb_*.jpg` sinh ra trong thư mục test; cần đo RAM cuộn danh sách. |
| **TC-27** | Backend/Media | Dọn sạch file vật lý khi xóa khoản chi | Test tự động Local Storage | 🟢 **AUTO_VERIFIED** | `testTransactionCRUDAndPhysicalImageCleanup()` pass (xóa sạch cả ảnh gốc và thumbnail trong thư mục tạm). |
| **TC-28** | Backend/Memory| Giải phóng RAM khi nhận cảnh báo bộ nhớ | Thủ công / UI | 📱 **MANUAL_PENDING** | Giả lập Simulate Memory Warning để kiểm tra NSCache purge. |
| **TC-29** | Data/Model | Thao tác CRUD thực thể ExpenseItem | Test tự động SwiftData | 🟢 **AUTO_VERIFIED** | Thêm, sửa, gọi `markUpdated()`, xóa trên database in-memory đều pass. |
| **TC-30** | Data/Model | Tính toán 6 trạng thái ngân sách | Test tự động Business Logic | 🟢 **AUTO_VERIFIED** | `testBudgetStatusAllSixConditions()` pass toàn bộ 6 trạng thái (`notSet` → `overBudget`). |
| **TC-31** | Data/Model | Lọc ranh giới tháng chính xác (UTC+7) | Test tự động Business Logic | 🟢 **AUTO_VERIFIED** | `testTotalSpentBoundaryAndAccountFiltering()` pass 4 mốc ranh giới đầu/cuối tháng. |
| **TC-32** | Data/Model | Bảo vệ danh mục mặc định & danh mục riêng | Tự động một phần + UI | 🟡 **PARTIAL_VERIFIED** | Lọc danh mục theo `ownerUID` pass; cần kiểm tra khóa xóa danh mục mặc định trên UI. |
| **TC-33** | Data/Model | Tính số dư ví Wallet (VND) | Test tự động Business Logic | 🟢 **AUTO_VERIFIED** | `testEntityIsolationAndWalletBalance()` pass (`initialBalance + income - expense`). |
| **TC-34** | Data/Model | Tính chuỗi ngày Streaks chụp ảnh camera | Test tự động Business Logic | 🟢 **AUTO_VERIFIED** | `testStreakCalculationWithCameraPhotos()` pass (chỉ tính ảnh camera, bỏ qua ảnh thư viện). |
| **TC-35** | Data/Model | Nhóm dữ liệu theo tháng cho Analytics | Thủ công / UI | 📱 **MANUAL_PENDING** | Biểu đồ cột và nhóm danh mục render mượt mà trong tab Thống kê. |
| **TC-36** | API/CSV | Xuất CSV RFC 4180 có BOM UTF-8 `\u{FEFF}` | Test tự động Dịch vụ | 🟢 **AUTO_VERIFIED** | `testCSVExportSpecialCharactersAndAccountIsolation()` pass 3 bytes `0xEF, 0xBB, 0xBF`. |
| **TC-37** | API/CSV | Escape ký tự đặc biệt (phẩy, ngoặc, dòng) | Test tự động Dịch vụ | 🟢 **AUTO_VERIFIED** | Ký tự `,`, `"`, `\n` được bọc và escape kép chuẩn RFC 4180. |
| **TC-38** | API/Network | Cập nhật tỷ giá & Offline Fallback | Thủ công / UI | 📱 **MANUAL_PENDING** | Bật Airplane Mode để kiểm tra fallback tỷ giá lưu cục bộ. |
| **TC-39** | API/Currency| Quy đổi tiền tệ VND / USD / EUR | Thủ công / UI | 📱 **MANUAL_PENDING** | Thay đổi đơn vị hiển thị trong Cài đặt và kiểm tra tỷ giá tương ứng. |
| **TC-40** | API/Notify | Cảnh báo ngân sách 80%/100% & Nhắc 20h | Thủ công / UI | 📱 **MANUAL_PENDING** | Cho phép nhận Local Notification và kích hoạt ngưỡng chi tiêu. |
| **TC-41** | Security/Apple| Sign in with Apple SHA-256 Nonce | Tự động một phần + UI | 🟡 **PARTIAL_VERIFIED** | `testPKCEAndNonceGenerators()` pass sinh nonce 32/64 ký tự và băm SHA-256; cần test Face ID thật. |
| **TC-42** | Security/Apple| Xóa vĩnh viễn tài khoản trong app | Thủ công / UI | 📱 **MANUAL_PENDING** | Bấm Xóa tài khoản xóa sạch SwiftData và local files theo Guideline 5.1.1(v). |
| **TC-43** | Security/Token| Session Token Invalidation | Tự động một phần + UI | 🟡 **PARTIAL_VERIFIED** | Đã gắn token check và cleanup trong `ExpenseCaptureView`; cần test đổi tài khoản lúc đang lưu trên máy. |
| **TC-44** | Security/OAuth| Google PKCE Code Challenge S256 | Tự động một phần + UI | 🟡 **PARTIAL_VERIFIED** | `testPKCEAndNonceGenerators()` pass sinh URL-safe challenge không chứa `+`, `/`, `=`. |
| **TC-45** | App Store | Khai báo quyền Camera, Photos trong Info | Build / Info.plist | 🔵 **BUILD_VERIFIED** | `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription` đầy đủ trong Info.plist. |

---

## 3. DANH SÁCH 10 TEST SWIFT TESTING ĐÃ CHẠY THÀNH CÔNG

Tệp kiểm thử nằm tại: `ViAnh/SnapSpendTest/SnapSpendTest.swift`.

```swift
// Toàn bộ 10 bài test sử dụng framework Swift Testing (@Suite, @Test, #expect)
// Database in-memory riêng biệt: ModelConfiguration(isStoredInMemoryOnly: true)
// Thư mục lưu ảnh tạm riêng biệt: FileManager.default.temporaryDirectory / defer dọn dẹp
```

| STT | Test Suite | Test Method | Kết Quả Thực Tế | Thời Gian |
|:---:|---|---|:---:|:---:|
| 1 | `MonthlyExpenseCalculationTests` | `testTotalSpentBoundaryAndAccountFiltering()` | 🟢 **PASSED** | < 0.01s |
| 2 | `DataIsolationTests` | `testDataIsolationBetweenUsersAndZeroForNewUser()` | 🟢 **PASSED** | < 0.01s |
| 3 | `BudgetStatusCalculationTests` | `testBudgetStatusAllSixConditions()` | 🟢 **PASSED** | < 0.01s |
| 4 | `CSVExportTests` | `testCSVExportSpecialCharactersAndAccountIsolation()` | 🟢 **PASSED** | < 0.01s |
| 5 | `TransactionLifecycleAndImageStorageTests` | `testTransactionCRUDAndPhysicalImageCleanup()` | 🟢 **PASSED** | < 0.01s |
| 6 | `EntityIsolationAndWalletTests` | `testEntityIsolationAndWalletBalance()` | 🟢 **PASSED** | < 0.01s |
| 7 | `StreakCalculationTests` | `testStreakCalculationWithCameraPhotos()` | 🟢 **PASSED** | < 0.01s |
| 8 | `SecurityAndDataPreservationTests` | `testPKCEAndNonceGenerators()` | 🟢 **PASSED** | < 0.01s |
| 9 | `SecurityAndDataPreservationTests` | `testProfileAvatarKeyIsolation()` | 🟢 **PASSED** | < 0.01s |
| 10 | `SecurityAndDataPreservationTests` | `testLegacyDataMigrationPreservation()` | 🟢 **PASSED** | < 0.01s |

---

## 4. BẰNG CHỨNG THỰC THI & MÔI TRƯỜNG BUILD / TEST

Các kết quả dưới đây được đo lường và xác thực trực tiếp trên hệ thống:

```text
============================================================
XCODE & SDK VERIFICATION:
$ xcodebuild -version
Xcode 26.3
Build version 17C529

$ xcodebuild -showsdks
iOS SDK: iOS 26.2 (-sdk iphoneos26.2)
iOS Simulator SDK: Simulator - iOS 26.2 (-sdk iphonesimulator26.2)
============================================================
EXECUTION LOG SUMMARY:
Command: xcodebuild test -scheme ViAnh -destination "id=71D6973E-BE01-4388-AABA-BA513BC6B407" -testPlan ViAnh
Device: Clone 1 of iPhone 16e - ViAnh (71D6973E-BE01-4388-AABA-BA513BC6B407)
Result: ** TEST SUCCEEDED ** (10 tests executed, 10 passed, 0 failed)
Result Bundle: /Users/minhhuy/Library/Developer/Xcode/DerivedData/ViAnh-gpmkaujmqkdczjhkvdshhutpdujq/Logs/Test/Test-ViAnh-2026.11.04_13-16-06-+0700.xcresult

BUILD VERIFICATION:
Debug Build:   xcodebuild build -configuration Debug   --> ** BUILD SUCCEEDED **
Release Build: xcodebuild build -configuration Release --> ** BUILD SUCCEEDED **
============================================================
```

### Xác Minh An Toàn Dữ Liệu Trong Test Ảnh
- `ImageStorageService` đã được bổ sung `init(customDirectoryURL: URL? = nil)` và thuộc tính `directoryURL`.
- Trong `testTransactionCRUDAndPhysicalImageCleanup()`, test tạo một thư mục tạm riêng biệt:
  ```swift
  let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("SnapSpendTest_Images_\(UUID().uuidString)")
  let isolatedStorage = ImageStorageService(customDirectoryURL: tempDir)
  defer { try? FileManager.default.removeItem(at: tempDir) }
  ```
- **Xác nhận:** Quá trình chạy test **hoàn toàn không ghi hoặc xóa tệp nào** trong thư mục người dùng thật (`Application Support/ViAnh/Images/`). Toàn bộ file thử nghiệm được tự động dọn sạch khi test kết thúc.

---

## 5. CHECKLIST KIỂM THỬ THỦ CÔNG TRÊN IPHONE THẬT CHO NGƯỜI DÙNG

Các kịch bản sau yêu cầu người dùng mở ứng dụng và thao tác trực tiếp trên iPhone vật lý:

### A. Khởi Động & Xác Thực
- [ ] **Màn hình Chào mừng (Cài mới):** Xóa app cài lại (hoặc test trên máy mới) → App dừng ở màn hình Chào mừng / Đăng nhập (`AuthWelcomeView`), không nhảy thẳng vào Dashboard.
- [ ] **Khách (Guest):** Bấm "Dùng thử không đăng nhập" → Vào Dashboard, avatar hiển thị ký tự Khách trên nền màu pastel.
- [ ] **Sign in with Apple:** Bấm "Tiếp tục với Apple" → Face ID / Touch ID hiện lên → Đăng nhập thành công, nạp đúng tên tài khoản Apple.
- [ ] **Google Sign-In:** Bấm "Tiếp tục với Google" → Safari sheet hiện ra → Chọn tài khoản Google → Callback quay lại app, nạp tên và avatar Google.
- [ ] **Khôi phục phiên:** Đóng hẳn app (kill app) từ App Switcher → Mở lại → Đăng nhập giữ nguyên, không bị văng.

### B. Cô Lập Dữ Liệu Đa Tài Khoản
- [ ] **User A:** Đăng nhập A → Tạo chi 35.000 ₫, thêm 1 danh mục tùy chỉnh, lưu avatar riêng.
- [ ] **User B:** Đăng xuất A → Đăng nhập B mới → Kiểm tra Dashboard hiển thị tổng chi = 0 ₫, không thấy danh mục tùy chỉnh của A, tạo chi 50.000 ₫ và avatar khác.
- [ ] **Quay lại User A:** Đăng xuất B → Đăng nhập lại A → Tổng chi A vẫn đúng 35.000 ₫, danh mục riêng của A hiển thị đầy đủ, không bị lẫn 50.000 ₫ của B.
- [ ] **Đổi tài khoản lúc đang lưu:** Chụp ảnh hóa đơn → Bấm Lưu → Lập tức chuyển sang Cài đặt đổi tài khoản → Kiểm tra tài khoản mới không nhận giao dịch của tài khoản cũ.

### C. Camera & Nhập Liệu
- [ ] **Cấp quyền Camera:** Xóa app cài lại → Bấm `[+]` → Chọn "Cho phép" → Camera hiển thị ngay lập tức.
- [ ] **Từ chối quyền Camera:** Cài lại app → Chọn "Từ chối" quyền Camera → App hiển thị view thông báo lịch sự kèm nút mở Cài đặt iOS, vẫn cho phép nhập chi tiêu không kèm ảnh.
- [ ] **Chuyển góc chụp 0.5x:** Thử nút chuyển 0.5x Ultra Wide trên camera sau.
- [ ] **Smart VND Chips:** Nhập "45" → Chạm chip "45.000 ₫" → Tiền được điền ngay.

### D. Avatar & Xóa Tài Khoản
- [ ] **Cắt ảnh tròn (`AvatarCropView`):** Vào Cài đặt → Chạm avatar → Chọn ảnh từ thư viện → Dùng 2 ngón tay pinch zoom và kéo di chuyển ảnh → Bấm Lưu → Avatar tròn cập nhật ở Header Dashboard và Cài đặt.
- [ ] **Xóa ảnh đại diện:** Nhấn giữ avatar → Chọn "Xóa ảnh đại diện" → Quay lại chữ cái đầu tên.
- [ ] **Xóa vĩnh viễn tài khoản (Guideline 5.1.1(v)):** Vào Cài đặt → Bấm "Xóa tài khoản" → Hộp thoại xác nhận đỏ → Đồng ý → Toàn bộ giao dịch, ngân sách và ảnh cục bộ bị xóa sạch; app quay về màn hình Chào mừng ban đầu.
