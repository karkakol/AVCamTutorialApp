//
//  PreviewContainer.swift
//  AVCam
//
//  Created by Karol Kakol on 15/10/2026.
//

import SwiftUI

struct PreviewContainer<Content: View, CameraModel: Camera>: View {
    @State var camera: CameraModel
    private let content: Content
    
    @State private var blurRadius = CGFloat.zero
    
    init(camera: CameraModel, @ViewBuilder content: () -> Content) {
        self.camera = camera
        self.content = content()
    }
    
    var body: some View {
        previewView
    }
    
    var previewView: some View {
        content.blur(radius: blurRadius, opaque: true)
            .onChange(of: camera.isSwitchingVideoDevices, updateBlurRadius(_:_:))
    }
    
    func updateBlurRadius(_: Bool, _ isSwitching: Bool){
        withAnimation {
            blurRadius = isSwitching ? 30 : 0
        }
    }
}

#Preview {
    PreviewContainer(
        camera: PreviewCameraModel(),
        content: {}
    )
}
