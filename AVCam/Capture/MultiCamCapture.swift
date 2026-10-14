/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
An object that manages a multi-camera session to capture from two cameras at the same time.
*/

import AVFoundation

/// An object that manages a multi-camera session, which captures from the back camera and the front camera at the same time.
///
/// `CaptureService` owns this object and calls it on the session queue. The multi-camera
/// session is a second session; the app runs it only in the dual capture mode.
final class MultiCamCapture {
    
    /// A Boolean value that indicates whether the device can capture from two cameras at the same time.
    static var isSupported: Bool {
        AVCaptureMultiCamSession.isMultiCamSupported
    }
    
    /// The multi-camera session.
    let session = AVCaptureMultiCamSession()
    
    // The inputs for the two cameras.
    private var backInput: AVCaptureDeviceInput?
    private var frontInput: AVCaptureDeviceInput?
    
    // A Boolean value that indicates whether the session has its inputs and connections.
    private(set) var isConfigured = false
    
    // The largest width of a camera format that the dual mode uses. Two large formats cost more than the hardware can give.
    private let maxFormatWidth: Int32 = 1920
    
    // MARK: - Configuration
    
    /// Adds the two cameras to the session and connects each one to its own preview layer.
    func configure(backCamera: AVCaptureDevice, frontCamera: AVCaptureDevice,
                   backPreview: AVCaptureVideoPreviewLayer, frontPreview: AVCaptureVideoPreviewLayer) throws {
        // Configure the session one time only.
        guard !isConfigured else { return }
        
        // Change the configuration atomically.
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        
        backInput = try addCamera(backCamera, previewLayer: backPreview)
        frontInput = try addCamera(frontCamera, previewLayer: frontPreview)
        
        isConfigured = true
    }
    
    // Adds an input for a camera and a connection from the camera to a preview layer.
    private func addCamera(_ device: AVCaptureDevice, previewLayer: AVCaptureVideoPreviewLayer) throws -> AVCaptureDeviceInput {
        // Select a format that works in a multi-camera session before the camera joins it.
        try selectMultiCamFormat(for: device)
        
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            throw CameraError.addInputFailed
        }
        // Add the input without connections. The session must not connect the camera to every output.
        session.addInputWithNoConnections(input)
        
        // The video port of the input carries the frames of this camera.
        guard let videoPort = input.ports(for: .video, sourceDeviceType: device.deviceType, sourceDevicePosition: device.position).first else {
            throw CameraError.addInputFailed
        }
        
        // Give the preview layer the session without a connection, then connect it to this camera only.
        previewLayer.setSessionWithNoConnection(session)
        let connection = AVCaptureConnection(inputPort: videoPort, videoPreviewLayer: previewLayer)
        guard session.canAddConnection(connection) else {
            throw CameraError.addOutputFailed
        }
        session.addConnection(connection)
        
        // A connection that the app creates gets no automatic settings. Mirror the front camera only,
        // as a person expects from a selfie, and turn the picture upright for the current orientation.
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = device.position == .front
        }
        let rotationCoordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
        connection.videoRotationAngle = rotationCoordinator.videoRotationAngleForHorizonLevelPreview
        
        return input
    }
    
    /// Selects the largest format of the device that supports multi-camera capture, up to the width limit.
    private func selectMultiCamFormat(for device: AVCaptureDevice) throws {
        // Keep the active format if it already fits.
        if device.activeFormat.isMultiCamSupported && device.activeFormat.formatDescription.dimensions.width <= maxFormatWidth {
            return
        }
        let candidates = device.formats.filter {
            $0.isMultiCamSupported && $0.formatDescription.dimensions.width <= maxFormatWidth
        }
        // Prefer the widest format, and among equal widths the one with the highest frame rate.
        guard let format = candidates.max(by: {
            ($0.formatDescription.dimensions.width, $0.maxFrameRate) < ($1.formatDescription.dimensions.width, $1.maxFrameRate)
        }) else {
            throw CameraError.setupFailed
        }
        try device.lockForConfiguration()
        device.activeFormat = format
        device.unlockForConfiguration()
    }
    
    // MARK: - Costs
    
    /// The cost of the session configuration for the hardware. A value above 1 means that the session can't run.
    var hardwareCost: Float {
        session.hardwareCost
    }
    
    /// The cost of the session configuration for the system. A value above 1 means that the device can overheat.
    var systemPressureCost: Float {
        session.systemPressureCost
    }
    
    // MARK: - Session life cycle
    
    /// Starts the flow of data from the two cameras.
    func start() {
        guard isConfigured, !session.isRunning else { return }
        session.startRunning()
    }
    
    /// Stops the flow of data.
    func stop() {
        guard session.isRunning else { return }
        session.stopRunning()
    }
}
