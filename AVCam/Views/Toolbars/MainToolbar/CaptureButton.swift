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
    @State var isRecording = false
    
    private let mainButtonDimension: CGFloat = 68
    
    var body: some View {
        captureButton
            .aspectRatio(1.0, contentMode: .fit)
            .frame(width: mainButtonDimension)
            // Respond to recording state changes that occur from hardware button presses.
            .onChange(of: camera.captureActivity.isRecording) { _, newValue in
                // Ensure the button animation occurs when toggling recording state from a hardware button.
                withAnimation(.easeInOut(duration: 0.25)) {
                    isRecording = newValue
                }
            }
    }
    
    @ViewBuilder
    var captureButton: some View {
        switch camera.captureMode {
        case .photo:
            PhotoCaptureButton(readiness: camera.captureReadiness) {
                Task {
                    await camera.capturePhoto()
                }
            }
        case .video:
            MovieCaptureButton(isRecording: $isRecording) { _ in
                Task {
                    await camera.toggleRecording()
                }
            }
        }
    }
}

#Preview("Photo") {
    PreviewBackground {
        CaptureButton(camera: PreviewCameraModel(captureMode: .photo))
    }
}

#Preview("Video") {
    PreviewBackground {
        CaptureButton(camera: PreviewCameraModel(captureMode: .video))
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

private struct MovieCaptureButton: View {
    
    private let action: (Bool) -> Void
    private let lineWidth = CGFloat(4.0)
    
    @Binding private var isRecording: Bool
    
    init(isRecording: Binding<Bool>, action: @escaping (Bool) -> Void) {
        _isRecording = isRecording
        self.action = action
    }
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: lineWidth)
                .foregroundColor(Color.white)
            Button {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isRecording.toggle()
                }
                action(isRecording)
            } label: {
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: geometry.size.width / (isRecording ? 4.0 : 2.0))
                        .inset(by: lineWidth * 1.2)
                        .fill(.red)
                        .scaleEffect(isRecording ? 0.6 : 1.0)
                }
            }
            .buttonStyle(NoFadeButtonStyle())
        }
    }
    
    struct NoFadeButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
        }
    }
}
