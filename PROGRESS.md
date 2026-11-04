# SnapSpend — Tiến Độ & Nhật Ký Bàn Giao (PROGRESS.md)

> **Dự án:** SnapSpend (Tên hiển thị: SnapSpend, Bundle ID: `com.gianghuy.snapspend`)  
> **Nền tảng:** iOS 17.0+ | SwiftUI | SwiftData | Swift Concurrency | Swift Testing  
> **Cập nhật lần cuối:** 2026-11-04 13:20  
> **Trạng thái thực tế:** Đã hoàn thành Giai đoạn 1 (Kiểm tra chất lượng & Sửa lỗi); sẵn sàng cho kiểm thử thủ công trên iPhone.

---

## 1. PHẠM VI LẦN CẬP NHẬT NÀY

Lần cập nhật này thực hiện các công việc kiểm tra chất lượng, sửa lỗi và đồng bộ tài liệu từ gói `SnapSpend_GitHub`:
1. **Kiểm tra môi trường & công cụ thực tế:**
   - Xác minh chính xác phiên bản công cụ: **Xcode 26.3 (Build 17C529)**, SDK **iOS 26.2** (`iphoneos26.2`, `iphonesimulator26.2`).
   - Cả 2 cấu hình **Debug** và **Release** đều được biên dịch và đóng gói thành công (`** BUILD SUCCEEDED **`).
2. **Sửa 2 lỗi logic phát hiện trong mã nguồn:**
   - *Lỗi tệp ảnh mồ côi (`ExpenseCaptureView.swift`):* Bổ sung tác vụ gọi `ImageStorageService.shared.delete(imageFileName:thumbnailFileName:)` khi guard session token hoặc owner UID thay đổi, đảm bảo không bỏ rơi file ảnh tạm trong sandbox.
   - *Lỗi tự động đăng nhập khách (`AuthService.swift` & `ContentView.swift`):* Sửa `loadSession()` giữ `currentUser = nil` khi chưa có session, kích hoạt màn hình Chào mừng / Đăng nhập (`AuthWelcomeView`) toàn màn hình khi người dùng mở app lần đầu.
3. **Cô lập thư mục lưu trữ ảnh trong Unit Test:**
   - Bổ sung `init(customDirectoryURL: URL? = nil)` cho actor `ImageStorageService`.
   - Trong `SnapSpendTest.swift`, bài test CRUD và dọn dẹp ảnh sử dụng thư mục tạm riêng biệt (`FileManager.default.temporaryDirectory`), đảm bảo **100% không đụng chạm đến thư mục dữ liệu thật (`Application Support/ViAnh/Images/`)** của người dùng.
4. **Hợp nhất gói tài liệu vào repository:**
   - Bổ sung [Báo cáo Kỹ thuật (Docs/TECHNICAL_REPORT.md)](Docs/TECHNICAL_REPORT.md) và [Hướng dẫn Xuất bản (Docs/PUBLISHING_GUIDE.md)](Docs/PUBLISHING_GUIDE.md).
   - Chuẩn hóa [README.md](README.md), [TESTING.md](TESTING.md), [PROGRESS.md](PROGRESS.md) theo giọng văn khách quan, trung thực, loại bỏ các tuyên bố thổi phồng ("bảo mật tuyệt đối", "100% coverage").

---

## 2. BẢNG TỔNG HỢP TRẠNG THÁI THEO BẰNG CHỨNG THỰC TẾ

| Hạng mục | Trạng thái Thực tế | Chi tiết Bằng chứng |
|---|:---:|---|
| **Bộ test Swift Testing** | ✅ **10 / 10 Tests PASSED** | 8 suites độc lập, 0 failure, thời gian chạy ~32.9s trên Simulator |
| **Build Debug** | ✅ **BUILD SUCCEEDED** | Biên dịch sạch 0 lỗi |
| **Build Release** | ✅ **BUILD SUCCEEDED** | Biên dịch tối ưu hóa (-O) sạch 0 lỗi |
| **An toàn thư mục Test Ảnh** | ✅ **ĐÃ XÁC MINH** | Dùng thư mục tạm riêng, dọn sạch qua `defer` |
| **Ma trận 45 kịch bản (TC)** | 📊 **Đã chuẩn hóa** | 10 Auto Verified, 11 Partial Verified, 3 Build Verified, 21 Manual Pending |
| **TestFlight** | 📦 **Bản 1.0.0 (1)** | Đã từng được đóng gói và tải lên theo lịch sử dự án |
| **Phát hành App Store** | ⏳ **Chưa phát hành** | Đang chuẩn bị hoàn tất kiểm thử thủ công và tài liệu metadata |
| **Kiểm thử trên iPhone thật** | 📱 **Chờ thực hiện** | Checklist 16 hạng mục sẵn sàng tại Mục 5 của [TESTING.md](TESTING.md) |

