//
//  DeviceLookup.swift
//  AVCam
//
//  Created by Karol Kakol on 14/10/2026.
//

import AVFoundation

final class DeviceLookup {

    private let backCameraDiscoverySession: AVCaptureDevice.DiscoverySession
    private let frontCameraDiscoverySession: AVCaptureDevice.DiscoverySession
    private let externalCameraDiscoverySession: AVCaptureDevice.DiscoverySession

    init() {
        backCameraDiscoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInDualCamera, .builtInWideAngleCamera],
            mediaType: .video,
            position: .back
        )
        frontCameraDiscoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInTrueDepthCamera, .builtInWideAngleCamera],
            mediaType: .video,
            position: .front
        )
        externalCameraDiscoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.external],
            mediaType: .video,
            position: .unspecified
        )

        if AVCaptureDevice.systemPreferredCamera == nil {
            AVCaptureDevice.userPreferredCamera = backCameraDiscoverySession.devices.first
        }
    }

    var defaultCamera: AVCaptureDevice {
        get throws {
            guard let preferredDevice = AVCaptureDevice.systemPreferredCamera
            else {
                throw CameraError.videoDeviceUnavailable
            }
            return preferredDevice
        }
    }

    var cameras: [AVCaptureDevice] {
        var cameras = [
            backCameraDiscoverySession.devices.first,
            frontCameraDiscoverySession.devices.first,
            externalCameraDiscoverySession.devices.first,
        ].compactMap { $0 }

        #if !targetEnvironment(simulator)
            if cameras.isEmpty {
                fatalError("No camera devices are found on this system")
            }
        #endif
        return cameras
    }
}
