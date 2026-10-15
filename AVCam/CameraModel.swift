//
//  CameraModel.swift
//  AVCam
//
//  Created by Karol Kakol on 09/10/2026.
//

import SwiftUI

@MainActor
@Observable
final class CameraModel: Camera {
    private(set) var status = CameraStatus.unknown
    
    private(set) var isSwitchingVideoDevices: Bool = false
    
    var previewSource: PreviewSource { captureService.previewSource}
    
    private let captureService = CaptureService()
    
    init() {
        
    }
    
    func start() async {
        guard await captureService.isAuthorized else {
            status = .unauthorized
            return
        }
        
        do {
            try await captureService.start()
            status = .running
        } catch {
            logger.error("Failed to start capture service. \(error)")
            status = .failed
        }
    }
    
    func switchVideoDevices() async {
        isSwitchingVideoDevices = true
        defer { isSwitchingVideoDevices = false}
        await captureService.selectNextVideoDevice()
    }
}
