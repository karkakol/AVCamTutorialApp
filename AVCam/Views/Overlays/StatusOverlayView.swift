/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
A view that presents a status message over the camera user interface.
*/

import SwiftUI

/// A view that presents a status message over the camera user interface.
struct StatusOverlayView: View {
	
	let status: CameraStatus
    let handled: [CameraStatus] = [.unauthorized, .failed]
    
	var body: some View {
		if handled.contains(status) {
			// Dimming view.
			Rectangle()
				.fill(Color(white: 0.0, opacity: 0.5))
			// Status message.
			Text(message)
				.font(.headline)
                .foregroundColor(color == .yellow ? .init(white: 0.25) : .white)
				.padding()
				.background(color)
				.cornerRadius(8.0)
                .frame(maxWidth: 600)
		}
	}
	
	var color: Color {
		switch status {
		case .unauthorized:
			return .red
		case .failed:
			return .orange
		default:
			return .clear
		}
	}
	
	var message: String {
		switch status {
		case .unauthorized:
			return "You haven't authorized AVCam to use the camera or microphone. Change these settings in Settings -> Privacy & Security"
		case .failed:
			return "The camera failed to start. Please try relaunching the app."
		default:
			return ""
		}
	}
}

#Preview("Failed") {
    CameraView(camera: PreviewCameraModel(status: .failed))
}

#Preview("Unauthorized") {
    CameraView(camera: PreviewCameraModel(status: .unauthorized))
}
