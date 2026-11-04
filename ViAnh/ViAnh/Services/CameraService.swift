@preconcurrency import AVFoundation
import UIKit
import SwiftUI

// MARK: - CameraService

@MainActor
final class CameraService: NSObject, ObservableObject {

    @Published var isSessionRunning = false
    @Published var isCameraAvailable = false
    @Published var authorizationStatus: AVAuthorizationStatus = .notDetermined
    @Published var capturedImage: UIImage? = nil
    @Published var flashMode: AVCaptureDevice.FlashMode = .auto
    @Published var isFlashSupported: Bool = true
    @Published var currentPosition: AVCaptureDevice.Position = .back
    @Published var availableZoomFactors: [CGFloat] = [1.0]
    @Published var currentZoomFactor: CGFloat = 1.0

    nonisolated(unsafe) let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private nonisolated(unsafe) var videoDeviceInput: AVCaptureDeviceInput?
    private let sessionQueue = DispatchQueue(label: "com.gianghuy.snapspend.cameraSessionQueue")

    override init() {
        super.init()
        checkPermissions()
    }

    // MARK: - Permissions

    func checkPermissions() {
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        switch authorizationStatus {
        case .authorized:
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor [weak self] in
                    self?.authorizationStatus = granted ? .authorized : .denied
                    if granted {
                        self?.setupSession()
                    }
                }
            }
        default:
            isCameraAvailable = false
        }
    }

    // MARK: - Session Setup

    func setupSession() {
        guard authorizationStatus == .authorized else {
            isCameraAvailable = false
            return
        }

        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let device = selectDevice(for: currentPosition),
              let input = try? AVCaptureDeviceInput(device: device) else {
            session.commitConfiguration()
            isCameraAvailable = false
            return
        }

        if let oldInput = videoDeviceInput {
            session.removeInput(oldInput)
        }

        if session.canAddInput(input) {
            session.addInput(input)
            videoDeviceInput = input
            isCameraAvailable = true
        } else {
            session.commitConfiguration()
            isCameraAvailable = false
            return
        }

        if !session.outputs.contains(photoOutput) {
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)
                if #available(iOS 16.0, *) {
                    photoOutput.maxPhotoDimensions = CMVideoDimensions(width: 4032, height: 3024)
                } else {
                    photoOutput.isHighResolutionCaptureEnabled = true
                }
            }
        }

        configureCapabilities(for: device)
        session.commitConfiguration()

        let initialPhysicalZoom = physicalZoomFactor(for: currentZoomFactor, on: device)
        applyZoom(initialPhysicalZoom, on: device)

        startSession()
    }

    func startSession() {
        guard !session.isRunning, isCameraAvailable else { return }
        let session = self.session
        sessionQueue.async { [weak self] in
            session.startRunning()
            Task { @MainActor [weak self] in
                self?.isSessionRunning = true
            }
        }
    }

    func stopSession() {
        guard session.isRunning else { return }
        let session = self.session
        sessionQueue.async { [weak self] in
            session.stopRunning()
            Task { @MainActor [weak self] in
                self?.isSessionRunning = false
            }
        }
    }

    // MARK: - Device Selection (Hỗ trợ Triple Camera, Dual Wide và TrueDepth)

    private func selectDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        if position == .front {
            // Camera trước TrueDepth hoặc Wide
            let discovery = AVCaptureDevice.DiscoverySession(
                deviceTypes: [
                    .builtInTrueDepthCamera,
                    .builtInWideAngleCamera
                ],
                mediaType: .video,
                position: .front
            )
            return discovery.devices.first ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        }

        // Camera sau: Ưu tiên camera đa ống kính (Triple Camera trên iPhone 15 Pro Max hoặc Dual Wide)
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInTripleCamera,
                .builtInDualWideCamera,
                .builtInDualCamera,
                .builtInUltraWideCamera,
                .builtInWideAngleCamera
            ],
            mediaType: .video,
            position: .back
        )
        return discovery.devices.first
    }

    private func configureCapabilities(for device: AVCaptureDevice) {
        if currentPosition == .back {
            let hasUltraWide = device.deviceType == .builtInTripleCamera ||
                               device.deviceType == .builtInDualWideCamera ||
                               !device.virtualDeviceSwitchOverVideoZoomFactors.isEmpty

            if hasUltraWide {
                self.availableZoomFactors = [0.5, 1.0, 2.0]
            } else {
                self.availableZoomFactors = [1.0, 2.0]
            }
            self.isFlashSupported = device.hasFlash
        } else {
            // Camera trước: nếu hỗ trợ zoom out (full sensor 23mm) thì hiển thị [1.0, 0.7] (1x & Góc rộng)
            if device.maxAvailableVideoZoomFactor >= 1.4 {
                self.availableZoomFactors = [1.0, 0.7]
            } else {
                self.availableZoomFactors = [1.0]
            }
            self.isFlashSupported = false
            self.flashMode = .off
        }
        self.currentZoomFactor = 1.0
    }

    // MARK: - Zoom Factor Mapping (Ánh xạ chuẩn xác zoom UI và zoom phần cứng AVFoundation)

    /// Trả về hệ số zoom vật lý của AVFoundation tương ứng với mức zoom UI người dùng chọn
    private func physicalZoomFactor(for uiFactor: CGFloat, on device: AVCaptureDevice) -> CGFloat {
        if currentPosition == .front {
            // Camera trước TrueDepth:
            // uiFactor < 1.0 (Góc rộng 0.7x): Toàn bộ cảm biến 12MP 23mm (AVFoundation zoom 1.0)
            // uiFactor == 1.0 (Tiêu chuẩn): Cắt tiêu chuẩn 30mm tránh méo mặt (AVFoundation zoom 1.4)
            if uiFactor < 1.0 {
                return 1.0
            } else {
                return min(1.4, device.maxAvailableVideoZoomFactor)
            }
        }

        // Camera sau:
        // Trên TripleCamera / DualWideCamera của iPhone:
        // AVFoundation zoom 1.0 = Ống kính Ultra-Wide 13mm (tương đương 0.5x trên UI Apple)
        // Switchover factor đầu tiên (thường là 2.0) = Ống kính Wide 24mm (tương đương 1x trên UI Apple)
        if let switchOver = device.virtualDeviceSwitchOverVideoZoomFactors.first {
            let baseWide = CGFloat(switchOver.doubleValue) // ~2.0
            if uiFactor <= 0.5 {
                return 1.0 // Ultra-wide lens thật 13mm
            } else if abs(uiFactor - 1.0) < 0.1 {
                return baseWide // Wide lens 1x 24mm
            } else {
                let target = baseWide * uiFactor // 2x -> 4.0 (48mm)
                return min(target, device.maxAvailableVideoZoomFactor)
            }
        }

        // Với camera đơn thông thường:
        let clamped = max(device.minAvailableVideoZoomFactor, min(uiFactor, device.maxAvailableVideoZoomFactor))
        return clamped
    }

    func setZoomFactor(_ factor: CGFloat) {
        currentZoomFactor = factor
        guard let device = videoDeviceInput?.device else { return }
        let targetPhysical = physicalZoomFactor(for: factor, on: device)
        applyZoom(targetPhysical, on: device)
    }

    nonisolated private func applyZoom(_ factor: CGFloat, on device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            let clamped = max(device.minAvailableVideoZoomFactor, min(factor, device.maxAvailableVideoZoomFactor))
            device.videoZoomFactor = clamped
            device.unlockForConfiguration()
        } catch {
            print("Zoom error: \(error.localizedDescription)")
        }
    }

    // MARK: - Toggle Camera (Front / Back)

    func flipCamera() {
        currentPosition = (currentPosition == .back) ? .front : .back
        setupSession()
    }

    // MARK: - Flash Toggle

    func toggleFlash() {
        guard isFlashSupported else { return }
        switch flashMode {
        case .auto: flashMode = .on
        case .on:   flashMode = .off
        case .off:  flashMode = .auto
        @unknown default: flashMode = .auto
        }
    }

    // MARK: - Photo Capture

    func capturePhoto() {
        guard session.isRunning else { return }

        let settings = AVCapturePhotoSettings()
        if isFlashSupported && photoOutput.supportedFlashModes.contains(flashMode) {
            settings.flashMode = flashMode
        } else {
            settings.flashMode = .off
        }

        if #available(iOS 16.0, *) {
            settings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
        } else {
            settings.isHighResolutionPhotoEnabled = true
        }

        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    // MARK: - Viewport Crop Helper (Khớp 1:1 tỉ lệ khung hình Locket)

    nonisolated static func cropToSquare(image: UIImage) -> UIImage {
        let cgImage = image.cgImage!
        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        let minSide = min(width, height)

        let x = (width - minSide) / 2.0
        let y = (height - minSide) / 2.0

        let cropRect = CGRect(x: x, y: y, width: minSide, height: minSide)
        guard let croppedCgImage = cgImage.cropping(to: cropRect) else {
            return image
        }

        return UIImage(cgImage: croppedCgImage, scale: image.scale, orientation: image.imageOrientation)
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraService: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let originalImage = UIImage(data: data) else {
            return
        }

        // Tự động crop theo đúng tỷ lệ khung hình gần vuông để preview và ảnh sau chụp đồng nhất 100%
        let processedImage = CameraService.cropToSquare(image: originalImage)

        Task { @MainActor in
            self.capturedImage = processedImage
        }
    }
}
