import UIKit
import ImageIO

// MARK: - ImageStorageService

/// Quản lý lưu, tải, xóa ảnh vật lý trên đĩa
/// Lưu tại: Application Support/ViAnh/Images/ để tránh iCloud backup lãng phí
/// Dùng Image I/O downsampling để load thumbnail và ảnh gốc mà không bị OOM
actor ImageStorageService {

    static let shared = ImageStorageService()

    // Constants
    static let jpegQuality: CGFloat = 0.8
    static let thumbnailMaxPixelSize: CGFloat = 300
    static let thumbnailQuality: CGFloat = 0.6

    private let cache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let imagesDirectoryURL: URL

    /// URL thư mục đang lưu trữ ảnh (phục vụ kiểm tra đường dẫn hoặc debug)
    var directoryURL: URL { imagesDirectoryURL }

    init(customDirectoryURL: URL? = nil) {
        let dir: URL
        if let custom = customDirectoryURL {
            dir = custom
        } else {
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            dir = appSupport.appendingPathComponent("ViAnh/Images", isDirectory: true)
        }

        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            // Loại khỏi iCloud backup
            var url = dir
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try? url.setResourceValues(resourceValues)
        }
        self.imagesDirectoryURL = dir
    }

    // MARK: - Save

    /// Lưu ảnh gốc và tạo thumbnail, trả về (imageFileName, thumbnailFileName)
    func save(image: UIImage) throws -> (imageFileName: String, thumbnailFileName: String) {
        let baseId = UUID().uuidString
        let imageFileName = "img_\(baseId).jpg"
        let thumbFileName = "thumb_\(baseId).jpg"

        let imageURL = imagesDirectoryURL.appendingPathComponent(imageFileName)
        let thumbURL = imagesDirectoryURL.appendingPathComponent(thumbFileName)

        // 1. Lưu ảnh gốc JPEG
        guard let fullData = image.jpegData(compressionQuality: Self.jpegQuality) else {
            throw ImageStorageError.compressionFailed
        }
        try fullData.write(to: imageURL, options: .atomic)

        // 2. Tạo thumbnail bằng Image I/O downsampling
        if let thumbImage = Self.downsample(data: fullData, maxPixelSize: Self.thumbnailMaxPixelSize) {
            if let thumbData = thumbImage.jpegData(compressionQuality: Self.thumbnailQuality) {
                try thumbData.write(to: thumbURL, options: .atomic)
                cache.setObject(thumbImage, forKey: thumbFileName as NSString)
            }
        }

        return (imageFileName, thumbFileName)
    }

    // MARK: - Delete

    /// Xóa cả ảnh gốc và thumbnail khỏi đĩa và cache
    func delete(imageFileName: String?, thumbnailFileName: String?) {
        if let thumb = thumbnailFileName {
            cache.removeObject(forKey: thumb as NSString)
            let thumbURL = imagesDirectoryURL.appendingPathComponent(thumb)
            try? fileManager.removeItem(at: thumbURL)
        }
        if let img = imageFileName {
            let imgURL = imagesDirectoryURL.appendingPathComponent(img)
            try? fileManager.removeItem(at: imgURL)
        }
    }

    // MARK: - Load

    /// Tải thumbnail từ cache hoặc từ đĩa bằng downsampling
    func loadThumbnail(fileName: String) -> UIImage? {
        if let cached = cache.object(forKey: fileName as NSString) {
            return cached
        }

        let fileURL = imagesDirectoryURL.appendingPathComponent(fileName)
        guard fileManager.fileExists(atPath: fileURL.path),
              let image = Self.downsample(imageAt: fileURL, maxPixelSize: Self.thumbnailMaxPixelSize) else {
            return nil
        }

        cache.setObject(image, forKey: fileName as NSString)
        return image
    }

    /// Tải ảnh gốc (downsample theo kích thước màn hình thiết bị)
    func loadFullImage(fileName: String, maxPixelSize: CGFloat = 1200) -> UIImage? {
        let fileURL = imagesDirectoryURL.appendingPathComponent(fileName)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        return Self.downsample(imageAt: fileURL, maxPixelSize: maxPixelSize)
    }

    // MARK: - Image I/O Downsampling

    private static func downsample(imageAt imageURL: URL, maxPixelSize: CGFloat) -> UIImage? {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, imageSourceOptions) else {
            return nil
        }
        return downsample(source: imageSource, maxPixelSize: maxPixelSize)
    }

    private static func downsample(data: Data, maxPixelSize: CGFloat) -> UIImage? {
        let imageSourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, imageSourceOptions) else {
            return nil
        }
        return downsample(source: imageSource, maxPixelSize: maxPixelSize)
    }

    private static func downsample(source imageSource: CGImageSource, maxPixelSize: CGFloat) -> UIImage? {
        let downsampleOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as [CFString : Any] as CFDictionary

        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, downsampleOptions) else {
            return nil
        }
        return UIImage(cgImage: downsampledImage)
    }
}

// MARK: - Errors

enum ImageStorageError: LocalizedError {
    case compressionFailed
    case fileNotFound

    var errorDescription: String? {
        switch self {
        case .compressionFailed: return "Không thể nén dữ liệu ảnh JPEG."
        case .fileNotFound: return "Không tìm thấy tệp ảnh trên đĩa."
        }
    }
}

