//
//  Datatypes.swift
//  AVCam
//
//  Created by Karol Kakol on 08/10/2026.
//

import AVFoundation

enum CameraStatus {
    case unknown
    case unauthorized
    case failed
    case running
}

enum CameraError: Error {
    case videoDeviceUnavailable
    case addInputFailed
    case setupFailed
}
