# Cách sử dụng gói tài liệu SnapSpend

## 1. Các file trong gói

| File | Thao tác trong repository |
| --- | --- |
| README.md | Thay README cũ sau khi kiểm tra diff |
| TESTING.md | Thay bản cũ đang công bố 45 TC/30 XCTest không thống nhất |
| PROGRESS.md | Thay bản bàn giao, hoặc lưu bản cũ vào lịch sử trước khi hợp nhất |
| Docs/TECHNICAL_REPORT.md | Thêm báo cáo kỹ thuật mới |
| Docs/PUBLISHING_GUIDE.md | Hướng dẫn này; có thể giữ trong Docs |

Đây là bản tài liệu được tạo từ file cung cấp. Nếu repository đã thay đổi sau thời điểm gửi file, hợp nhất nội dung mới thay vì ghi đè mù. Giữ nguyên source, Bundle ID, signing và dữ liệu. Không cần thay hoặc thêm requirements/skills từ gói này.

## 2. Những chỗ cần xác nhận trước khi public

- Tên tác giả: Minh Huy, cách viết đầy đủ và người cùng đóng góp nếu có. Tên tài khoản Developer không mặc định là tác giả.
- Đường dẫn project, test file và scheme sau khi sắp xếp thư mục.
- Phiên bản macOS, Xcode, SDK và Simulator đúng output thực tế.
- 10 tests có trong target, gọi production code và artifact chạy khớp commit.
- Kiểm tra ảnh/video không chứa dữ liệu cá nhân; chưa nhúng ảnh giả hay liên kết placeholder trong README.
- Chọn giấy phép sau khi kiểm tra quyền đối với source và asset.
- Không public token, private key, chứng chỉ ký hoặc dữ liệu tài khoản test.

Không cần đưa toàn bộ DerivedData/.xcarchive/.xcresult nặng lên Git. Có thể dùng CI artifacts hoặc báo cáo văn bản gọn gắn commit; rà soát dữ liệu nhạy cảm trong log trước khi chia sẻ.

## 3. Bằng chứng nên bổ sung

| Nội dung | Vị trí gợi ý |
| --- | --- |
| 4–6 ảnh màn hình thật | Docs/assets/ |
| Video demo ngắn | GitHub attachment hoặc URL video hợp lệ |
| Kết quả test/build có môi trường và commit | Docs/evidence/ |
| Biên bản test iPhone | TESTING.md hoặc Docs/evidence/ |
| Liên kết commit sửa lỗi | Case study trong báo cáo |

Video nên thể hiện tác vụ thực tế, dùng dữ liệu mẫu: tạo khoản chi, xem nhật ký, ngân sách và chuyển tài khoản. Không công bố số liệu tốc độ khi chỉ quay một thao tác được chuẩn bị sẵn.

## 4. Nội dung CV tham khảo

Các câu dưới đây chỉ dùng sau khi xác minh source và kết quả; điều chỉnh đúng phần việc cá nhân. Không mặc định dùng tất cả.

**SnapSpend — iOS Personal Project**  
SwiftUI · SwiftData · Swift Concurrency · Swift Testing

- Developed a photo-based expense tracking app with local persistence, budgeting, and a visual transaction journal.
- Implemented account-scoped data access and regression tests for expense filtering, monthly boundaries, budget states, and CSV export.
- Addressed orphaned image files when the active session changed during asynchronous saving.
- Reported test suite: 10 Swift Testing tests across 8 suites; verify and link the run before including this metric in a CV.

Nếu đã phân phối beta, bổ sung trạng thái TestFlight đúng thực tế. Chỉ ghi phát hành App Store khi có trang app công khai. Không dùng nhãn Senior, 100% coverage hoặc full compliance làm kết luận từ gói tài liệu này.

## 5. Yêu cầu có thể gửi Antigravity để đối chiếu trên Mac

```text
Đọc gói tài liệu SnapSpend_GitHub và source repository hiện tại.
Kiểm tra git status trước; không ghi đè thay đổi mới của tôi.
Đối chiếu các tên hàm, đường dẫn, công nghệ, số test và case study với code.
Chạy kiểm tra phiên bản Xcode/SDK, test và build Debug/Release nếu môi trường cho phép.
Xác minh test ảnh không sử dụng thư mục dữ liệu thật.
Bổ sung bằng chứng vào TESTING.md và PROGRESS.md theo kết quả thực sự.
Giữ các mục chưa xác minh, không chuyển sang PASS từ code inspection.
Hợp nhất README.md, TESTING.md, PROGRESS.md và hai file Docs vào repository.
Kiểm tra liên kết Markdown nội bộ, thông tin cá nhân, secret và giấy phép.
Báo diff, số test thực tế và mục còn cần tôi test trên iPhone.
Không thay signing/Bundle ID, không push hoặc phát hành.
```
