/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
The main user interface for the sample app.
*/

import SwiftUI
import AVFoundation
import AVKit

@MainActor
struct CameraView<CameraModel: Camera>: PlatformView {

    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass

    @State var camera: CameraModel

    // The direction a person swipes on the camera preview or mode selector.
    @State var swipeDirection = SwipeDirection.left
    
    // The zoom factor at the start of a pinch gesture.
    @State private var pinchStartFactor: CGFloat?

    var body: some View {
        ZStack {
            // A container view that manages the placement of the preview.
            PreviewContainer(camera: camera) {
                // A view that provides a preview of the captured content.
                CameraPreview(source: camera.previewSource)
                    // Handle capture events from device hardware buttons.
                    .onCameraCaptureEvent(defaultSoundDisabled: true) { event in
                        if event.phase == .ended {
                            let sound: AVCaptureEventSound
                            switch camera.captureMode {
                            case .photo:
                                sound = .cameraShutter
                            case .video:
                                sound = camera.captureActivity.isRecording ?
                                    .endVideoRecording : .beginVideoRecording
                            }
                            // Play a sound when capturing by clicking an AirPods stem. Play it before
                            // the capture, so that the person hears it at the moment of the click.
                            if event.shouldPlaySound {
                                event.play(sound)
                            }
                            switch camera.captureMode {
                            case .photo:
                                // Capture a photo when pressing a hardware button.
                                await camera.capturePhoto()
                            case .video:
                                // Toggle video recording when pressing a hardware button.
                                await camera.toggleRecording()
                            }
                        }
                    }
                    // Focus and expose at the tapped point.
                    .onTapGesture { location in
                        Task { await camera.focusAndExpose(at: location) }
                    }
                    // Switch between capture modes by swiping left and right.
                    .simultaneousGesture(swipeGesture)
                    // Zoom in and out with two fingers.
                    .simultaneousGesture(pinchGesture)
                    /// The value of `shouldFlashScreen` changes briefly to `true` when capture
                    /// starts, and then immediately changes to `false`. Use this change to
                    /// flash the screen to provide visual feedback when capturing photos.
                    .opacity(camera.shouldFlashScreen ? 0 : 1)
            }
            // The main camera user interface.
            CameraUI(camera: camera, swipeDirection: $swipeDirection)
        }
    }

    var pinchGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                // Keep the zoom factor from the start of the gesture, and scale it by the gesture's value.
                let startFactor = pinchStartFactor ?? camera.displayZoomFactor
                pinchStartFactor = startFactor
                Task { await camera.setZoom(displayFactor: startFactor * value.magnification) }
            }
            .onEnded { _ in
                pinchStartFactor = nil
            }
    }
    
    var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 50)
            .onEnded {
                // Capture swipe direction.
                swipeDirection = $0.translation.width < 0 ? .left : .right
            }
    }
}

#Preview {
    PreviewBackground {
        CameraView(camera: PreviewCameraModel())
    }
}

enum SwipeDirection {
    case left
    case right
    case up
    case down
}
