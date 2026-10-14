/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
A compute kernel that draws a small picture into a full-size picture.
*/

#include <metal_stdlib>
using namespace metal;

/// The position and size of the small picture, in pixels of the output texture.
struct MixerParameters {
    float2 smallPicturePosition;
    float2 smallPictureSize;
};

/// A sampler that scales the small picture with linear filtering.
constant sampler linearSampler(filter::linear, coord::pixel, address::clamp_to_edge);

/// Writes one output pixel: from the small picture inside its frame, from the full picture elsewhere.
kernel void pictureInPictureMixer(texture2d<half, access::read> fullPicture [[ texture(0) ]],
                                  texture2d<half, access::sample> smallPicture [[ texture(1) ]],
                                  texture2d<half, access::write> output [[ texture(2) ]],
                                  const device MixerParameters& parameters [[ buffer(0) ]],
                                  uint2 position [[ thread_position_in_grid ]]) {
    // Stay inside the output texture; the grid can be larger than the texture.
    if (position.x >= output.get_width() || position.y >= output.get_height()) {
        return;
    }
    
    uint2 origin = uint2(parameters.smallPicturePosition);
    uint2 size = uint2(parameters.smallPictureSize);
    bool insideSmallPicture = position.x >= origin.x && position.y >= origin.y &&
                              position.x < origin.x + size.x && position.y < origin.y + size.y;
    
    half4 color;
    if (insideSmallPicture) {
        // Map the output pixel to a pixel of the small picture, which the sampler scales down.
        float2 scale = float2(smallPicture.get_width(), smallPicture.get_height()) / parameters.smallPictureSize;
        float2 source = float2(position - origin) * scale;
        color = smallPicture.sample(linearSampler, source + 0.5);
    } else {
        color = fullPicture.read(position);
    }
    output.write(color, position);
}
