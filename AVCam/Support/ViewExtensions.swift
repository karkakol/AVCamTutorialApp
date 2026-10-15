//
//  ViewExtensions.swift
//  AVCam
//
//  Created by Karol Kakol on 14/10/2026.
//

import SwiftUI
import UIKit
let largeButtonSize = CGSize(width: 64, height: 64)

struct DefayltButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled: Bool
    @Environment(\.verticalSizeClass) private var vertialSizeClass
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    enum Size: CGFloat {
        case small = 22
        case large = 24
    }
    
    private let size: Size
    
    init(size: Size){
        self.size = size
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(isEnabled ? .primary : Color(white: 0.4))
            .font(.system(size: size.rawValue))
            .padding(isRegularSize || size == .large ? 10.0: 0)
            .background(.black.opacity(0.4))
            .clipShape(size == .small ? AnyShape(Rectangle()) : AnyShape(Circle()))
    }
    
    var isRegularSize: Bool {
        horizontalSizeClass == .regular && vertialSizeClass == .regular
    }
}
