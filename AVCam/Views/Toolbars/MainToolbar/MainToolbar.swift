/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
A view that displays controls to capture, switch cameras, and view the last captured media item.
*/

import SwiftUI

/// A view that displays controls to capture, switch cameras, and view the last captured media item.
struct MainToolbar<CameraModel: Camera>: View {

    @State var camera: CameraModel
    
    var body: some View {
        HStack {
            Spacer()
            SwitchCameraButton(camera: camera)
        }
        .foregroundColor(.white)
        .font(.system(size: 24))
        .frame(height: height)
        .padding([.leading, .trailing])
    }
    
    var height: CGFloat? { 80 }
}

#Preview {
    Group {
        MainToolbar(camera: PreviewCameraModel())
    }
}
