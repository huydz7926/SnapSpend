import SwiftUI
import PhotosUI
import AVFoundation

// MARK: - AddExpenseView (SnapSpend Locket Camera & Capture Flow)

struct AddExpenseView: View {

    var initialDate: Date = Date.now

    @Environment(\.dismiss) private var dismiss
    @StateObject private var cameraService = CameraService()

    @State private var capturedImage: UIImage? = nil
    @State private var isFromLibrary: Bool = false
    @State private var hasSelectedOrCaptured = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil

    private let theme = ThemeManager.shared

    var body: some View {
        ZStack {
            // Nền ấm chuẩn SnapSpend (theo mẫu ảnh 2)
            theme.background.ignoresSafeArea()

            if hasSelectedOrCaptured {
                // Màn hình 2: Giữ ảnh vừa chụp + Nhập tiền (bàn phím hệ thống) + Caption (theo mẫu ảnh 1)
                ExpenseCaptureView(
                    capturedImage: capturedImage,
                    isFromLibrary: isFromLibrary,
                    initialDate: initialDate,
                    onRetake: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            capturedImage = nil
                            isFromLibrary = false
                            hasSelectedOrCaptured = false
                        }
                        cameraService.startSession()
                    },
                    onDismiss: {
                        dismiss()
                    },
                    onSaveSuccess: {
                        dismiss()
                    }
                )
                .transition(.asymmetric(insertion: .opacity.combined(with: .scale(scale: 0.98)),
                                        removal: .opacity))
            } else {
                // Màn hình 1: Khung chụp bo góc vừa vặn (theo mẫu ảnh 2)
                locketCameraView
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: hasSelectedOrCaptured)
        .onAppear {
            cameraService.startSession()
        }
        .onDisappear {
            cameraService.stopSession()
        }
        .onChange(of: cameraService.capturedImage) { _, newImage in
            if let img = newImage {
                self.capturedImage = img
                self.isFromLibrary = false
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    self.hasSelectedOrCaptured = true
                }
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        self.capturedImage = CameraService.cropToSquare(image: image)
                        self.isFromLibrary = true
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            self.hasSelectedOrCaptured = true
                        }
                    }
                }
            }
        }
    }

    // MARK: - Locket Camera View (Khung Camera Đưa Lên Cao Sát Nút Hủy & Safe Area)

    private var locketCameraView: some View {
        GeometryReader { geo in
            let horizontalMargin: CGFloat = 16
            let camWidth = geo.size.width - (horizontalMargin * 2)
            // Tính chiều cao khả dụng để nút chụp và thư viện luôn vừa vặn trên mọi kích cỡ màn hình
            let availableHeight = geo.size.height - 48 - 8 - 12 - 156
            let camHeight = max(280, min(camWidth * 1.06, availableHeight))

            VStack(spacing: 0) {
                // Top Bar: Nút Hủy dạng Pill trắng góc trên bên trái sát ngay safe area
                HStack {
                    Button {
                        HapticManager.shared.selectionChanged()
                        dismiss()
                    } label: {
                        Text("Hủy")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.black.opacity(0.8))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.white)
                            .clipShape(Capsule())
                            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    // Nút "Không ảnh"
                    Button {
                        capturedImage = nil
                        isFromLibrary = false
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            hasSelectedOrCaptured = true
                        }
                        HapticManager.shared.selectionChanged()
                    } label: {
                        Text(LocalizationManager.shared.currentLanguage == .vietnamese ? "Không ảnh" : "No photo")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(theme.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.8))
                            .clipShape(Capsule())
                            .shadow(color: Color.black.opacity(0.04), radius: 4, y: 1)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 8)

                // Khung Camera Locket đặt sát ngay dưới khu vực Hủy (Khoảng cách chỉ 6-8pt)
                ZStack(alignment: .bottom) {
                    if cameraService.isCameraAvailable {
                        CameraPreviewView(session: cameraService.session)
                            .frame(width: camWidth, height: camHeight)
                            .clipped()
                    } else {
                        cameraFallbackView
                            .frame(width: camWidth, height: camHeight)
                    }

                    // Các nút điều khiển đè trực tiếp lên hình ảnh trong preview
                    VStack {
                        // Góc trên: Flash (trái) & Lật camera (phải) - Vùng chạm tối thiểu 44x44pt
                        HStack {
                            // Nút Flash
                            Button {
                                cameraService.toggleFlash()
                                HapticManager.shared.selectionChanged()
                            } label: {
                                Image(systemName: flashIconName)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(
                                        cameraService.isFlashSupported
                                        ? (cameraService.flashMode == .on ? Color.yellow : Color.white)
                                        : Color.white.opacity(0.35)
                                    )
                                    .frame(width: 44, height: 44)
                                    .background(Color.black.opacity(0.45))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .disabled(!cameraService.isFlashSupported)

                            Spacer()

                            // Nút Lật Camera trước / sau
                            Button {
                                cameraService.flipCamera()
                                HapticManager.shared.selectionChanged()
                            } label: {
                                Image(systemName: "arrow.triangle.2.circlepath.camera")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(Color.white)
                                    .frame(width: 44, height: 44)
                                    .background(Color.black.opacity(0.45))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(14)

                        Spacer()

                        // Pill Zoom (0.5x • 1x • 2x) nổi trên mép dưới khung camera
                        zoomSelectorPill
                            .padding(.bottom, 14)
                    }
                }
                .frame(width: camWidth, height: camHeight)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.08), radius: 10, y: 4)

                Spacer(minLength: 8)

                // Nút Chụp tròn màu trắng viền Gradient hồng tím (Ảnh 2)
                Button {
                    HapticManager.shared.savedExpense()
                    cameraService.capturePhoto()
                } label: {
                    ZStack {
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "#FF4D97") ?? .pink,
                                        Color(hex: "#BD34FE") ?? .purple
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 4.5
                            )
                            .frame(width: 74, height: 74)

                        Circle()
                            .fill(Color.white)
                            .frame(width: 63, height: 63)
                            .shadow(color: Color.black.opacity(0.12), radius: 6, y: 2)
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
                .padding(.bottom, 12)

                // Nút Pill "Chọn từ thư viện" (Ảnh 2)
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 14, weight: .semibold))
                        Text(LocalizationManager.shared.currentLanguage == .vietnamese ? "Chọn từ thư viện" : "Photo Library")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(Color(hex: "#A838E8") ?? .purple)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(Color(hex: "#F9EEFF") ?? Color.purple.opacity(0.1))
                    .clipShape(Capsule())
                    .shadow(color: Color.purple.opacity(0.08), radius: 6, y: 2)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 18)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Zoom Selector Pill (0.5x, 1x, 2x & Góc rộng)

    private var zoomSelectorPill: some View {
        HStack(spacing: 6) {
            ForEach(cameraService.availableZoomFactors, id: \.self) { factor in
                let isSelected = abs(cameraService.currentZoomFactor - factor) < 0.05
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        cameraService.setZoomFactor(factor)
                    }
                    HapticManager.shared.selectionChanged()
                } label: {
                    Text(zoomLabel(for: factor))
                        .font(.system(size: 12, weight: isSelected ? .heavy : .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.75))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(isSelected ? Color.black.opacity(0.6) : Color.clear)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.black.opacity(0.45))
        .clipShape(Capsule())
    }

    private func zoomLabel(for factor: CGFloat) -> String {
        if cameraService.currentPosition == .front {
            if factor < 1.0 {
                return LocalizationManager.shared.currentLanguage == .vietnamese ? "Góc rộng" : "Wide"
            } else {
                return "1x"
            }
        } else {
            if factor == 0.5 {
                return "0.5x"
            } else {
                return "\(Int(factor))x"
            }
        }
    }

    private var flashIconName: String {
        switch cameraService.flashMode {
        case .on:   return "bolt.fill"
        case .off:  return "bolt.slash.fill"
        case .auto: return "bolt.badge.automatic.fill"
        @unknown default: return "bolt.fill"
        }
    }

    private var cameraFallbackView: some View {
        ZStack {
            Color(hex: "#222222") ?? Color.gray
            VStack(spacing: 12) {
                Image(systemName: "camera.slash.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.white.opacity(0.7))
                Text(cameraService.authorizationStatus == .denied ? "Chưa cấp quyền Camera" : "Camera không khả dụng")
                    .font(.headline)
                    .foregroundStyle(Color.white)
                Text("Chọn ảnh từ Thư viện hoặc tiếp tục ghi chi tiêu mà không cần ảnh.")
                    .font(.footnote)
                    .foregroundStyle(Color.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
    }
}
