/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
A Camera implementation to use when working with SwiftUI previews.
*/

import Foundation
import SwiftUI

@Observable
class PreviewCameraModel: Camera {
    
    var isLivePhotoEnabled = true
    var prefersMinimizedUI = false
    var qualityPrioritization = QualityPrioritization.quality
    var rawFormat = RAWFormat.off
    // Report both RAW formats as supported so the previews show the RAW control.
    let captureCapabilities = CaptureCapabilities(isAppleProRAWSupported: true, isBayerRAWSupported: true)
    var shouldFlashScreen = false
    var captureReadiness = CaptureReadiness.ready
    var isHDRVideoSupported = false
    var isHDRVideoEnabled = false
    
    // Example zoom levels, so that SwiftUI previews show the zoom control.
    let zoomLevels = [ZoomLevel(videoZoomFactor: 1.0, displayFactor: 0.5),
                      ZoomLevel(videoZoomFactor: 2.0, displayFactor: 1.0),
                      ZoomLevel(videoZoomFactor: 6.0, displayFactor: 3.0)]
    private(set) var displayZoomFactor: CGFloat = 1.0
    
    struct PreviewSourceStub: PreviewSource {
        // Stubbed out for test purposes.
        func connect(to target: PreviewTarget) {}
    }
    
    let previewSource: PreviewSource = PreviewSourceStub()
    
    private(set) var status = CameraStatus.unknown
    private(set) var captureActivity = CaptureActivity.idle
    var captureMode = CaptureMode.photo {
        didSet {
            isSwitchingModes = true
            Task {
                // Create a short delay to mimic the time it takes to reconfigure the session.
                try? await Task.sleep(until: .now + .seconds(0.3), clock: .continuous)
                self.isSwitchingModes = false
            }
        }
    }
    private(set) var isSwitchingModes = false
    private(set) var isVideoDeviceSwitchable = true
    private(set) var isSwitchingVideoDevices = false
    private(set) var thumbnail: CGImage?
    
    var error: Error?
    
    init(captureMode: CaptureMode = .photo, status: CameraStatus = .unknown) {
        self.captureMode = captureMode
        self.status = status
    }
    
    func start() async {
        if status == .unknown {
            status = .running
        }
    }
    
    func switchVideoDevices() {
        logger.debug("Device switching isn't implemented in PreviewCamera.")
    }
    
    func capturePhoto() {
        logger.debug("Photo capture isn't implemented in PreviewCamera.")
    }
    
    func toggleRecording() {
        logger.debug("Moving capture isn't implemented in PreviewCamera.")
    }
    
    func focusAndExpose(at point: CGPoint) {
        logger.debug("Focus and expose isn't implemented in PreviewCamera.")
    }
    
    private func capabilities(for mode: CaptureMode) -> CaptureCapabilities {
        switch mode {
        case .photo:
            return CaptureCapabilities(isLivePhotoCaptureSupported: true)
        case .video:
            return CaptureCapabilities(isLivePhotoCaptureSupported: false,
                                       isHDRSupported: true)
        }
    }
    
    func syncState() async {
        logger.debug("Syncing state isn't implemented in PreviewCamera.")
    }
    
    func setZoom(to level: ZoomLevel) {
        displayZoomFactor = level.displayFactor
    }
    
    func setZoom(displayFactor: CGFloat) {
        displayZoomFactor = displayFactor
    }
    
    func setCameraDirections(_ directions: CameraDirections) {
        logger.debug("Camera directions aren't implemented in PreviewCamera.")
    }
}
