import SwiftUI
import PhotosUI

// MARK: - AvatarCropView (Màn hình Di chuyển & Thu phóng Ảnh đại diện)

struct AvatarCropView: View {

    let originalImage: UIImage
    var onSave: (UIImage) -> Void
    var onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    // Trạng thái thu phóng và di chuyển
    @State private var currentScale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var currentOffset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    @State private var isProcessing: Bool = false

    private let cropSize: CGFloat = 280
    private let theme = ThemeManager.shared
    private let locManager = LocalizationManager.shared

    private var isVN: Bool {
        locManager.currentLanguage == .vietnamese
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 20) {
                    Spacer()

                    // Khung Crop hình ảnh
                    ZStack {
                        // Ảnh gốc được scale và di chuyển
                        Image(uiImage: originalImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: cropSize, height: cropSize)
                            .scaleEffect(currentScale)
                            .offset(currentOffset)
                            .gesture(
                                SimultaneousGesture(magnificationGesture, dragGesture)
                            )
                            .frame(width: cropSize, height: cropSize)
                            .clipped()

                        // Lớp phủ xem trước hình tròn
                        CircleCropOverlay(cropSize: cropSize)
                            .allowsHitTesting(false)
                    }
                    .frame(width: cropSize, height: cropSize)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: Color.black.opacity(0.6), radius: 20)

                    // Hướng dẫn tương tác
                    Text(isVN ? "Kéo để di chuyển • Chụm hai ngón để phóng to" : "Drag to reposition • Pinch to zoom")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color.white.opacity(0.8))
                        .padding(.top, 10)

                    Spacer()
                }
            }
            .navigationTitle(isVN ? "Cắt ảnh đại diện" : "Move & Scale")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.85), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(locManager.t("action_cancel")) {
                        onCancel()
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        cropAndSave()
                    } label: {
                        if isProcessing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text(locManager.t("action_save"))
                                .font(.body.weight(.bold))
                                .foregroundStyle(theme.primaryAction)
                        }
                    }
                    .disabled(isProcessing)
                }
            }
        }
    }

    // MARK: - Gestures

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let newScale = lastScale * value
                currentScale = min(max(newScale, 1.0), 4.0)
            }
            .onEnded { _ in
                lastScale = currentScale
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                currentOffset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = currentOffset
            }
    }

    // MARK: - Cắt ảnh thực tế

    private func cropAndSave() {
        isProcessing = true
        HapticManager.shared.selectionChanged()

        let scale = currentScale
        let offset = currentOffset
        let size = cropSize
        let image = originalImage

        Task.detached(priority: .userInitiated) {
            let cropped = renderCroppedImage(
                image: image,
                cropSize: size,
                scale: scale,
                offset: offset
            )

            await MainActor.run {
                self.isProcessing = false
                self.onSave(cropped)
                self.dismiss()
            }
        }
    }

    private func renderCroppedImage(
        image: UIImage,
        cropSize: CGFloat,
        scale: CGFloat,
        offset: CGSize
    ) -> UIImage {
        let normalized = image.normalized()
        let targetSize = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: targetSize)

        return renderer.image { _ in
            let factor = targetSize.width / cropSize

            // Tính tỷ lệ khung hình thực tế
            let imageAspect = normalized.size.width / normalized.size.height
            var drawWidth: CGFloat
            var drawHeight: CGFloat

            if imageAspect >= 1.0 {
                drawHeight = targetSize.height * scale
                drawWidth = drawHeight * imageAspect
            } else {
                drawWidth = targetSize.width * scale
                drawHeight = drawWidth / imageAspect
            }

            let originX = (targetSize.width - drawWidth) / 2.0 + (offset.width * factor)
            let originY = (targetSize.height - drawHeight) / 2.0 + (offset.height * factor)

            normalized.draw(in: CGRect(x: originX, y: originY, width: drawWidth, height: drawHeight))
        }
    }
}

// MARK: - CircleCropOverlay (Lớp phủ xem trước viền tròn)

private struct CircleCropOverlay: View {
    let cropSize: CGFloat

    var body: some View {
        ZStack {
            // Lớp phủ tối xung quanh vòng tròn
            Rectangle()
                .fill(Color.black.opacity(0.55))
                .mask {
                    Rectangle()
                        .overlay {
                            Circle()
                                .frame(width: cropSize, height: cropSize)
                                .blendMode(.destinationOut)
                        }
                }

            // Vòng tròn định vị sắc nét
            Circle()
                .stroke(Color.white.opacity(0.85), lineWidth: 2)
                .frame(width: cropSize, height: cropSize)
        }
    }
}

