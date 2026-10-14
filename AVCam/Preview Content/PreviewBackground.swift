/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
A background for Xcode previews that stands in for the camera picture.
*/

import SwiftUI

/// A view that stands in for the camera picture in Xcode previews.
///
/// The controls of the app are translucent and sit on the live camera picture. On the black
/// canvas of a preview, their dark backgrounds are invisible. This view puts a gray gradient
/// behind its content, so that a preview shows each control completely.
struct PreviewBackground<Content: View>: View {
    
    @ViewBuilder let content: Content
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(white: 0.45), Color(white: 0.2)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            content
        }
    }
}
