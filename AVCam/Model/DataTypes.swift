/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
Supporting data types for the app.
*/

import AVFoundation

// MARK: - Supporting types

/// An enumeration that describes the current status of the camera.
enum CameraStatus {
    /// The initial status upon creation.
    case unknown
    /// A status that indicates a person disallows access to the camera or microphone.
    case unauthorized
    /// A status that indicates the camera failed to start.
    case failed
    /// A status that indicates the camera is successfully running.
    case running
}

enum CameraError: Error {
    case videoDeviceUnavailable
    case addInputFailed
    case setupFailed
}
