//
//  CameraView.swift
//  AVCam
//
//  Created by Karol Kakol on 12/10/2026.
//

import SwiftUI


@MainActor
struct CameraView<CameraModel: Camera>: View {
    @State var camera: CameraModel
    var body: some View {
        ZStack {
            CameraPreview(source: camera.previewSource)
            StatusOverlayView(status: camera.status)
        }
    }
}

#Preview {
    CameraView(camera: PreviewCameraModel())
}
