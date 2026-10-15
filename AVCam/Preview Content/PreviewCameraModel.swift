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
    var qualityPrioritization = QualityPrioritization.quality
    var rawFormat = RAWFormat.off
    // Report both RAW formats as supported so the previews show the RAW control.
    let captureCapabilities = CaptureCapabilities(isAppleProRAWSupported: true, isBayerRAWSupported: true)
    var shouldFlashScreen = false
    var captureReadiness = CaptureReadiness.ready
    
    struct PreviewSourceStub: PreviewSource {
        // Stubbed out for test purposes.
        func connect(to target: PreviewTarget) {}
    }
    
    let previewSource: PreviewSource = PreviewSourceStub()
    
    private(set) var status = CameraStatus.unknown
    private(set) var captureActivity = CaptureActivity.idle
    
    private(set) var isSwitchingVideoDevices = false
    private(set) var thumbnail: CGImage?
    
    var error: Error?
    
    init(status: CameraStatus = .unknown) {
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
    
    func focusAndExpose(at point: CGPoint) {
        logger.debug("Focus and expose isn't implemented in PreviewCamera.")
    }
}
