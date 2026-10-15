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

    /// The camera's current activity state, which can be photo capture or idle.
    var captureActivity: CaptureActivity { get }

    /// The source of video content for a camera preview.
    var previewSource: PreviewSource { get }
    
    /// Starts the camera capture pipeline.
    func start() async
    
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
    
    /// A thumbnail image for the most recent photo capture.
    var thumbnail: CGImage? { get }
    
    /// An error if the camera encountered a problem.
    var error: Error? { get }
}
