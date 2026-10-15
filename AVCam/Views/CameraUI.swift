//
//  CameraUI.swift
//  AVCam
//
//  Created by Karol Kakol on 14/10/2026.
//

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
    PreviewBackground{
        CameraUI(camera: PreviewCameraModel())
    }
}
