/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
A view that presents the main camera user interface.
*/

import SwiftUI

/// A view that presents the main camera user interface.
struct CameraUI<CameraModel: Camera>: View {

    @State var camera: CameraModel
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            MainToolbar(camera: camera)
        }
        .overlay {
            StatusOverlayView(status: camera.status)
        }
    }
}

#Preview {
    CameraUI(camera: PreviewCameraModel())
}
