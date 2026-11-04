import SwiftUI

// MARK: - AsyncThumbnailView

/// Tải thumbnail bất đồng bộ từ disk cache qua ImageStorageService
/// Nếu không có ảnh hoặc lỗi, hiển thị category icon placeholder
struct AsyncThumbnailView: View {

    let fileName: String?
    var category: ExpenseCategory? = nil

    @State private var image: UIImage? = nil
    @State private var isLoading = false

    var body: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if isLoading {
                Color.secondary.opacity(0.1)
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                // Placeholder với icon danh mục hoặc icon ảnh mặc định
                ZStack {
                    (category?.color ?? Color.gray).opacity(0.15)
                    Image(systemName: category?.symbolName ?? "photo")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(category?.color ?? Color.secondary)
                }
            }
        }
        .task(id: fileName) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let fileName = fileName, !fileName.isEmpty else {
            image = nil
            return
        }

        isLoading = true
        let loaded = await ImageStorageService.shared.loadThumbnail(fileName: fileName)
        await MainActor.run {
            self.image = loaded
            self.isLoading = false
        }
    }
}
