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
    
    // MARK: - Capture a photo.
    
    /// The app calls this method when the user taps the photo capture button.
    func capturePhoto() async throws -> Photo {
        // Wrap the delegate-based capture API in a continuation to use it in an async context.
        try await withCheckedThrowingContinuation { continuation in
            
            // Create a settings object to configure the photo capture.
            let photoSettings = createPhotoSettings()
            
            let delegate = PhotoCaptureDelegate(continuation: continuation)
            monitorProgress(of: delegate)
            
            // Capture a new photo with the specified settings.
            photoOutput.capturePhoto(with: photoSettings, delegate: delegate)
        }
    }
    
    // MARK: - Create a photo settings object.
    
    // Create a photo settings object to configure the photo capture.
    private func createPhotoSettings() -> AVCapturePhotoSettings {
        
        // Create a new settings object to configure the photo capture.
        var photoSettings = AVCapturePhotoSettings()
        
        // Capture photos in HEIF format when the device supports it.
        if photoOutput.availablePhotoCodecTypes.contains(.hevc) {
            photoSettings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.hevc])
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
        
        return photoSettings
    }
    
    /// Monitors the progress of a photo capture delegate.
    ///
    /// The `PhotoCaptureDelegate` produces an asynchronous stream of values that indicate its current activity.
    /// The app propagates the activity values up to the view tier so the UI can update accordingly.
    private func monitorProgress(of delegate: PhotoCaptureDelegate, isolation: isolated (any Actor)? = #isolation) {
        Task {
            _ = isolation
            // Asynchronously monitor the activity of the delegate while the system performs capture.
            for await activity in delegate.activityStream {
                captureActivity = activity
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
    }
}

typealias PhotoContinuation = CheckedContinuation<Photo, Error>

// MARK: - A photo capture delegate to process the captured photo.

/// An object that adopts the `AVCapturePhotoCaptureDelegate` protocol to respond to photo capture life-cycle events.
///
/// The delegate produces a stream of events that indicate its current state of processing.
private class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    
    private let continuation: PhotoContinuation
    
    private var photoData: Data?
    
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
        // Signal that the photo output accepts the capture request.
        activityContinuation.yield(.photoCapture())
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        // Signal that a capture is beginning.
        activityContinuation.yield(.photoCapture(willCapture: true))
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            logger.debug("Error capturing photo: \(String(describing: error))")
            return
        }
        photoData = photo.fileDataRepresentation()
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
        let photo = Photo(data: photoData)
        // Resume the continuation by returning the captured photo.
        continuation.resume(returning: photo)
    }
}
