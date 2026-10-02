/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
An object that manages a photo capture output to take photographs.
*/

import AVFoundation
import CoreImage

enum PhotoCaptureError: Error {
    case noPhotoData
}

/// An object that manages a photo capture output to perform take photographs.
final class PhotoCapture: OutputService {
    
    /// A value that indicates the current state of photo capture.
    @Published private(set) var captureActivity: CaptureActivity = .idle
    
    /// The capture output type for this service.
    let output = AVCapturePhotoOutput()
    
    // An internal alias for the output.
    private var photoOutput: AVCapturePhotoOutput { output }
    
    /// A value that indicates whether the photo output can accept a new capture request.
    @Published private(set) var captureReadiness = CaptureReadiness.sessionNotRunning
    
    // An object that tracks the photo output's readiness and notifies the app on the main queue.
    private lazy var readinessCoordinator = AVCapturePhotoOutputReadinessCoordinator(photoOutput: photoOutput)
    
    // The coordinator's delegate. The coordinator holds a weak reference, so this object keeps it alive.
    private let readinessObserver = ReadinessObserver()
    
    // The task that forwards readiness changes to `captureReadiness`.
    private var readinessTask: Task<Void, Never>?
    
    // The current capabilities available.
    private(set) var capabilities: CaptureCapabilities = .unknown
    
    // A count of Live Photo captures currently in progress.
    private var livePhotoCount = 0
    
    // MARK: - Capture a photo.
    
    /// The app calls this method when the user taps the photo capture button.
    func capturePhoto(with features: PhotoFeatures) async throws -> Photo {
        // Wrap the delegate-based capture API in a continuation to use it in an async context.
        try await withCheckedThrowingContinuation { continuation in
            
            // Create a settings object to configure the photo capture.
            let photoSettings = createPhotoSettings(with: features)
            
            let delegate = PhotoCaptureDelegate(continuation: continuation)
            monitorProgress(of: delegate)
            
            // Tell the coordinator about the request before the capture starts.
            readinessCoordinator.startTrackingCaptureRequest(using: photoSettings)
            
            // Capture a new photo with the specified settings.
            photoOutput.capturePhoto(with: photoSettings, delegate: delegate)
        }
    }
    
    // MARK: - Create a photo settings object.
    
    // Create a photo settings object with the features a person enables in the UI.
    private func createPhotoSettings(with features: PhotoFeatures) -> AVCapturePhotoSettings {
        // Create a new settings object to configure the photo capture.
        var photoSettings = AVCapturePhotoSettings()
        
        // Capture photos in HEIF format when the device supports it.
        if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
            photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
        }
        
        /// Request a RAW photo along with the processed photo when the device supports the chosen format.
        /// The capture then delivers two photos, so the processed format needs a codec of its own.
        let rawType = rawPixelFormat(for: features.rawFormat)
        if let rawType {
            let codec: AVVideoCodecType = photoOutput.availablePhotoCodecTypes.contains(.hevc) ? .hevc : .jpeg
            photoSettings = AVCapturePhotoSettings(rawPixelFormatType: rawType,
                                                   processedFormat: [AVVideoCodecKey: codec])
            logger.debug("Capturing with RAW format: \(features.rawFormat.description)")
        }
        
        /// Set the format of the preview image to capture. The `photoSettings` object returns the available
        /// preview format types in order of compatibility with the primary image.
        if let previewPhotoPixelFormatType = photoSettings.availablePreviewPhotoPixelFormatTypes.first {
            photoSettings.previewPhotoFormat = [kCVPixelBufferPixelFormatTypeKey as String: previewPhotoPixelFormatType]
        }
        
        /// Set the largest dimensions that the photo output supports.
        /// `CaptureService` automatically updates the photo output's `maxPhotoDimensions`
        /// when the capture pipeline changes.
        photoSettings.maxPhotoDimensions = photoOutput.maxPhotoDimensions
        
        // Set the movie URL if the photo output supports Live Photo capture.
        // An Apple ProRAW capture can't include a Live Photo movie.
        let excludesLivePhoto = rawType != nil && features.rawFormat == .appleProRAW
        photoSettings.livePhotoMovieFileURL = features.isLivePhotoEnabled && !excludesLivePhoto ? URL.movieFileURL : nil
        
        // Set the priority of speed versus quality during this capture.
        if let prioritization = AVCapturePhotoOutput.QualityPrioritization(rawValue: features.qualityPrioritization.rawValue) {
            photoSettings.photoQualityPrioritization = prioritization
        }
        
        // A Bayer RAW capture throws an exception with any prioritization other than speed.
        if rawType != nil && features.rawFormat == .bayerRAW {
            photoSettings.photoQualityPrioritization = .speed
        }
        
