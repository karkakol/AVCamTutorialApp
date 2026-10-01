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
            // A container view that manages the placement of the preview.
            PreviewContainer(camera: camera) {
                // A view that provides a preview of the captured content.
                CameraPreview(source: camera.previewSource)
            }
            // The main camera user interface.
            CameraUI(camera: camera)
        }
    }
}

#Preview {
    PreviewBackground {
        CameraView(camera: PreviewCameraModel())
    }
}
