/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
Extensions and supporting SwiftUI types.
*/

import SwiftUI
import UIKit

let largeButtonSize = CGSize(width: 64, height: 64)

@MainActor
protocol PlatformView: View {
    var verticalSizeClass: UserInterfaceSizeClass? { get }
    var horizontalSizeClass: UserInterfaceSizeClass? { get }
    var isRegularSize: Bool { get }
    var isCompactSize: Bool { get }
}

extension PlatformView {
    var isRegularSize: Bool { horizontalSizeClass == .regular && verticalSizeClass == .regular }
    var isCompactSize: Bool { horizontalSizeClass == .compact || verticalSizeClass == .compact }
}

struct DefaultButtonStyle: ButtonStyle {
    
    @Environment(\.isEnabled) private var isEnabled: Bool
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    enum Size: CGFloat {
        case small = 22
        case large = 24
    }
    
    private let size: Size
    
    init(size: Size) {
        self.size = size
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isEnabled ? .primary : Color(white: 0.4))
            .font(.system(size: size.rawValue))
            // Pad buttons on devices that use the `regular` size class,
            // and also when explicitly requesting large buttons.
            .padding(isRegularSize || size == .large ? 10.0 : 0)
            .background(.black.opacity(0.4))
            .clipShape(size == .small ? AnyShape(Rectangle()) : AnyShape(Circle()))
    }
    
    var isRegularSize: Bool {
        horizontalSizeClass == .regular && verticalSizeClass == .regular
    }
}

extension View {
    /// Hides this view until the capture session is running.
    ///
    /// The app applies this to its controls so that it doesn't show UI until it's
    /// functional, and so the preview is the first thing to appear at launch.
    func hidden(until isRunning: Bool) -> some View {
        opacity(isRunning ? 1 : 0)
            .animation(.easeIn(duration: 0.3), value: isRunning)
    }
}

extension Image {
    init(_ image: CGImage) {
        self.init(uiImage: UIImage(cgImage: image))
    }
}
