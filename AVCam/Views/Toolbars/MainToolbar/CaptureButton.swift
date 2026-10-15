/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
A view that displays an appropriate capture button for the selected capture mode.
*/

import SwiftUI

/// A view that displays an appropriate capture button for the selected mode.
@MainActor
struct CaptureButton<CameraModel: Camera>: View {
    
    @State var camera: CameraModel
    
    private let mainButtonDimension: CGFloat = 68
    
    var body: some View {
        captureButton
            .aspectRatio(1.0, contentMode: .fit)
            .frame(width: mainButtonDimension)
    }
    
    @ViewBuilder
    var captureButton: some View {
        PhotoCaptureButton(readiness: camera.captureReadiness) {
            Task {
                await camera.capturePhoto()
            }
        }
    }
}

#Preview("Photo") {
    PreviewBackground {
        CaptureButton(camera: PreviewCameraModel())
    }
}

#Preview("Waiting for processing") {
    PreviewBackground {
        let camera = PreviewCameraModel()
        let _ = camera.captureReadiness = .notReadyWaitingForProcessing
        CaptureButton(camera: camera)
    }
}

private struct PhotoCaptureButton: View {
    private let readiness: CaptureReadiness
    private let action: () -> Void
    private let lineWidth = CGFloat(4.0)
    
    init(readiness: CaptureReadiness, action: @escaping () -> Void) {
        self.readiness = readiness
        self.action = action
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: lineWidth)
                .fill(.white)
            Button {
                action()
            } label: {
                Circle()
                    .inset(by: lineWidth * 1.2)
                    .fill(.white)
            }
            .buttonStyle(PhotoButtonStyle())
            // Disable the button while the photo output is busy capturing or processing.
            // The button stays enabled when the output is momentarily not ready, because the state is short.
            .disabled(readiness.isCaptureButtonDisabled)
            if readiness == .notReadyWaitingForProcessing {
                // Show a progress indicator while the photo output processes a capture.
                ProgressView()
                    .tint(.black)
            }
        }
        // Dim the button in the two waiting states.
        .opacity(readiness.isCaptureButtonDisabled ? 0.5 : 1.0)
    }
    
    struct PhotoButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? 0.85 : 1.0)
                .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
        }
    }
}
