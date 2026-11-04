# Yêu cầu dự án: Tiếp tục hoàn thiện Ví Ảnh theo thiết kế SnapSpend

## Mục tiêu
Phát triển ứng dụng iOS SnapSpend (hiện tại trong codebase Ví Ảnh / ViAnh), quản lý thu chi bằng hình ảnh trên iPhone:
- Mở app → bấm + → chụp ảnh → nhập nhanh số tiền → lưu bằng một tay trong vòng 3 giây.
- Hỗ trợ lưu không kèm ảnh khi từ chối camera.
- Giữ tên ứng dụng, bundle identifier (`com.gianghuy.snapspend`), cấu hình ký và dữ liệu người dùng hiện tại.

## Phong cách chủ đạo (UI/UX Pro Max)
- Nền Warm Cream `#FAF6F0`, thẻ trắng bo góc 20–24 pt, bóng nhẹ.
- Số tiền dùng font hệ thống với `.rounded`.
- Xanh lá đậm cho hành động chính.
- Khoản chi dùng hồng đỏ và ↗; khoản thu dùng xanh lá và ↙.
- Animation `.spring(response: 0.35, dampingFraction: 0.8)` và `sensoryFeedback` nhẹ. Tôn trọng Reduce Motion.
- Vùng chạm tối thiểu 44 × 44 pt, thao tác một tay.

## Lộ trình 6 giai đoạn
- Giai đoạn 1 — Nền tảng dữ liệu, định dạng tiền và thanh điều hướng (iOS 17.0+, schema Transaction/Category/Wallet/Budget, ThemeManager, Floating dock 5 vị trí).
- Giai đoạn 2 — Trang chủ và Lịch Ảnh Kỷ Niệm.
- Giai đoạn 3 — Camera và nhập tiền trên ảnh.
- Giai đoạn 4 — Thống kê Ngày / Tháng / Năm.
- Giai đoạn 5 — Đa ngân sách và cảnh báo.
- Giai đoạn 6 — Tài khoản, kiểm thử và chuẩn bị phát hành.

Hiện tại chỉ tập trung triển khai: **GIAI ĐOẠN 1**.

