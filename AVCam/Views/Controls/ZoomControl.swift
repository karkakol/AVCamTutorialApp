/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
A view that shows the zoom levels of the camera and changes the zoom.
*/

import SwiftUI

/// A view that shows the zoom levels of the camera and changes the zoom.
struct ZoomControl<CameraModel: Camera>: View {
    
    @State var camera: CameraModel
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(camera.zoomLevels) { level in
                Button {
                    Task {
                        await camera.setZoom(to: level)
                    }
                } label: {
                    label(for: level)
                }
            }
        }
        .padding(4)
        .background(.black.opacity(0.25), in: Capsule())
        .animation(.easeInOut(duration: 0.2), value: selectedLevel)
        // A camera with one zoom level needs no control.
        .opacity(camera.zoomLevels.count > 1 ? 1 : 0)
        // Hide the zoom control when a person interacts with capture controls.
        .opacity(camera.prefersMinimizedUI ? 0 : 1)
        // Hide it until the capture session runs, using a custom modifier.
        .hidden(until: camera.status == .running)
    }
    
    /// The level that contains the current zoom factor.
    private var selectedLevel: ZoomLevel? {
        // A small tolerance prevents a wrong selection because of rounding.
        camera.zoomLevels.last { $0.displayFactor <= camera.displayZoomFactor + 0.01 } ?? camera.zoomLevels.first
    }
    
    @ViewBuilder
    private func label(for level: ZoomLevel) -> some View {
        let isSelected = level == selectedLevel
        // The selected level shows the current zoom factor, which can be between two levels.
        Text(isSelected ? "\(ZoomLevel.label(for: camera.displayZoomFactor))×" : level.label)
            .font(.system(size: isSelected ? 13 : 11, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(isSelected ? .yellow : .white)
            .frame(width: isSelected ? 40 : 30, height: isSelected ? 40 : 30)
            .background(.black.opacity(0.5), in: Circle())
    }
}

#Preview {
    ZoomControl(camera: PreviewCameraModel(status: .running))
        .padding()
        .background(.gray)
}
