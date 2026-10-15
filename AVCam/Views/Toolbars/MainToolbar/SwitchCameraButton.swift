//
//  SwitchCameraButton.swift
//  AVCam
//
//  Created by Karol Kakol on 14/10/2026.
//

import SwiftUI

struct SwitchCameraButton<CameraModel: Camera>: View {
    @State var camera: CameraModel
    var body: some View {
        Button {
            Task {
                await camera.switchVideoDevices()
            }
        } label: {
            Image(systemName: "arrow.triangle.2.circlepath")
        }
        .buttonStyle(DefayltButtonStyle(size: .large))
        .frame(width: largeButtonSize.width, height: largeButtonSize.height)
        .allowsHitTesting(!camera.isSwitchingVideoDevices)
    }
}

#Preview {
    PreviewBackground{
        SwitchCameraButton(camera: PreviewCameraModel())
    }
}
