/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
An object that manages a capture session and its inputs and outputs.
*/

import Foundation
@preconcurrency import AVFoundation
import Combine

/// An actor that manages the capture pipeline, which includes the capture session, device inputs, and capture outputs.
/// The app defines it as an `actor` type to ensure that all camera operations happen off of the `@MainActor`.
actor CaptureService {
    
    /// A value that indicates whether the capture service is idle or capturing a photo or movie.
    @Published private(set) var captureActivity: CaptureActivity = .idle
    /// A value that indicates whether the photo output can accept a new capture request.
    @Published private(set) var captureReadiness = CaptureReadiness.sessionNotRunning
    /// A value that indicates the current capture capabilities of the service.
    @Published private(set) var captureCapabilities = CaptureCapabilities.unknown
    /// A Boolean value that indicates whether a higher priority event, like receiving a phone call, interrupts the app.
    @Published private(set) var isInterrupted = false
    /// A Boolean value that indicates whether the user enables HDR video capture.
    @Published var isHDRVideoEnabled = false
    /// The zoom levels that the selected camera offers.
    @Published private(set) var zoomLevels = [ZoomLevel]()
    /// The zoom factor of the selected camera, as the value to show to a person.
    @Published private(set) var displayZoomFactor: CGFloat = 1.0
    /// A Boolean value that indicates whether capture controls are in a fullscreen appearance.
    @Published var isShowingFullscreenControls = false
    
    /// A type that connects a preview destination with the capture session.
    nonisolated let previewSource: PreviewSource
    
    /// A stream of the results of recordings that end without a request from the app.
    nonisolated let unexpectedRecordingResults: AsyncStream<Result<Movie, Error>>
    
    /// A type that connects the two preview views of the dual mode with the multi-camera session.
    nonisolated var dualPreviewSource: DualPreviewSource {
        DefaultDualPreviewSource(captureService: self)
    }
    
    // The app's capture session.
    private let captureSession = AVCaptureSession()
    
    // An object that manages the app's photo capture behavior.
    private let photoCapture = PhotoCapture()
    
    // An object that manages the app's video capture behavior.
    private let movieCapture = MovieCapture()
    
    // An object that manages the multi-camera session of the dual mode.
    private let multiCamCapture = MultiCamCapture()
    
    // The preview layers of the dual mode, as soon as the dual preview view exists.
    private var dualPreviewLayers: (back: AVCaptureVideoPreviewLayer, front: AVCaptureVideoPreviewLayer)?
    
    // An internal collection of output services.
    private var outputServices: [any OutputService] { [photoCapture, movieCapture] }
    
    // The video input for the currently selected device camera.
    private var activeVideoInput: AVCaptureDeviceInput?
    
    // The mode of capture, either photo or video. Defaults to photo.
    private(set) var captureMode = CaptureMode.photo
    
    // An object the service uses to retrieve capture devices.
    private let deviceLookup = DeviceLookup()
    
    // The directions that the cameras face in relation to the preview, if the system reports them.
    private var cameraDirections: CameraDirections?
    
    // A Boolean value that indicates whether the person selected a camera that faces them.
    private var isForwardFacingCameraSelected = false
    
    // An object that monitors the state of the system-preferred camera.
    private let systemPreferredCamera = SystemPreferredCameraObserver()
    
    // An object that monitors video device rotations.
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator!
    private var rotationObservers = [AnyObject]()
    
    // An observation of the zoom factor of the selected camera.
    private var zoomObserver: NSKeyValueObservation?
    
    // The largest zoom factor that the app offers, as a display value.
    private let maxDisplayZoomFactor: CGFloat = 10.0
    
    // A Boolean value that indicates whether the actor finished its required configuration.
    private var isSetUp = false
    
    // A delegate object that responds to capture control activation and presentation events.
    private var controlsDelegate = CaptureControlsDelegate()
    
    // A map that stores capture controls by device identifier.
    private var controlsMap: [String: [AVCaptureControl]] = [:]
    
    // A serial dispatch queue to use for capture control actions.
    private let sessionQueue = DispatchSerialQueue(label: "com.karolkakol.AVCam.sessionQueue")
    
    // Sets the session queue as the actor's executor.
    nonisolated var unownedExecutor: UnownedSerialExecutor {
        sessionQueue.asUnownedSerialExecutor()
    }
    
    init() {
        // Create a source object to connect the preview view with the capture session.
        previewSource = DefaultPreviewSource(session: captureSession)
        // Pass on the stream of the movie capture service.
        unexpectedRecordingResults = movieCapture.unexpectedResults
    }
    
    // MARK: - Authorization
    /// A Boolean value that indicates whether a person authorizes this app to use
    /// device cameras and microphones. If they haven't previously authorized the
    /// app, querying this property prompts them for authorization.
    var isAuthorized: Bool {
        get async {
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            // Determine whether a person previously authorized camera access.
            var isAuthorized = status == .authorized
            // If the system hasn't determined their authorization status,
            // explicitly prompt them for approval.
            if status == .notDetermined {
                isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
            }
            return isAuthorized
        }
    }
    
    // MARK: - Capture session life cycle
    func start(with state: CameraState) async throws {
        // Set initial operating state. A device that can't run two cameras starts in photo mode.
        captureMode = state.captureMode == .dual && !MultiCamCapture.isSupported ? .photo : state.captureMode
        isHDRVideoEnabled = state.isVideoHDREnabled
        
        // Exit early if not authorized or the session is already running.
        guard await isAuthorized, !captureSession.isRunning else { return }
        // Configure the session and start it. In the dual mode, the multi-camera session runs instead.
        try setUpSession()
        if captureMode == .dual {
            startDualCaptureIfNeeded()
        } else {
            captureSession.startRunning()
        }
    }
    
    // MARK: - Capture setup
    // Performs the initial capture session configuration.
    private func setUpSession() throws {
        // Return early if already set up.
        guard !isSetUp else { return }

        // Observe internal state and notifications.
        observeOutputServices()
        observeNotifications()
        observeCaptureControlsState()
        
        do {
            // Retrieve the default camera and microphone.
            let defaultCamera = try deviceLookup.defaultCamera
            let defaultMic = try deviceLookup.defaultMic

            // Enable using AirPods as a high-quality lapel microphone.
            captureSession.configuresApplicationAudioSessionForBluetoothHighQualityRecording = true

            // Add inputs for the default camera and microphone devices.
            activeVideoInput = try addInput(for: defaultCamera)
            try addInput(for: defaultMic)

            // Configure the session preset based on the current capture mode.
            captureSession.sessionPreset = captureMode == .video ? .high : .photo

            // Deferred start brings up the preview first, and prepares the capture outputs a moment
            // later. An app that links the iOS 26 SDK gets this behavior by default; these
            // assignments show the properties that control it.
            captureSession.automaticallyRunsDeferredStart = true

            // Add the photo capture output as the default output type.
            photoCapture.output.isDeferredStartEnabled = photoCapture.output.isDeferredStartSupported
            try addOutput(photoCapture.output)
            // If the capture mode is set to `video`, add a movie capture output.
            if captureMode == .video {
                // Add the movie output as the default output type.
                movieCapture.output.isDeferredStartEnabled = movieCapture.output.isDeferredStartSupported
                try addOutput(movieCapture.output)
                setHDRVideoEnabled(isHDRVideoEnabled)
            }
            
            // Configure controls to use with the Camera Control.
            configureControls(for: defaultCamera)
            // Configure the zoom levels for the default camera.
            configureZoom(for: defaultCamera)
            // Monitor the system-preferred camera state.
            monitorSystemPreferredCamera()
            // Configure a rotation coordinator for the default video device.
            createRotationCoordinator(for: defaultCamera)
            // Observe changes to the default camera's subject area.
            observeSubjectAreaChanges(of: defaultCamera)
            // Update the service's advertised capabilities.
            updateCaptureCapabilities()
            
            isSetUp = true
            
            // The app can start with a front camera, for example when a person selected it in the last session.
            updateSelectedDirection(for: defaultCamera)
            // The directions can arrive before the setup is complete. Apply them now.
            applyCameraDirections()
        } catch {
            throw CameraError.setupFailed
        }
    }

    // Adds an input to the capture session to connect the specified capture device.
    @discardableResult
    private func addInput(for device: AVCaptureDevice) throws -> AVCaptureDeviceInput {
        let input = try AVCaptureDeviceInput(device: device)
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        } else {
            throw CameraError.addInputFailed
        }
        return input
    }
    
    // Adds an output to the capture session to connect the specified capture device, if allowed.
    private func addOutput(_ output: AVCaptureOutput) throws {
        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
        } else {
            throw CameraError.addOutputFailed
        }
    }
    
    // The device for the active video input.
    private var currentDevice: AVCaptureDevice {
        guard let device = activeVideoInput?.device else {
            fatalError("No device found for current video input.")
        }
        return device
    }
    
    // MARK: - Capture controls
    
    private func configureControls(for device: AVCaptureDevice) {
        
        // Exit early if the host device doesn't support capture controls.
        guard captureSession.supportsControls else { return }
        
        // Begin configuring the capture session.
        captureSession.beginConfiguration()
        
        // Remove previously configured controls, if any.
        for control in captureSession.controls {
            captureSession.removeControl(control)
        }
        
        // Create controls and add them to the capture session.
        for control in createControls(for: device) {
            if captureSession.canAddControl(control) {
                captureSession.addControl(control)
            } else {
                logger.info("Unable to add control \(control).")
            }
        }
        
        // Set the controls delegate.
        captureSession.setControlsDelegate(controlsDelegate, queue: sessionQueue)
        
        // Commit the capture session configuration.
        captureSession.commitConfiguration()
    }
    
    func createControls(for device: AVCaptureDevice) -> [AVCaptureControl] {
        // Retrieve the capture controls for this device, if they exist.
        guard let controls = controlsMap[device.uniqueID] else {
            // Define the default controls.
            var controls = [
                AVCaptureSystemZoomSlider(device: device),
                AVCaptureSystemExposureBiasSlider(device: device)
            ]
            // Create a lens position control if the device supports setting a custom position.
            if device.isLockingFocusWithCustomLensPositionSupported {
                // Create a slider to adjust the value from 0 to 1.
                let lensSlider = AVCaptureSlider("Lens Position", symbolName: "circle.dotted.circle", in: 0...1)
                // Perform the slider's action on the session queue.
                lensSlider.setActionQueue(sessionQueue) { lensPosition in
                    do {
                        try device.lockForConfiguration()
                        device.setFocusModeLocked(lensPosition: lensPosition)
                        device.unlockForConfiguration()
                    } catch {
                        logger.info("Unable to change the lens position: \(error)")
                    }
                }
                // Add the slider the controls array.
                controls.append(lensSlider)
            }
            // Store the controls for future use.
            controlsMap[device.uniqueID] = controls
            return controls
        }
        
        // Return the previously created controls.
        return controls
    }
    
    // MARK: - Zoom
    
    /// Creates the zoom levels for the specified device, and starts the device at the 1x level.
    private func configureZoom(for device: AVCaptureDevice) {
        // The ratio between the zoom factor of the device and the value that the system shows to a person.
        let multiplier = displayMultiplier(for: device)
        
        // The first level is the widest field of view of the device. A zoom factor is never less than 1.
        var factors = [max(device.minAvailableVideoZoomFactor, 1.0)]
        // A virtual device changes to its next camera at each switch-over zoom factor.
        factors += device.virtualDeviceSwitchOverVideoZoomFactors.map { CGFloat(truncating: $0) }
        // A device with one level gets a 2x level, if it can zoom that far.
        if factors.count == 1, device.maxAvailableVideoZoomFactor >= factors[0] * 2 {
            factors.append(factors[0] * 2)
        }
        zoomLevels = factors.map { ZoomLevel(videoZoomFactor: $0, displayFactor: $0 * multiplier) }
        
        // Start at the level that a person sees as 1x. On a virtual device with an
        // ultra-wide camera, the smallest zoom factor shows the 0.5x field of view.
        setVideoZoomFactor(1.0 / multiplier, on: device, animated: false)
        
        // Observe the zoom factor, because the Camera Control and a zoom ramp also change it.
        zoomObserver = device.observe(\.videoZoomFactor, options: [.initial, .new]) { [weak self] device, _ in
            let zoomFactor = device.videoZoomFactor
            Task { await self?.updateDisplayZoomFactor(for: zoomFactor, of: device) }
        }
    }
    
    private func updateDisplayZoomFactor(for zoomFactor: CGFloat, of device: AVCaptureDevice) {
        displayZoomFactor = zoomFactor * displayMultiplier(for: device)
    }
    
    /// Returns the ratio between the zoom factor of the device and the value to show to a person.
    private func displayMultiplier(for device: AVCaptureDevice) -> CGFloat {
        // Some devices, such as a simulated camera, report no multiplier. Use 1 for them.
        let multiplier = device.displayVideoZoomFactorMultiplier
        return multiplier > 0 ? multiplier : 1.0
    }
    
    /// Changes the zoom to the specified level with a smooth transition.
    func setZoom(to level: ZoomLevel) {
        setVideoZoomFactor(level.videoZoomFactor, on: currentDevice, animated: true)
    }
    
    /// Changes the zoom to the specified display value immediately.
    ///
    /// The app calls this method many times during a pinch gesture.
    func setZoom(displayFactor: CGFloat) {
        let device = currentDevice
        setVideoZoomFactor(displayFactor / displayMultiplier(for: device), on: device, animated: false)
    }
    
    private func setVideoZoomFactor(_ factor: CGFloat, on device: AVCaptureDevice, animated: Bool) {
        // A device that cannot zoom, such as a simulated camera, reports a largest zoom factor of less than 1.
        guard device.maxAvailableVideoZoomFactor >= 1.0 else { return }
        // Keep the value in the range that the device supports. A value outside of the range raises an exception.
        let smallestFactor = max(device.minAvailableVideoZoomFactor, 1.0)
        let largestFactor = max(min(device.maxAvailableVideoZoomFactor, maxDisplayZoomFactor / displayMultiplier(for: device)), smallestFactor)
        let factor = min(max(factor, smallestFactor), largestFactor)
        do {
            try device.lockForConfiguration()
            if animated {
                // Move to the new value at a constant rate. The rate doubles the zoom factor this many times each second.
                device.ramp(toVideoZoomFactor: factor, withRate: 8.0)
            } else {
                device.videoZoomFactor = factor
            }
            device.unlockForConfiguration()
        } catch {
            logger.debug("Unable to change the zoom factor: \(error)")
        }
    }
    
    // MARK: - Capture mode selection
    
    /// Changes the mode of capture, which can be `photo` or `video`.
    ///
    /// - Parameter `captureMode`: The capture mode to enable.
    func setCaptureMode(_ captureMode: CaptureMode) throws {
        let previousMode = self.captureMode
        // Update the internal capture mode value before performing the session configuration.
        self.captureMode = captureMode
        
        if captureMode == .dual {
            // Two sessions can't run at the same time. Stop the single-camera session, then start the multi-camera session.
            captureSession.stopRunning()
            startDualCaptureIfNeeded()
            updateCaptureCapabilities()
            return
        }
        
        // Stop the multi-camera session before the single-camera session starts again.
        let restartsSession = previousMode == .dual
        if restartsSession {
            multiCamCapture.stop()
        }
        
        // Change the configuration atomically.
        captureSession.beginConfiguration()
        defer {
            captureSession.commitConfiguration()
            // Start the session again after the configuration is committed.
            if restartsSession {
                captureSession.startRunning()
            }
        }
        
        // Configure the capture session for the selected capture mode.
        switch captureMode {
        case .photo:
            // The app needs to remove the movie capture output to perform Live Photo capture.
            captureSession.sessionPreset = .photo
            captureSession.removeOutput(movieCapture.output)
        case .video:
            captureSession.sessionPreset = .high
            try addOutput(movieCapture.output)
            // Adding the output creates a new connection. Give it the current capture rotation angle.
            updateCaptureRotation(rotationCoordinator.videoRotationAngleForHorizonLevelCapture)
            if isHDRVideoEnabled {
                setHDRVideoEnabled(true)
            }
        case .dual:
            // The dual mode returns above.
            break
        }

        // Update the advertised capabilities after reconfiguration.
        updateCaptureCapabilities()
        // A new session preset can select a new device format. Create the zoom levels again.
        configureZoom(for: currentDevice)
    }
    
    // MARK: - Dual capture
    
    /// Stores the preview layers of the dual mode, and starts the multi-camera session if the dual mode is active.
    ///
    /// The app calls this method when the dual preview view appears.
    func attachDualPreview(back: AVCaptureVideoPreviewLayer, front: AVCaptureVideoPreviewLayer) {
        dualPreviewLayers = (back, front)
        startDualCaptureIfNeeded()
    }
    
    /// Configures and starts the multi-camera session when the dual mode is active and the preview layers exist.
    private func startDualCaptureIfNeeded() {
        guard captureMode == .dual, let layers = dualPreviewLayers, MultiCamCapture.isSupported else { return }
        let cameras = deviceLookup.cameras
        guard let backCamera = cameras.first(where: { $0.position == .back }),
              let frontCamera = cameras.first(where: { $0.position == .front }) else {
            logger.error("The dual mode needs a back camera and a front camera.")
            return
        }
        do {
            try multiCamCapture.configure(backCamera: backCamera, frontCamera: frontCamera,
                                          backPreview: layers.back, frontPreview: layers.front)
        } catch {
            logger.error("Unable to configure the multi-camera session: \(error)")
            return
        }
        multiCamCapture.start()
        logger.info("Dual capture costs: hardware \(self.multiCamCapture.hardwareCost), system pressure \(self.multiCamCapture.systemPressureCost)")
    }
    
    // MARK: - Device selection
    
    /// Changes the capture device that provides video input.
    ///
    /// The app calls this method in response to the user tapping the button in the UI to change cameras.
    /// The implementation switches between the front and back cameras and, in iPadOS,
    /// connected external cameras.
    func selectNextVideoDevice() {
        // The array of available video capture devices.
        let videoDevices = deviceLookup.cameras

        // Find the index of the currently selected video device.
        let selectedIndex = videoDevices.firstIndex(of: currentDevice) ?? 0
        // Get the next index.
        var nextIndex = selectedIndex + 1
        // Wrap around if the next index is invalid.
        if nextIndex == videoDevices.endIndex {
            nextIndex = 0
        }
        
        let nextDevice = videoDevices[nextIndex]
        // Change the session's active capture device.
        changeCaptureDevice(to: nextDevice)
        
        // Keep the direction of the selection, so that the app can follow it when the directions change.
        updateSelectedDirection(for: nextDevice)
        
        // The app only calls this method in response to the user requesting to switch cameras.
        // Set the new selection as the user's preferred camera.
        AVCaptureDevice.userPreferredCamera = nextDevice
    }
    
    // Changes the device the service uses for video capture.
    private func changeCaptureDevice(to device: AVCaptureDevice) {
        // The service must have a valid video input prior to calling this method.
        guard let currentInput = activeVideoInput else { fatalError() }
        
        // Bracket the following configuration in a begin/commit configuration pair.
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        
        // Remove the existing video input before attempting to connect a new one.
        captureSession.removeInput(currentInput)
        do {
            // Attempt to connect a new input and device to the capture session.
            activeVideoInput = try addInput(for: device)
            // Configure capture controls for new device selection.
            configureControls(for: device)
            // Configure the zoom levels for the new device.
            configureZoom(for: device)
            // Configure a new rotation coordinator for the new device.
            createRotationCoordinator(for: device)
            // Register for device observations.
            observeSubjectAreaChanges(of: device)
            // Update the service's advertised capabilities.
            updateCaptureCapabilities()
            // A new input creates a new preview connection. Set its mirroring again.
            updatePreviewMirroring()
        } catch {
            // Reconnect the existing camera on failure.
            captureSession.addInput(currentInput)
        }
    }
    
    // MARK: - Camera directions
    
    /// Stores the directions that the cameras face in relation to the preview.
    ///
    /// The app calls this method when the preview view reports new directions, for
    /// example after a person opens or closes iPhone Duo.
    func setCameraDirections(_ directions: CameraDirections) {
        cameraDirections = directions
        // Before the setup, the session has no camera. The setup applies the directions later.
        guard isSetUp else { return }
        applyCameraDirections()
    }
    
    /// Stores the direction that the specified camera faces as the direction that the person selected.
    private func updateSelectedDirection(for device: AVCaptureDevice) {
        // Without a report from the system, use the position of the camera.
        isForwardFacingCameraSelected = cameraDirections?.forwardFacing.contains(device.uniqueID) ?? (device.position == .front)
    }
    
    /// Changes the camera if the selected one no longer faces the selected direction.
    private func applyCameraDirections() {
        guard let directions = cameraDirections else { return }
        let selectedID = currentDevice.uniqueID
        // Only follow the cameras that the system reports a direction for. It reports no direction
        // for an external camera, or for the virtual front camera, which the system moves by itself.
        guard directions.forwardFacing.contains(selectedID) || directions.backwardFacing.contains(selectedID) else { return }
        
        // The cameras that face the direction that the person selected.
        let candidates = isForwardFacingCameraSelected ? directions.forwardFacing : directions.backwardFacing
        if !candidates.contains(selectedID), let device = deviceLookup.camera(withUniqueIDIn: candidates) {
            logger.debug("Switching camera selection, because the selected camera changed its direction.")
            changeCaptureDevice(to: device)
        } else {
            updatePreviewMirroring()
        }
    }
    
    /// Mirrors the preview when the position of the selected camera and its direction disagree.
    private func updatePreviewMirroring() {
        guard let directions = cameraDirections else { return }
        let device = currentDevice
        let isFacingForward = directions.forwardFacing.contains(device.uniqueID)
        let isFacingBackward = directions.backwardFacing.contains(device.uniqueID)
        let isFrontCamera = device.position == .front
        
        // The connection mirrors the preview of each camera with the front position by itself.
        // Take over only when a back camera faces the person, or a front camera faces the scene.
        let needsOverride = (isFacingForward && !isFrontCamera) || (isFacingBackward && isFrontCamera)
        
        let connection = videoPreviewLayer.connection
        Task { @MainActor in
            // Assigning `isVideoMirrored` raises an exception when the connection doesn't support mirroring.
            guard let connection, connection.isVideoMirroringSupported else { return }
            if needsOverride {
                // Assigning `isVideoMirrored` raises an exception while automatic adjustment stays on.
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = isFacingForward
            } else {
                // Position and direction agree again. Give the mirroring back to the connection.
                connection.automaticallyAdjustsVideoMirroring = true
            }
        }
    }
    
    /// Monitors changes to the system's preferred camera selection.
    ///
    /// iPadOS supports external cameras. When someone connects an external camera to their iPad,
    /// they're signaling the intent to use the device. The system responds by updating the
    /// system-preferred camera (SPC) selection to this new device. When this occurs, if the SPC
    /// isn't the currently selected camera, switch to the new device.
    private func monitorSystemPreferredCamera() {
        Task {
            // An object monitors changes to system-preferred camera (SPC) value.
            for await camera in systemPreferredCamera.changes {
                // If the SPC isn't the currently selected camera, attempt to change to that device.
                if let camera, currentDevice != camera {
                    logger.debug("Switching camera selection to the system-preferred camera.")
                    changeCaptureDevice(to: camera)
                }
            }
        }
    }
    
    // MARK: - Rotation handling
    
    /// Create a new rotation coordinator for the specified device and observe its state to monitor rotation changes.
    private func createRotationCoordinator(for device: AVCaptureDevice) {
        // Create a new rotation coordinator for this device.
        rotationCoordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: videoPreviewLayer)
        
        // Set initial rotation state on the preview and output connections.
        updatePreviewRotation(rotationCoordinator.videoRotationAngleForHorizonLevelPreview)
        updateCaptureRotation(rotationCoordinator.videoRotationAngleForHorizonLevelCapture)
        
        // Cancel previous observations.
        rotationObservers.removeAll()
        
        // Add observers to monitor future changes.
        rotationObservers.append(
            rotationCoordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: .new) { [weak self] _, change in
                guard let self, let angle = change.newValue else { return }
                // Update the capture preview rotation.
                Task { await self.updatePreviewRotation(angle) }
            }
        )
        
        rotationObservers.append(
            rotationCoordinator.observe(\.videoRotationAngleForHorizonLevelCapture, options: .new) { [weak self] _, change in
                guard let self, let angle = change.newValue else { return }
                // Update the capture preview rotation.
                Task { await self.updateCaptureRotation(angle) }
            }
        )
    }
    
    private func updatePreviewRotation(_ angle: CGFloat) {
        let connection = videoPreviewLayer.connection
        Task { @MainActor in
            // Set initial rotation angle on the video preview.
            connection?.videoRotationAngle = angle
        }
    }
    
    private func updateCaptureRotation(_ angle: CGFloat) {
        // Update the orientation for all output services.
        outputServices.forEach { $0.setVideoRotationAngle(angle) }
    }
    
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        // Access the capture session's connected preview layer.
        guard let previewLayer = captureSession.connections.compactMap({ $0.videoPreviewLayer }).first else {
            fatalError("The app is misconfigured. The capture session should have a connection to a preview layer.")
        }
        return previewLayer
    }
    
    // MARK: - Automatic focus and exposure
    
    /// Performs a one-time automatic focus and expose operation.
    ///
    /// The app calls this method as the result of a person tapping on the preview area.
    func focusAndExpose(at point: CGPoint) {
        // The point this call receives is in view-space coordinates. Convert this point to device coordinates.
        let devicePoint = videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: point)
        do {
            // Perform a user-initiated focus and expose.
            try focusAndExpose(at: devicePoint, isUserInitiated: true)
        } catch {
            logger.debug("Unable to perform focus and exposure operation. \(error)")
        }
    }
    
    // Observe notifications of type `subjectAreaDidChangeNotification` for the specified device.
    private func observeSubjectAreaChanges(of device: AVCaptureDevice) {
        // Cancel the previous observation task.
        subjectAreaChangeTask?.cancel()
        subjectAreaChangeTask = Task {
            // Signal true when this notification occurs.
            for await _ in NotificationCenter.default.notifications(named: AVCaptureDevice.subjectAreaDidChangeNotification, object: device).compactMap({ _ in true }) {
                // Perform a system-initiated focus and expose.
                try? focusAndExpose(at: CGPoint(x: 0.5, y: 0.5), isUserInitiated: false)
            }
        }
    }
    private var subjectAreaChangeTask: Task<Void, Never>?
    
    private func focusAndExpose(at devicePoint: CGPoint, isUserInitiated: Bool) throws {
        // Configure the current device.
        let device = currentDevice
        
        // The following mode and point of interest configuration requires obtaining an exclusive lock on the device.
        try device.lockForConfiguration()
        
        let focusMode = isUserInitiated ? AVCaptureDevice.FocusMode.autoFocus : .continuousAutoFocus
        if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(focusMode) {
            device.focusPointOfInterest = devicePoint
            device.focusMode = focusMode
        }
        
        let exposureMode = isUserInitiated ? AVCaptureDevice.ExposureMode.autoExpose : .continuousAutoExposure
        if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(exposureMode) {
            device.exposurePointOfInterest = devicePoint
            device.exposureMode = exposureMode
        }
        // Enable subject-area change monitoring when performing a user-initiated automatic focus and exposure operation.
        // If this method enables change monitoring, when the device's subject area changes, the app calls this method a
        // second time and resets the device to continuous automatic focus and exposure.
        device.isSubjectAreaChangeMonitoringEnabled = isUserInitiated
        
        // Release the lock.
        device.unlockForConfiguration()
    }
    
    // MARK: - Photo capture
    func capturePhoto(with features: PhotoFeatures) async throws -> Photo {
        try await photoCapture.capturePhoto(with: features)
    }
    
    // MARK: - Movie capture
    /// Starts recording video. The video records until the user stops recording,
    /// which calls the following `stopRecording()` method.
    func startRecording() {
        movieCapture.startRecording()
    }

    /// Stops the recording and returns the captured movie.
    func stopRecording() async throws -> Movie {
        try await movieCapture.stopRecording()
    }

    /// Sets whether the app captures HDR video.
    func setHDRVideoEnabled(_ isEnabled: Bool) {
        // Bracket the following configuration in a begin/commit configuration pair.
        captureSession.beginConfiguration()
        defer { captureSession.commitConfiguration() }
        do {
            // If the current device provides a 10-bit HDR format, enable it for use.
            if isEnabled, let format = currentDevice.activeFormat10BitVariant {
                try currentDevice.lockForConfiguration()
                currentDevice.activeFormat = format
                currentDevice.unlockForConfiguration()
                isHDRVideoEnabled = true
            } else {
                captureSession.sessionPreset = .high
                isHDRVideoEnabled = false
            }
        } catch {
            logger.error("Unable to obtain lock on device and can't enable HDR video capture.")
        }
    }
    
    // MARK: - Internal state management
    /// Updates the state of the actor to ensure its advertised capabilities are accurate.
    ///
    /// When the capture session changes, such as changing modes or input devices, the service
    /// calls this method to update its configuration and capabilities. The app uses this state to
    /// determine which features to enable in the user interface.
    private func updateCaptureCapabilities() {
        // Update the output service configuration.
        outputServices.forEach { $0.updateConfiguration(for: currentDevice) }
        // Set the capture service's capabilities for the selected mode.
        switch captureMode {
        case .photo:
            captureCapabilities = photoCapture.capabilities
        case .video:
            captureCapabilities = movieCapture.capabilities
        case .dual:
            captureCapabilities = .unknown
        }
    }
    
    /// Merge the `captureActivity` values of the photo and movie capture services,
    /// and assign the value to the actor's property.`
    private func observeOutputServices() {
        Publishers.Merge(photoCapture.$captureActivity, movieCapture.$captureActivity)
            .assign(to: &$captureActivity)
        photoCapture.$captureReadiness
            .assign(to: &$captureReadiness)
    }
    
    /// Observe when capture control enter and exit a fullscreen appearance.
    private func observeCaptureControlsState() {
        controlsDelegate.$isShowingFullscreenControls
            .assign(to: &$isShowingFullscreenControls)
    }
    
    /// Observe capture-related notifications.
    private func observeNotifications() {
        Task {
            for await reason in NotificationCenter.default.notifications(named: AVCaptureSession.wasInterruptedNotification)
                .compactMap({ $0.userInfo?[AVCaptureSessionInterruptionReasonKey] as AnyObject? })
                .compactMap({ AVCaptureSession.InterruptionReason(rawValue: $0.integerValue) }) {
                /// Set the `isInterrupted` state as appropriate.
                isInterrupted = [.audioDeviceInUseByAnotherClient, .videoDeviceInUseByAnotherClient].contains(reason)
            }
        }
        
        Task {
            // Await notification of the end of an interruption.
            for await _ in NotificationCenter.default.notifications(named: AVCaptureSession.interruptionEndedNotification) {
                isInterrupted = false
            }
        }
        
        Task {
            for await error in NotificationCenter.default.notifications(named: AVCaptureSession.runtimeErrorNotification)
                .compactMap({ $0.userInfo?[AVCaptureSessionErrorKey] as? AVError }) {
                // If the system resets media services, the capture session stops running.
                if error.code == .mediaServicesWereReset {
                    if !captureSession.isRunning {
                        captureSession.startRunning()
                    }
                }
            }
        }
    }
}

class CaptureControlsDelegate: NSObject, AVCaptureSessionControlsDelegate {
    
    @Published private(set) var isShowingFullscreenControls = false

    func sessionControlsDidBecomeActive(_ session: AVCaptureSession) {
        logger.debug("Capture controls active.")
    }

    func sessionControlsWillEnterFullscreenAppearance(_ session: AVCaptureSession) {
        isShowingFullscreenControls = true
        logger.debug("Capture controls will enter fullscreen appearance.")
    }
    
    func sessionControlsWillExitFullscreenAppearance(_ session: AVCaptureSession) {
        isShowingFullscreenControls = false
        logger.debug("Capture controls will exit fullscreen appearance.")
    }
    
    func sessionControlsDidBecomeInactive(_ session: AVCaptureSession) {
        logger.debug("Capture controls inactive.")
    }
}
