/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
A view that provides a container view around the camera preview.
*/

import SwiftUI

/// A view that provides a container view around the camera preview.
///
/// This view applies transition effects when changing capture modes or switching devices.
@MainActor
struct PreviewContainer<Content: View, CameraModel: Camera>: View {
    
    @State var camera: CameraModel
    
    // State values for transition effects.
    @State private var blurRadius = CGFloat.zero
    
    private let content: Content
    
    init(camera: CameraModel, @ViewBuilder content: () -> Content) {
        self.camera = camera
        self.content = content()
    }
    
    var body: some View {
        previewView
    }
    
    /// Attach animations to the camera preview.
    var previewView: some View {
        content
            .blur(radius: blurRadius, opaque: true)
            .onChange(of: camera.isSwitchingVideoDevices, updateBlurRadius(_:_:))
    }
    
    func updateBlurRadius(_: Bool, _ isSwitching: Bool) {
        withAnimation {
            blurRadius = isSwitching ? 30 : 0
        }
    }
}
