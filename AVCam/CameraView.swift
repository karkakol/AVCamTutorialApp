/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
The main user interface for the sample app.
*/

import SwiftUI

@MainActor
struct CameraView<CameraModel: Camera>: View {

    @State var camera: CameraModel

    var body: some View {
        ZStack {
            // A view that provides a preview of the captured content.
            CameraPreview(source: camera.previewSource)
            // A view that presents a status message over the camera preview.
            StatusOverlayView(status: camera.status)
        }
    }
}

#Preview {
    CameraView(camera: PreviewCameraModel())
}
