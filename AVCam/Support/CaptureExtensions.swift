/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
Extensions on AVFoundation capture and related types.
*/

import AVFoundation

extension CMVideoDimensions: @retroactive Equatable, @retroactive Comparable {
    
    static let zero = CMVideoDimensions()
    
    public static func == (lhs: CMVideoDimensions, rhs: CMVideoDimensions) -> Bool {
        lhs.width == rhs.width && lhs.height == rhs.height
    }
    
    public static func < (lhs: CMVideoDimensions, rhs: CMVideoDimensions) -> Bool {
        lhs.width < rhs.width && lhs.height < rhs.height
    }
}
