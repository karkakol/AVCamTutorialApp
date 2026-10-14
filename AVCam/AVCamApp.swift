//
//  AVCamApp.swift
//  AVCam
//
//  Created by Karol Kakol on 01/10/2026.
//

import os
import SwiftUI

@main
struct AVCamApp: App {
    
    @State private var camera = CameraModel()
    
    var body: some Scene {
        WindowGroup {
            CameraView(camera: camera)
                .statusBarHidden(true)
                .task {
                    
                    await camera.start()
                }
        }
    }
}

let logger = Logger()
