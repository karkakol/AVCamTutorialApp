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
    
    // The outputs that deliver the frames of each camera and the samples of the microphone.
    private let backVideoOutput = AVCaptureVideoDataOutput()
    private let frontVideoOutput = AVCaptureVideoDataOutput()
    private let audioOutput = AVCaptureAudioDataOutput()
    
    /// The object that mixes and records the frames of the two cameras.
    private(set) var recorder: DualRecorder?
    
    // A Boolean value that indicates whether the session has its inputs and connections.
    private(set) var isConfigured = false
    
    // The largest width of a camera format that the dual mode uses. Two large formats cost more than the hardware can give.
    private let maxFormatWidth: Int32 = 1920
    
    // MARK: - Configuration
    
    /// Adds the two cameras and the microphone to the session, and connects each camera to its own preview layer and data output.
    func configure(backCamera: AVCaptureDevice, frontCamera: AVCaptureDevice, microphone: AVCaptureDevice?,
                   backPreview: AVCaptureVideoPreviewLayer, frontPreview: AVCaptureVideoPreviewLayer) throws {
        // Configure the session one time only.
        guard !isConfigured else { return }
        
        // Change the configuration atomically.
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        
        // The recorder receives the sample buffers of the three outputs.
        let hasMicrophone = microphone != nil
        let recorder = DualRecorder(backOutput: backVideoOutput, frontOutput: frontVideoOutput,
                                    audioOutput: hasMicrophone ? audioOutput : nil)
        self.recorder = recorder
        
        backInput = try addCamera(backCamera, previewLayer: backPreview, videoOutput: backVideoOutput, recorder: recorder)
        frontInput = try addCamera(frontCamera, previewLayer: frontPreview, videoOutput: frontVideoOutput, recorder: recorder)
        if let microphone {
            try addMicrophone(microphone, recorder: recorder)
        }
        
        isConfigured = true
    }
    
    // Adds an input for a camera, and connections from the camera to a preview layer and to a video data output.
    private func addCamera(_ device: AVCaptureDevice, previewLayer: AVCaptureVideoPreviewLayer,
                           videoOutput: AVCaptureVideoDataOutput, recorder: DualRecorder) throws -> AVCaptureDeviceInput {
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
        
        // Add a data output for this camera, and connect it to the same port. The output delivers
        // each frame to the recorder on the data output queue.
        guard session.canAddOutput(videoOutput) else {
            throw CameraError.addOutputFailed
        }
        session.addOutputWithNoConnections(videoOutput)
        // The mixer reads BGRA pixels. Ask the output for that format, so that no conversion is needed later.
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.setSampleBufferDelegate(recorder, queue: recorder.dataOutputQueue)
        
        let outputConnection = AVCaptureConnection(inputPorts: [videoPort], output: videoOutput)
        guard session.canAddConnection(outputConnection) else {
            throw CameraError.addOutputFailed
        }
        session.addConnection(outputConnection)
        // The recorded frames need the same mirroring and rotation as the preview.
        if outputConnection.isVideoMirroringSupported {
            outputConnection.automaticallyAdjustsVideoMirroring = false
            outputConnection.isVideoMirrored = device.position == .front
        }
        outputConnection.videoRotationAngle = rotationCoordinator.videoRotationAngleForHorizonLevelCapture
        
        return input
    }
    
    // Adds an input for the microphone and a connection to an audio data output.
    private func addMicrophone(_ microphone: AVCaptureDevice, recorder: DualRecorder) throws {
        let input = try AVCaptureDeviceInput(device: microphone)
        guard session.canAddInput(input) else {
            throw CameraError.addInputFailed
        }
        session.addInputWithNoConnections(input)
        
        // The microphone has one port per direction. Use the port that faces the scene with the back camera.
        guard let audioPort = input.ports(for: .audio, sourceDeviceType: microphone.deviceType, sourceDevicePosition: .back).first
                ?? input.ports.first(where: { $0.mediaType == .audio }) else {
            throw CameraError.addInputFailed
        }
        guard session.canAddOutput(audioOutput) else {
            throw CameraError.addOutputFailed
        }
        session.addOutputWithNoConnections(audioOutput)
        audioOutput.setSampleBufferDelegate(recorder, queue: recorder.dataOutputQueue)
        
        let connection = AVCaptureConnection(inputPorts: [audioPort], output: audioOutput)
        guard session.canAddConnection(connection) else {
            throw CameraError.addOutputFailed
        }
        session.addConnection(connection)
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
    
    // MARK: - Recording
    
    /// Tells the recorder which camera is in the small picture.
    func setSmallPicture(_ position: AVCaptureDevice.Position) {
        guard let recorder else { return }
        recorder.dataOutputQueue.async {
            recorder.smallPicture = position
        }
    }
    
    /// Starts a recording of the mixed pictures.
    func startRecording() throws {
        guard let recorder, session.isRunning else { return }
        try recorder.dataOutputQueue.sync {
            try recorder.startRecording()
        }
    }
    
    /// Stops the recording and returns the movie.
    func stopRecording() async throws -> Movie {
        guard let recorder else { throw MovieCaptureError.notRecording }
        // Detach the movie recorder on the data output queue, so that no frame arrives after this point.
        guard let movieRecorder = recorder.dataOutputQueue.sync(execute: { recorder.stopRecording() }) else {
            throw MovieCaptureError.notRecording
        }
        let url = try await movieRecorder.finish()
        return Movie(url: url)
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
