/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
Supporting data types for the app.
*/

import AVFoundation

// MARK: - Supporting types

/// An enumeration that describes the current status of the camera.
enum CameraStatus {
    /// The initial status upon creation.
    case unknown
    /// A status that indicates a person disallows access to the camera or microphone.
    case unauthorized
    /// A status that indicates the camera failed to start.
    case failed
    /// A status that indicates the camera is successfully running.
    case running
    /// A status that indicates higher-priority media processing is interrupting the camera.
    case interrupted
}

/// An enumeration that defines the activity states the capture service supports.
///
/// This type provides feedback to the UI regarding the active status of the `CaptureService` actor.
enum CaptureActivity {
    case idle
    /// A status that indicates the capture service is performing photo capture.
    case photoCapture(willCapture: Bool = false, isLivePhoto: Bool = false)
    /// A status that indicates the capture service is performing movie capture.
    case movieCapture(duration: TimeInterval = 0.0)
    
    var isLivePhoto: Bool {
        if case .photoCapture(_, let isLivePhoto) = self {
            return isLivePhoto
        }
        return false
    }
    
    var willCapture: Bool {
        if case .photoCapture(let willCapture, _) = self {
            return willCapture
        }
        return false
    }
    
    var currentTime: TimeInterval {
        if case .movieCapture(let duration) = self {
            return duration
        }
        return .zero
    }
    
    var isRecording: Bool {
        if case .movieCapture = self {
            return true
        }
        return false
    }
}

/// An enumeration of the capture modes that the camera supports.
enum CaptureMode: String, Identifiable, CaseIterable, Codable {
    var id: Self { self }
    /// A mode that enables photo capture.
    case photo
    /// A mode that enables video capture.
    case video
    /// A mode that shows the back camera and the front camera at the same time.
    case dual
    
    var systemName: String {
        switch self {
        case .photo:
            "camera.fill"
        case .video:
            "video.fill"
        case .dual:
            "rectangle.on.rectangle"
        }
    }
}

/// An enumeration that describes whether the photo output can accept a new capture request.
///
/// This type mirrors `AVCapturePhotoOutput.CaptureReadiness` so the views don't depend on AVFoundation.
enum CaptureReadiness {
    /// A status that indicates the photo output can service a new request.
    case ready
    /// A status that indicates the output isn't ready, but may be ready again shortly.
    case notReadyMomentarily
    /// A status that indicates the output is busy capturing.
    case notReadyWaitingForCapture
    /// A status that indicates the output is busy processing.
    case notReadyWaitingForProcessing
    /// A status that indicates the capture session isn't running.
    case sessionNotRunning
    
    /// A Boolean value that indicates whether the UI should disable the photo button.
    ///
    /// The button stays available for `notReadyMomentarily`. The state is too short to justify a visible change.
    var isCaptureButtonDisabled: Bool {
        self == .notReadyWaitingForCapture || self == .notReadyWaitingForProcessing
    }
}

/// A structure that represents a captured photo.
struct Photo: Sendable {
    let data: Data
    let isProxy: Bool
    let livePhotoMovieURL: URL?
    /// The DNG data of a RAW capture, or `nil` when the capture has no RAW photo.
    let rawData: Data?
}

/// A structure that contains the uniform type identifier and movie URL.
struct Movie: Sendable {
    /// The temporary location of the file on disk.
    let url: URL
}

struct PhotoFeatures {
    let isLivePhotoEnabled: Bool
    let qualityPrioritization: QualityPrioritization
    var rawFormat = RAWFormat.off
}

/// A structure that represents the capture capabilities of `CaptureService` in
/// its current configuration.
struct CaptureCapabilities {

    let isLivePhotoCaptureSupported: Bool
    let isAppleProRAWSupported: Bool
    let isBayerRAWSupported: Bool
    let isHDRSupported: Bool
    
    init(isLivePhotoCaptureSupported: Bool = false,
         isAppleProRAWSupported: Bool = false,
         isBayerRAWSupported: Bool = false,
         isHDRSupported: Bool = false) {
        self.isLivePhotoCaptureSupported = isLivePhotoCaptureSupported
        self.isAppleProRAWSupported = isAppleProRAWSupported
        self.isBayerRAWSupported = isBayerRAWSupported
        self.isHDRSupported = isHDRSupported
    }
    
    static let unknown = CaptureCapabilities()
}

/// The cameras of the device, grouped by the direction that they face in relation to the camera preview.
///
/// On a device with one display, the front camera always faces the person and the back cameras
/// always face the scene. On iPhone Duo, the direction of a camera changes when a person opens or closes the device.
struct CameraDirections: Sendable, Equatable {
    /// The unique identifiers of the cameras that face the person who looks at the preview.
    let forwardFacing: [String]
    /// The unique identifiers of the cameras that face the scene behind the preview.
    let backwardFacing: [String]
}

/// A zoom level that the camera interface offers, such as 0.5x, 1x, or 2x.
struct ZoomLevel: Identifiable, Hashable {
    /// The value to set on the capture device.
    let videoZoomFactor: CGFloat
    /// The value to show to a person.
    let displayFactor: CGFloat
    
    var id: CGFloat { videoZoomFactor }
    
    /// A short text for the value, such as "0.5" or "2".
    var label: String {
        ZoomLevel.label(for: displayFactor)
    }
    
    /// Returns a short text for a display zoom factor.
    static func label(for displayFactor: CGFloat) -> String {
        Double(displayFactor).formatted(.number.precision(.fractionLength(0...1)))
    }
}

enum QualityPrioritization: Int, Identifiable, CaseIterable, CustomStringConvertible, Codable {
    var id: Self { self }
    case speed = 1
    case balanced
    case quality
    var description: String {
        switch self {
        case.speed:
            return "Speed"
        case .balanced:
            return "Balanced"
        case .quality:
            return "Quality"
        }
    }
}

/// An enumeration that describes the RAW format to capture along with the processed photo.
enum RAWFormat: Int, Identifiable, CaseIterable, CustomStringConvertible, Codable {
    var id: Self { self }
    /// No RAW photo.
    case off
    /// A linear DNG that the system partially processes.
    case appleProRAW
    /// A DNG with the unprocessed sensor data.
    case bayerRAW
    var description: String {
        switch self {
        case .off:
            return "Off"
        case .appleProRAW:
            return "Apple ProRAW"
        case .bayerRAW:
            return "RAW"
        }
    }
}

enum CameraError: Error {
    case videoDeviceUnavailable
    case audioDeviceUnavailable
    case addInputFailed
    case addOutputFailed
    case setupFailed
    case deviceChangeFailed
}

protocol OutputService {
    associatedtype Output: AVCaptureOutput
    var output: Output { get }
    var captureActivity: CaptureActivity { get }
    var capabilities: CaptureCapabilities { get }
    func updateConfiguration(for device: AVCaptureDevice)
    func setVideoRotationAngle(_ angle: CGFloat)
}

extension OutputService {
    func setVideoRotationAngle(_ angle: CGFloat) {
        // Set the rotation angle on the output object's video connection.
        output.connection(with: .video)?.videoRotationAngle = angle
    }
    func updateConfiguration(for device: AVCaptureDevice) {}
}
