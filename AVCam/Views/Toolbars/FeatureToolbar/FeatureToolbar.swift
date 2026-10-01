/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
A view that presents controls to enable capture features.
*/

import SwiftUI

/// A view that presents controls to enable capture features.
struct FeaturesToolbar<CameraModel: Camera>: PlatformView {
    
    @Environment(\.verticalSizeClass) var verticalSizeClass
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    @State var camera: CameraModel
    
    var body: some View {
        HStack(spacing: 30) {
            Spacer()
            switch camera.captureMode {
            case .photo:
                livePhotoButton
                prioritizePicker
                rawMenu
            case .video:
                if camera.isHDRVideoSupported {
                    hdrButton
                }
            }
        }
        .buttonStyle(DefaultButtonStyle(size: isRegularSize ? .large : .small))
        .padding([.leading, .trailing])
        // Hide them until the capture session runs, using a custom modifier.
        .hidden(until: camera.status == .running)
    }
    
    //  A button to toggle the enabled state of Live Photo capture.
    var livePhotoButton: some View {
        Button {
            camera.isLivePhotoEnabled.toggle()
        } label: {
            Image(systemName: camera.isLivePhotoEnabled ? "livephoto" : "livephoto.slash")
        }
    }
    
    @ViewBuilder
    var prioritizePicker: some View {
        Menu {
            Picker("Quality Prioritization", selection: $camera.qualityPrioritization) {
                ForEach(QualityPrioritization.allCases) {
                    Text($0.description)
                        .font(.body.weight(.bold))
                }
            }

        } label: {
            switch camera.qualityPrioritization {
            case .speed:
                Image(systemName: "dial.low")
            case .balanced:
                Image(systemName: "dial.medium")
            case .quality:
                Image(systemName: "dial.high")
            }
        }
    }
    
    /// The RAW formats that the current camera supports. A person can always turn RAW off.
    private var supportedRAWFormats: [RAWFormat] {
        RAWFormat.allCases.filter {
            switch $0 {
            case .off: true
            case .appleProRAW: camera.captureCapabilities.isAppleProRAWSupported
            case .bayerRAW: camera.captureCapabilities.isBayerRAWSupported
            }
        }
    }
    
    // A menu to choose the RAW format. The menu is hidden when the camera supports no RAW format.
    @ViewBuilder
    var rawMenu: some View {
        if supportedRAWFormats.count > 1 {
            Menu {
                Picker("RAW Format", selection: $camera.rawFormat) {
                    ForEach(supportedRAWFormats) {
                        Text($0.description)
                            .font(.body.weight(.bold))
                    }
                }
            } label: {
                Image(systemName: camera.rawFormat == .off ? "r.square" : "r.square.fill")
            }
        }
    }

    @ViewBuilder
    var hdrButton: some View {
        if isCompactSize {
            hdrToggleButton
        } else {
            hdrToggleButton
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
        }
    }
    
    var hdrToggleButton: some View {
        Button {
            camera.isHDRVideoEnabled.toggle()
        } label: {
            Text("HDR \(camera.isHDRVideoEnabled ? "On" : "Off")")
                .font(.body.weight(.semibold))
        }
        .disabled(camera.captureActivity.isRecording)
    }
}

#Preview {
    PreviewBackground {
        FeaturesToolbar(camera: PreviewCameraModel())
    }
}
