import SwiftUI
import PhotosUI

// MARK: - ImagePickerStep

struct ImagePickerStep: View {

    @Binding var selectedImage: UIImage?
    let onContinue: () -> Void

    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showCamera = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Preview khung ảnh polaroid
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
                    .frame(height: 280)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                    )

                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 56, weight: .light))
                            .foregroundStyle(Color.secondary)

                        Text("Chụp hoặc chọn ảnh món đồ/hóa đơn")
                            .font(.subheadline)
                            .foregroundStyle(Color.secondary)
                    }
                }
            }
            .padding(.horizontal)

            // Nút Chụp & Chọn từ thư viện
            HStack(spacing: 16) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button {
                        showCamera = true
                    } label: {
                        Label("Chụp ảnh", systemImage: "camera.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.brandGreen)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                let hasImage = selectedImage != nil
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label("Chọn từ thư viện", systemImage: "photo.on.rectangle")
                        .font(.headline)
                        .foregroundStyle(!hasImage ? .white : Color.brandGreen)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(!hasImage ? Color.brandGreen : Color.brandGreen.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal)

            Spacer()

            // Nút Tiếp tục / Bỏ qua
            Button(action: onContinue) {
                Text(selectedImage == nil ? "Bỏ qua, nhập số tiền →" : "Tiếp tục nhập số tiền →")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.secondary)
                    .padding()
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        self.selectedImage = uiImage
                        HapticManager.shared.selectionChanged()
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPickerView(selectedImage: $selectedImage)
        }
    }
}

// MARK: - CameraPickerView wrapper

struct CameraPickerView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView
        init(_ parent: CameraPickerView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

