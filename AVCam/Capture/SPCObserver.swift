//
//  SPCObserver.swift
//  AVCam
//
//  Created by Karol Kąkol on 15/10/2026.
//

import AVFoundation

class SystemPreferredCameraObserver: NSObject {
    
    private let systemPreferredKeyPath = "systemPreferredCamera"
    
    let changes: AsyncStream<AVCaptureDevice?>
    
    private var continuation: AsyncStream<AVCaptureDevice?>.Continuation?
    
    override init() {
        let (changes, continuation) = AsyncStream.makeStream(of: AVCaptureDevice?.self)
        
        self.changes = changes
        self.continuation = continuation
        
        super.init()
        
        AVCaptureDevice.self.addObserver(self, forKeyPath: systemPreferredKeyPath, options: [.new], context: nil)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        switch keyPath {
        case systemPreferredKeyPath:
            let newDevice = change?[.newKey] as? AVCaptureDevice
            continuation?.yield(newDevice)
        default:
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    deinit {
        continuation?.finish()
    }
    
}
