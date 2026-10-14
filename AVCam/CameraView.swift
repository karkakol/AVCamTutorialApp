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
    
    // The difference between the safe area insets at the two sides of the screen.
    @State private var sideInsetDifference = CGFloat.zero
    
    // The zoom factor at the start of a pinch gesture.
    @State private var pinchStartFactor: CGFloat?

    var body: some View {
        ZStack {
            // A container view that manages the placement of the preview.
            PreviewContainer(camera: camera) {
                // A view that provides a preview of the captured content. The capture service needs its
                // preview connection in every mode, so the view stays in place when the dual mode covers it.
                CameraPreview(source: camera.previewSource) { directions in
                    // Tell the camera which way each camera faces now.
                    Task { await camera.setCameraDirections(directions) }
                }
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
                            case .dual:
                                // The dual mode captures nothing yet.
                                return
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
                            case .dual:
                                break
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
                    // In the dual mode, a view that shows both cameras covers the single preview.
                    .overlay {
                        if camera.captureMode == .dual {
                            DualCameraPreview(source: camera.dualPreviewSource)
                                // Switch between capture modes by swiping left and right.
                                .simultaneousGesture(swipeGesture)
                        }
                    }
            }
            // The main camera user interface.
            CameraUI(camera: camera, swipeDirection: $swipeDirection)
        }
        // iPhone Duo shows its status items in an area at one side of the display. The safe area
        // leaves that area out, so the interface isn't in the center of the display. Use the full
        // width, and give both sides the same space.
        .padding(.horizontal, sideInsetDifference / 2)
        .ignoresSafeArea(.container, edges: .horizontal)
        .onGeometryChange(for: CGFloat.self) { proxy in
            // Round the value. A layout pass can change an inset by a very small amount, and
            // a new value starts a new layout pass.
            abs(proxy.safeAreaInsets.trailing - proxy.safeAreaInsets.leading).rounded()
        } action: { difference in
            sideInsetDifference = difference
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
