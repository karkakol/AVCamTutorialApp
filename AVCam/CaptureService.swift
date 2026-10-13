//
//  CaptureService.swift
//  AVCam
//
//  Created by Karol Kakol on 08/10/2026.
//

import Foundation
@preconcurrency import AVFoundation

actor CaptureService {
    nonisolated let previewSource: PreviewSource
    
    private let captureSession = AVCaptureSession()
    
    private let sessionQueue = DispatchSerialQueue(label: "\(Bundle.main.bundleIdentifier).sessionQueue")
    
    nonisolated var unownedExecutor: UnownedSerialExecutor {
        sessionQueue.asUnownedSerialExecutor()
    }
    
    init() {
        previewSource = DefaultPreviewSource(session: captureSession)
    }
    
    var isAuthorized: Bool {
        get async {
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            
            var isAuthorized = status == .authorized
            
            if status == .notDetermined {
                isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
            }
            return isAuthorized
        }
    }
    
    func start() async throws {
        guard await isAuthorized, !captureSession.isRunning else { return }
        try setUpSessino()
        captureSession.startRunning()
    }
    
    private func setUpSessino() throws {
        do {
            guard let defaultCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                throw CameraError.videoDeviceUnavailable
            }
            
            try addInput(for: defaultCamera)
            
        } catch {
            throw CameraError.setupFailed
        }
    }
    
    @discardableResult
    private func addInput(for device: AVCaptureDevice) throws -> AVCaptureDeviceInput {
        let input = try AVCaptureDeviceInput(device: device)
        if captureSession.canAddInput(input){
            captureSession.addInput(input)
        } else {
            throw CameraError.addInputFailed
        }
        return input
    }
    
}