        return photoSettings
    }
    
    /// Returns the first RAW pixel format of the requested kind that the photo output offers.
    private func rawPixelFormat(for rawFormat: RAWFormat) -> OSType? {
        let formats = photoOutput.availableRawPhotoPixelFormatTypes
        switch rawFormat {
        case .off:
            return nil
        case .appleProRAW:
            return formats.first { AVCapturePhotoOutput.isAppleProRAWPixelFormat($0) }
        case .bayerRAW:
            return formats.first { AVCapturePhotoOutput.isBayerRAWPixelFormat($0) }
        }
    }
    
    /// Monitors the progress of a photo capture delegate.
    ///
    /// The `PhotoCaptureDelegate` produces an asynchronous stream of values that indicate its current activity.
    /// The app propagates the activity values up to the view tier so the UI can update accordingly.
    private func monitorProgress(of delegate: PhotoCaptureDelegate, isolation: isolated (any Actor)? = #isolation) {
        Task {
            _ = isolation
            var isLivePhoto = false
            // Asynchronously monitor the activity of the delegate while the system performs capture.
            for await activity in delegate.activityStream {
                var currentActivity = activity
                /// More than one activity value for the delegate may report that `isLivePhoto` is `true`.
                /// Only increment/decrement the count when the value changes from its previous state.
                if activity.isLivePhoto != isLivePhoto {
                    isLivePhoto = activity.isLivePhoto
                    // Increment or decrement as appropriate.
                    livePhotoCount += isLivePhoto ? 1 : -1
                    if livePhotoCount > 0 {
                        /// Set `isLivePhoto` to `true` while another Live Photo is still in progress.
                        /// This prevents the "Live" badge in the UI from flickering.
                        currentActivity = .photoCapture(willCapture: activity.willCapture, isLivePhoto: true)
                    }
                }
                captureActivity = currentActivity
            }
        }
    }
    
    /// Monitors the readiness values that the coordinator's delegate produces.
    ///
    /// The delegate reports on the main queue. The stream moves each value to the capture service's actor.
    private func monitorReadiness(isolation: isolated (any Actor)? = #isolation) {
        readinessTask = Task {
            _ = isolation
            for await readiness in readinessObserver.readinessStream {
                logger.debug("Capture readiness changed to \(String(describing: readiness))")
                captureReadiness = readiness
            }
        }
    }
    
    // MARK: - Update the photo output configuration
    
    /// Reconfigures the photo output and updates the output service's capabilities accordingly.
    ///
    /// The `CaptureService` calls this method whenever you change cameras.
    ///
    func updateConfiguration(for device: AVCaptureDevice) {
        // Enable all supported features.
        photoOutput.maxPhotoDimensions = device.activeFormat.supportedMaxPhotoDimensions.last ?? .zero
        photoOutput.isLivePhotoCaptureEnabled = photoOutput.isLivePhotoCaptureSupported
        photoOutput.maxPhotoQualityPrioritization = .quality
        photoOutput.isZeroShutterLagEnabled = photoOutput.isZeroShutterLagSupported
        photoOutput.isResponsiveCaptureEnabled = photoOutput.isResponsiveCaptureSupported
        photoOutput.isFastCapturePrioritizationEnabled = photoOutput.isFastCapturePrioritizationSupported
        photoOutput.isAutoDeferredPhotoDeliveryEnabled = photoOutput.isAutoDeferredPhotoDeliverySupported
        // Enabling Apple ProRAW adds its formats to the available RAW formats.
        photoOutput.isAppleProRAWEnabled = photoOutput.isAppleProRAWSupported
        // Log the state of the capture switches so a device test can read them.
        let output = photoOutput
        logger.debug("Zero shutter lag (supported/enabled): \(output.isZeroShutterLagSupported)/\(output.isZeroShutterLagEnabled)")
        logger.debug("Responsive capture (supported/enabled): \(output.isResponsiveCaptureSupported)/\(output.isResponsiveCaptureEnabled)")
        logger.debug("Fast capture prioritization (supported/enabled): \(output.isFastCapturePrioritizationSupported)/\(output.isFastCapturePrioritizationEnabled)")
        // Start tracking readiness once. Setting the delegate delivers the first value.
        if readinessTask == nil {
            readinessCoordinator.delegate = readinessObserver
            monitorReadiness()
        }
        updateCapabilities(for: device)
    }
    
    private func updateCapabilities(for device: AVCaptureDevice) {
        capabilities = CaptureCapabilities(isLivePhotoCaptureSupported: photoOutput.isLivePhotoCaptureSupported,
                                           isAppleProRAWSupported: rawPixelFormat(for: .appleProRAW) != nil,
                                           isBayerRAWSupported: rawPixelFormat(for: .bayerRAW) != nil)
    }
}

// MARK: - A delegate to observe the photo output's readiness.

/// An object that adopts the readiness coordinator's delegate protocol and turns its callbacks into a stream.
///
/// The coordinator calls the delegate on the main queue, so the object yields each value into an
/// asynchronous stream that the capture service's actor consumes.
private class ReadinessObserver: NSObject, AVCapturePhotoOutputReadinessCoordinatorDelegate {
    
