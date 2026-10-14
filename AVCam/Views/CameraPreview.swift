/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
A view that presents a video preview of the captured content.
*/

import SwiftUI
@preconcurrency import AVFoundation
import AVKit

struct CameraPreview: UIViewRepresentable {
    
    private let source: PreviewSource
    
    // A closure to call when the directions that the cameras face change.
    private let directionsHandler: @MainActor (CameraDirections) -> Void
    
    init(source: PreviewSource, onDirectionsChange directionsHandler: @escaping @MainActor (CameraDirections) -> Void = { _ in }) {
        self.source = source
        self.directionsHandler = directionsHandler
    }
    
    func makeUIView(context: Context) -> PreviewView {
        let preview = PreviewView()
        // Connect the preview layer to the capture session.
        source.connect(to: preview)
        // Report the directions that the cameras face in relation to the preview.
        preview.observeCameraDirections(with: directionsHandler)
        return preview
    }
    
    func updateUIView(_ previewView: PreviewView, context: Context) {
        // No-op.
    }
    
    /// A class that presents the captured content.
    ///
    /// This class owns the `AVCaptureVideoPreviewLayer` that presents the captured content.
    ///
    class PreviewView: UIView, PreviewTarget {
        
        init() {
            super.init(frame: .zero)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        // Use the preview layer as the view's backing layer.
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
        
        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
        
        // An object that reports the direction that each camera faces in relation to this view.
        // The type of the property is `AnyObject`, because the coordinator class needs iOS 27.1.
        private var directionCoordinator: AnyObject?
        
        /// Starts to observe the directions that the cameras face, and reports each change to the handler.
        func observeCameraDirections(with handler: @escaping @MainActor (CameraDirections) -> Void) {
            // Earlier systems don't have the coordinator. On those systems, the app uses the position of a camera.
            guard #available(iOS 27.1, *) else { return }
            directionCoordinator = AVCaptureDeviceDirectionCoordinator(view: self, deviceTypes: DeviceLookup.builtInCameraTypes) { directionMap in
                // The coordinator calls this handler on the main actor, soon after its creation and after each change.
                // A descriptor identifies a camera. Keep only the identifiers, which are safe to pass to the capture actor.
                let directions = CameraDirections(forwardFacing: directionMap.forwardFacingDeviceDescriptors.map(\.uniqueID),
                                                  backwardFacing: directionMap.backwardFacingDeviceDescriptors.map(\.uniqueID))
                MainActor.assumeIsolated {
                    handler(directions)
                }
            }
        }
        
        nonisolated func setSession(_ session: AVCaptureSession) {
            // Connects the session with the preview layer, which allows the layer
            // to provide a live view of the captured content.
            Task { @MainActor in
                previewLayer.session = session
            }
        }
    }
}

/// A protocol that enables a preview source to connect to a preview target.
///
/// The app provides an instance of this type to the client tier so it can connect
/// the capture session to the `PreviewView` view. It uses these protocols
/// to prevent explicitly exposing the capture objects to the UI layer.
///
protocol PreviewSource: Sendable {
    // Connects a preview destination to this source.
    func connect(to target: PreviewTarget)
}

/// A protocol that passes the app's capture session to the `CameraPreview` view.
protocol PreviewTarget {
    // Sets the capture session on the destination.
    func setSession(_ session: AVCaptureSession)
    // The layer that presents the captured content.
    @MainActor var previewLayer: AVCaptureVideoPreviewLayer { get }
}

/// A protocol that connects the two preview views of the dual mode with the multi-camera session.
protocol DualPreviewSource: Sendable {
    // Connects the preview views for the back camera and the front camera to this source.
    @MainActor func connect(back: PreviewTarget, front: PreviewTarget)
}

/// The app's default `DualPreviewSource` implementation.
struct DefaultDualPreviewSource: DualPreviewSource {
    
    private let captureService: CaptureService
    
    init(captureService: CaptureService) {
        self.captureService = captureService
    }
    
    @MainActor
    func connect(back: PreviewTarget, front: PreviewTarget) {
        let backLayer = back.previewLayer
        let frontLayer = front.previewLayer
        // The capture service connects the layers on its own queue.
        Task { await captureService.attachDualPreview(back: backLayer, front: frontLayer) }
    }
}

/// The app's default `PreviewSource` implementation.
struct DefaultPreviewSource: PreviewSource {
    
    private let session: AVCaptureSession
    
    init(session: AVCaptureSession) {
        self.session = session
    }
    
    func connect(to target: PreviewTarget) {
        target.setSession(session)
    }
}
