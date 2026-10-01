/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
A protocol that represents the model for the camera view.
*/

import SwiftUI

/// A protocol that represents the model for the camera view.
///
/// The AVFoundation camera APIs require running on a physical device. The app defines the model as a protocol to make it
/// simple to swap out the real camera for a test camera when previewing SwiftUI views.
@MainActor
protocol Camera: AnyObject, SendableMetatype {

    /// Provides the current status of the camera.
    var status: CameraStatus { get }

    /// The camera's current activity state, which can be photo capture, movie capture, or idle.
    var captureActivity: CaptureActivity { get }

    /// A value that indicates whether the photo output can accept a new capture request.
    var captureReadiness: CaptureReadiness { get }

    /// The source of video content for a camera preview.
    var previewSource: PreviewSource { get }
    
    /// Starts the camera capture pipeline.
    func start() async
    
    /// The capture mode, which can be photo or video.
    var captureMode: CaptureMode { get set }
    
    /// A Boolean value that indicates whether the camera is currently switching capture modes.
    var isSwitchingModes: Bool { get }
    
    /// Switches between video devices available on the host system.
    func switchVideoDevices() async
    
    /// A Boolean value that indicates whether the camera is currently switching video devices.
    var isSwitchingVideoDevices: Bool { get }
    
    /// Performs a one-time automatic focus and exposure operation.
    func focusAndExpose(at point: CGPoint) async
    
    /// A Boolean value that indicates whether to capture Live Photos when capturing stills.
    var isLivePhotoEnabled: Bool { get set }
    
    /// A value that indicates how to balance the photo capture quality versus speed.
    var qualityPrioritization: QualityPrioritization { get set }
    
    /// A value that indicates which RAW format to capture along with the processed photo.
    var rawFormat: RAWFormat { get set }
    
    /// The capture features that the current camera configuration supports.
    var captureCapabilities: CaptureCapabilities { get }
    
    /// Captures a photo and writes it to the user's photo library.
    func capturePhoto() async
    
    /// A Boolean value that indicates whether to show visual feedback when capture begins.
    var shouldFlashScreen: Bool { get }
    
    /// Starts or stops recording a movie, and writes it to the user's photo library when complete.
    func toggleRecording() async
    
    /// A thumbnail image for the most recent photo or video capture.
    var thumbnail: CGImage? { get }
    
    /// An error if the camera encountered a problem.
    var error: Error? { get }
}
