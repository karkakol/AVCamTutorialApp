/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
An object that writes video and audio sample buffers to a movie file.
*/

import AVFoundation

/// An object that writes sample buffers to a QuickTime movie file with an asset writer.
///
/// `AVCaptureMovieFileOutput` does this work by itself for one camera. For frames that the app makes
/// itself, the app has to write the file. `DualRecorder` calls this object on the data output queue.
final class MovieRecorder {
    
    private let writer: AVAssetWriter
    private let videoInput: AVAssetWriterInput
    private let audioInput: AVAssetWriterInput?
    
    /// The location of the movie file.
    var outputURL: URL { writer.outputURL }
    
    /// Creates a recorder that writes to a new temporary file.
    ///
    /// - Parameters:
    ///   - videoSettings: The compression settings for the video track, from the video data output.
    ///   - audioSettings: The compression settings for the audio track, or `nil` for a movie without sound.
    init(videoSettings: [String: Any], audioSettings: [String: Any]?) throws {
        writer = try AVAssetWriter(outputURL: .movieFileURL, fileType: .mov)
        
        // The inputs receive the frames in real time, so the writer must not wait for a full buffer.
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = true
        writer.add(videoInput)
        
        if let audioSettings {
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            input.expectsMediaDataInRealTime = true
            writer.add(input)
            audioInput = input
        } else {
            audioInput = nil
        }
    }
    
    /// Appends a video frame. The first frame starts the file and sets its time zero.
    func append(videoSampleBuffer: CMSampleBuffer) {
        if writer.status == .unknown {
            // Start the file at the time of the first frame, so that the movie starts without a gap.
            writer.startWriting()
            writer.startSession(atSourceTime: videoSampleBuffer.presentationTimeStamp)
        }
        guard writer.status == .writing, videoInput.isReadyForMoreMediaData else { return }
        videoInput.append(videoSampleBuffer)
    }
    
    /// Appends audio samples. Samples that arrive before the first video frame are dropped.
    func append(audioSampleBuffer: CMSampleBuffer) {
        guard writer.status == .writing, let audioInput, audioInput.isReadyForMoreMediaData else { return }
        audioInput.append(audioSampleBuffer)
    }
    
    /// Finishes the file and returns its location.
    func finish() async throws -> URL {
        guard writer.status == .writing else {
            throw writer.error ?? MovieCaptureError.notRecording
        }
        videoInput.markAsFinished()
        audioInput?.markAsFinished()
        await writer.finishWriting()
        if let error = writer.error {
            throw error
        }
        return writer.outputURL
    }
}