---

## 3. KẾT QUẢ TEST RUN THỰC TẾ (10 TESTS)

```text
Test Plan: ViAnh.xctestplan | Scheme: ViAnh | Destination: Clone 1 of iPhone 16e - ViAnh (71D6973E-BE01-4388-AABA-BA513BC6B407)
Result: ** TEST SUCCEEDED ** (10/10 passed)
Result Bundle Path: /Users/minhhuy/Library/Developer/Xcode/DerivedData/ViAnh-gpmkaujmqkdczjhkvdshhutpdujq/Logs/Test/Test-ViAnh-2026.11.04_13-16-06-+0700.xcresult
```

1. `MonthlyExpenseCalculationTests/testTotalSpentBoundaryAndAccountFiltering()` — 🟢 PASSED
2. `DataIsolationTests/testDataIsolationBetweenUsersAndZeroForNewUser()` — 🟢 PASSED
3. `BudgetStatusCalculationTests/testBudgetStatusAllSixConditions()` — 🟢 PASSED
4. `CSVExportTests/testCSVExportSpecialCharactersAndAccountIsolation()` — 🟢 PASSED
5. `TransactionLifecycleAndImageStorageTests/testTransactionCRUDAndPhysicalImageCleanup()` — 🟢 PASSED
6. `EntityIsolationAndWalletTests/testEntityIsolationAndWalletBalance()` — 🟢 PASSED
7. `StreakCalculationTests/testStreakCalculationWithCameraPhotos()` — 🟢 PASSED
8. `SecurityAndDataPreservationTests/testPKCEAndNonceGenerators()` — 🟢 PASSED
9. `SecurityAndDataPreservationTests/testProfileAvatarKeyIsolation()` — 🟢 PASSED
10. `SecurityAndDataPreservationTests/testLegacyDataMigrationPreservation()` — 🟢 PASSED

---

## 4. CÁC TÀI LIỆU ĐÃ HỢP NHẤT TRONG REPOSITORY

- **`README.md`**: Giới thiệu dự án, công nghệ, kiến trúc trách nhiệm, hướng dẫn cài đặt và kết quả kiểm thử trung thực.
- **`TESTING.md`**: Ma trận 45 kịch bản phân loại chi tiết (Auto, Partial, Build, Manual), danh sách 10 test Swift Testing, bằng chứng thực thi và checklist kiểm thử iPhone.
- **`PROGRESS.md`**: Nhật ký bàn giao, phạm vi nâng cấp và theo dõi trạng thái bằng chứng.
- **`Docs/TECHNICAL_REPORT.md`**: Báo cáo kỹ thuật chuyên sâu, phân tích trách nhiệm dữ liệu và 3 case study trọng tâm (đa tài khoản, ảnh mồ côi, khởi động khách).
- **`Docs/PUBLISHING_GUIDE.md`**: Hướng dẫn sử dụng gói tài liệu, rà soát thông tin cá nhân/secret và gợi ý viết CV.

---

## 5. CÔNG VIỆC TIẾP THEO

1. **Người dùng thực hiện Checklist kiểm thử trên iPhone thật:**
   - Kiểm tra cấp/từ chối quyền Camera và chụp góc rộng 0.5x.
   - Thử nghiệm Sign in with Apple (Face ID) và Google Sign-in thật qua Safari sheet.
   - Thử nghiệm cắt avatar (`AvatarCropView`) và xóa avatar.
   - Thử nghiệm tính năng "Xóa tài khoản" theo App Store Guideline 5.1.1(v).
2. **Chuẩn bị hồ sơ Giai đoạn 2 (Metadata & Assets App Store):**
   - Chụp 4–6 ảnh màn hình thật từ iPhone (cỡ 6.7" và 6.5") dùng dữ liệu mẫu.
   - Hoàn thiện mô tả ứng dụng, từ khóa tìm kiếm (Keywords) và URL hỗ trợ/chính sách quyền riêng tư.
   - Đóng gói bản `.xcarchive` chính thức để sẵn sàng gửi duyệt.
