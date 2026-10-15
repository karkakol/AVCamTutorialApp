//
//  PreviewCameraModel.swift
//  AVCam
//
//  Created by Karol Kakol on 12/10/2026.
//

import Foundation
import SwiftUI

@Observable
class PreviewCameraModel: Camera {
    struct PreviewSourceStub: PreviewSource {
        func connect(to target: PreviewTarget) {}
    }
    
    let previewSource: PreviewSource = PreviewSourceStub()
    
    private(set) var status = CameraStatus.unknown
    
    private(set) var isSwitchingVideoDevices = false
    
    init(status: CameraStatus = CameraStatus.unknown) {
        self.status = status
    }
    
    func start() async {
        if status == .unknown {
            status = .running
        }
    }
    
    func switchVideoDevices() {
        logger.debug("Device switching isn't implemented in PreviewCamera")
    }
}
