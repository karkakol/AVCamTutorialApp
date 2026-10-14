/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
A view that shows the back camera and the front camera at the same time.
*/

import SwiftUI
@preconcurrency import AVFoundation

/// A view that shows one camera full screen and the other camera in a small picture.
///
/// A tap on the view exchanges the two pictures.
struct DualCameraPreview: View {
    
    private let source: DualPreviewSource
    
    // The camera that the small picture shows.
    @State private var smallPicture = AVCaptureDevice.Position.front
    
    init(source: DualPreviewSource) {
        self.source = source
    }
    
    var body: some View {
        DualPreviewViews(source: source, smallPicture: smallPicture)
            .onTapGesture {
                // Exchange the full picture and the small picture, on the screen and in the recording.
                smallPicture = smallPicture == .front ? .back : .front
                source.setSmallPicture(smallPicture)
            }
    }
}

/// A view that hosts the two preview views and places one of them in a corner.
struct DualPreviewViews: UIViewRepresentable {
    
    let source: DualPreviewSource
    let smallPicture: AVCaptureDevice.Position
    
    func makeUIView(context: Context) -> DualPreviewContainer {
        let container = DualPreviewContainer()
        // Connect the two preview layers to the multi-camera session.
        source.connect(back: container.backPreview, front: container.frontPreview)
        return container
    }
    
    func updateUIView(_ container: DualPreviewContainer, context: Context) {
        container.smallPicture = smallPicture
    }
    
    /// A view that contains the two preview views and lays them out.
    class DualPreviewContainer: UIView {
        
        let backPreview = CameraPreview.PreviewView()
        let frontPreview = CameraPreview.PreviewView()
        
        // The size of the small picture, as a part of the width of this view.
        private let smallPictureScale = 0.3
        private let inset = CGFloat(16)
        
        var smallPicture = AVCaptureDevice.Position.front {
            didSet {
                guard smallPicture != oldValue else { return }
                UIView.animate(withDuration: 0.25) {
                    self.layoutPreviews()
                }
            }
        }
        
        init() {
            super.init(frame: .zero)
            backgroundColor = .black
            for preview in [backPreview, frontPreview] {
                // Fill the picture, so that a small picture has no black bars.
                preview.previewLayer.videoGravity = .resizeAspectFill
                preview.layer.cornerRadius = 12
                preview.layer.borderColor = UIColor.white.cgColor
                preview.clipsToBounds = true
                addSubview(preview)
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            layoutPreviews()
        }
        
        // Gives one preview the full bounds and the other preview a corner.
        private func layoutPreviews() {
            let small = smallPicture == .front ? frontPreview : backPreview
            let full = smallPicture == .front ? backPreview : frontPreview
            let width = bounds.width * smallPictureScale
            let height = width * bounds.height / max(bounds.width, 1)
            full.frame = bounds
            full.layer.cornerRadius = 0
            full.layer.borderWidth = 0
            small.frame = CGRect(x: inset, y: safeAreaInsets.top + inset, width: width, height: height)
            small.layer.cornerRadius = 12
            small.layer.borderWidth = 1
            // Draw the small picture on top of the full picture.
            bringSubviewToFront(small)
        }
    }
}
