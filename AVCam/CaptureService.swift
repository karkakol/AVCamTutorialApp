//
//  CaptureService.swift
//  AVCam
//
//  Created by Karol Kakol on 08/10/2026.
//

@preconcurrency import AVFoundation
import Foundation

actor CaptureService {
    nonisolated let previewSource: PreviewSource

    private let captureSession = AVCaptureSession()

    private let sessionQueue = DispatchSerialQueue(
        label: "\(Bundle.main.bundleIdentifier).sessionQueue"
    )

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

    private func getAllCaptureDevices() -> [AVCaptureDevice] {
        var deviceTypes: [AVCaptureDevice.DeviceType] = [
            // Physical cameras
            .builtInWideAngleCamera,
            .builtInUltraWideCamera,
            .builtInTelephotoCamera,

            // Virtual cameras
            .builtInDualCamera,
            .builtInDualWideCamera,
            .builtInTripleCamera,

            // Micriphone
            .microphone,
        ]

        if #available(iOS 15.4, *) {
            deviceTypes.append(.builtInLiDARDepthCamera)
        }

        if #available(iOS 17.0, *) {
            deviceTypes.append(.continuityCamera)
        }

        #if os(iOS)
            if #available(iOS 17.0, *) {
                deviceTypes.append(.external)
            }
        #elseif os(macOS)
            deviceTypes.append(.externalUnknown)
        #endif

        if #available(iOS 27.1, *) {
            deviceTypes.append(.builtInInnerUltraWideCamera)
            deviceTypes.append(.builtInOuterUltraWideCamera)
        }

        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: nil,
            position: .unspecified
        )

        return discoverySession.devices
    }

    private func listAllCaptureDevices() {
        print(String(repeating: "=", count: 50))
        print("All camera devices: ")
        for device in getAllCaptureDevices() {
            print()
            if device.isVirtualDevice {
                print("\(device.localizedName) is Virtual")
                print(
                    "Underlying physical cameras: ",
                    device.constituentDevices
                )
            } else {
                print("\(device.localizedName) is Physical")
            }
            print("\(device.modelID) model ID")
            print("\(device.uniqueID) unique ID")

        }
        print(String(repeating: "=", count: 50))
    }

    private func setUpSessino() throws {
        listAllCaptureDevices()
        do {
            guard
                let defaultCamera = AVCaptureDevice.default(
                    .builtInWideAngleCamera,
                    for: .video,
                    position: .front
                )
            else {
                throw CameraError.videoDeviceUnavailable
            }

            try addInput(for: defaultCamera)

        } catch {
            throw CameraError.setupFailed
        }
    }

    @discardableResult
    private func addInput(for device: AVCaptureDevice) throws
        -> AVCaptureDeviceInput
    {
        let input = try AVCaptureDeviceInput(device: device)
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        } else {
            throw CameraError.addInputFailed
        }
        return input
    }

}