    /// A stream of readiness values that the photo output reports.
    let readinessStream: AsyncStream<CaptureReadiness>
    private let readinessContinuation: AsyncStream<CaptureReadiness>.Continuation
    
    override init() {
        let (readinessStream, readinessContinuation) = AsyncStream.makeStream(of: CaptureReadiness.self)
        self.readinessStream = readinessStream
        self.readinessContinuation = readinessContinuation
        super.init()
    }
    
    func readinessCoordinator(_ coordinator: AVCapturePhotoOutputReadinessCoordinator,
                              captureReadinessDidChange captureReadiness: AVCapturePhotoOutput.CaptureReadiness) {
        readinessContinuation.yield(CaptureReadiness(captureReadiness))
    }
}

private extension CaptureReadiness {
    /// Creates a readiness value from the AVFoundation value.
    init(_ readiness: AVCapturePhotoOutput.CaptureReadiness) {
        switch readiness {
        case .ready: self = .ready
        case .notReadyMomentarily: self = .notReadyMomentarily
        case .notReadyWaitingForCapture: self = .notReadyWaitingForCapture
        case .notReadyWaitingForProcessing: self = .notReadyWaitingForProcessing
        default: self = .sessionNotRunning
        }
    }
}

typealias PhotoContinuation = CheckedContinuation<Photo, Error>

// MARK: - A photo capture delegate to process the captured photo.

/// An object that adopts the `AVCapturePhotoCaptureDelegate` protocol to respond to photo capture life-cycle events.
///
/// The delegate produces a stream of events that indicate its current state of processing.
private class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    
    private let continuation: PhotoContinuation
    
    private var isLivePhoto = false
    private var isProxyPhoto = false
    
    private var photoData: Data?
    private var rawData: Data?
    private var livePhotoMovieURL: URL?
    
    /// A stream of capture activity values that indicate the current state of progress.
    let activityStream: AsyncStream<CaptureActivity>
    private let activityContinuation: AsyncStream<CaptureActivity>.Continuation
    
    /// Creates a new delegate object with the checked continuation to call when processing is complete.
    init(continuation: PhotoContinuation) {
        self.continuation = continuation
        
        let (activityStream, activityContinuation) = AsyncStream.makeStream(of: CaptureActivity.self)
        self.activityStream = activityStream
        self.activityContinuation = activityContinuation
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, willBeginCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        // Determine if this is a live capture.
        isLivePhoto = resolvedSettings.livePhotoMovieDimensions != .zero
        activityContinuation.yield(.photoCapture(isLivePhoto: isLivePhoto))
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        // Signal that a capture is beginning.
        activityContinuation.yield(.photoCapture(willCapture: true, isLivePhoto: isLivePhoto))
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishRecordingLivePhotoMovieForEventualFileAt outputFileURL: URL, resolvedSettings: AVCaptureResolvedPhotoSettings) {
        // Indicates that Live Photo capture is over.
        activityContinuation.yield(.photoCapture(isLivePhoto: false))
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingLivePhotoToMovieFileAt outputFileURL: URL, duration: CMTime, photoDisplayTime: CMTime, resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if let error {
            logger.debug("Error processing Live Photo companion movie: \(String(describing: error))")
        }
        livePhotoMovieURL = outputFileURL
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCapturingDeferredPhotoProxy deferredPhotoProxy: AVCaptureDeferredPhotoProxy?, error: Error?) {
        if let error = error {
            logger.debug("Error capturing deferred photo: \(error)")
            return
        }
        // Capture the data for this photo.
        photoData = deferredPhotoProxy?.fileDataRepresentation()
        isProxyPhoto = true
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            logger.debug("Error capturing photo: \(String(describing: error))")
            return
        }
        // A RAW capture calls this method twice: once for the DNG and once for the processed photo.
        if photo.isRawPhoto {
            let data = photo.fileDataRepresentation()
            logger.debug("Captured RAW photo, \(data?.count ?? 0) bytes")
            rawData = data
        } else {
            photoData = photo.fileDataRepresentation()
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {

        defer {
            /// Finish the continuation to terminate the activity stream.
            activityContinuation.finish()
        }

        // If an error occurs, resume the continuation by throwing an error, and return.
        if let error {
            continuation.resume(throwing: error)
            return
        }
        
        // If the app captures no photo data, resume the continuation by throwing an error, and return.
        guard let photoData else {
            continuation.resume(throwing: PhotoCaptureError.noPhotoData)
            return
        }
        
        /// Create a photo object to save to the `MediaLibrary`.
        let photo = Photo(data: photoData, isProxy: isProxyPhoto, livePhotoMovieURL: livePhotoMovieURL, rawData: rawData)
        // Resume the continuation by returning the captured photo.
        continuation.resume(returning: photo)
    }
}
