//
//  MainToolbar.swift
//  AVCam
//
//  Created by Karol Kakol on 14/10/2026.
//

import SwiftUI

struct MainToolbar<CameraModel: Camera>: View {
    @State var camera: CameraModel
    
    var body: some View {
        HStack {
            Spacer()
            SwitchCameraButton(camera: camera)
        }
        .foregroundStyle(.white)
        .font(.system(size: 24))
        .frame(height: height)
        .padding([.leading, .trailing])
    }
    
    var height: CGFloat? { 80 }
}

#Preview {
    PreviewBackground{
        MainToolbar(camera: PreviewCameraModel())
    }
}
