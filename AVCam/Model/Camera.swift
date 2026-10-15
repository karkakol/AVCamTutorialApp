//
//  Camera.swift
//  AVCam
//
//  Created by Karol Kakol on 09/10/2026.
//

import SwiftUI

@MainActor
protocol Camera: AnyObject, SendableMetatype {
    var status: CameraStatus { get }
    var previewSource: PreviewSource { get }
    func start() async
    
    var isSwitchingVideoDevices: Bool { get }
    func switchVideoDevices() async
}
