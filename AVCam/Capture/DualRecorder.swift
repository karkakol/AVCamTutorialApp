/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
An object that receives the frames of two cameras, mixes them, and records them.
*/

import AVFoundation
import Combine

/// An object that receives the sample buffers of the dual mode, mixes the two pictures, and records a movie.
///
/// The data outputs call this object on their queue, `dataOutputQueue`. `MultiCamCapture` calls
/// `startRecording()` and `stopRecording()` on the same queue, so no lock is needed.
final class DualRecorder: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    
    /// A value that indicates the current state of movie capture.
    @Published private(set) var captureActivity: CaptureActivity = .idle
    
    /// The serial queue on which the outputs deliver their sample buffers.
    let dataOutputQueue = DispatchQueue(label: "com.karolkakol.AVCam.dataOutputQueue")
    
    /// The camera that the small picture shows. The other camera fills the frame.
    var smallPicture = AVCaptureDevice.Position.front
    
    // The outputs, so that the recorder knows which camera a frame comes from.
    private let backOutput: AVCaptureVideoDataOutput
    private let frontOutput: AVCaptureVideoDataOutput
    private let audioOutput: AVCaptureAudioDataOutput?
    
    private let mixer = PiPVideoMixer()
    private var recorder: MovieRecorder?
    
    // The last frame of the camera in the small picture.
    private var latestSmallPictureFrame: CMSampleBuffer?
    // The time of the first recorded frame, to compute the recording time.
    private var recordingStartTime: CMTime?
    // The last recording time that the recorder reported.
    private var reportedDuration = TimeInterval.zero
    
    init(backOutput: AVCaptureVideoDataOutput, frontOutput: AVCaptureVideoDataOutput, audioOutput: AVCaptureAudioDataOutput?) {
        self.backOutput = backOutput
        self.frontOutput = frontOutput
        self.audioOutput = audioOutput
    }
    
    /// A Boolean value that indicates whether a recording is in progress.
    var isRecording: Bool { recorder != nil }
    
    // MARK: - Recording
    
    /// Starts a recording with the compression settings that the outputs recommend.
    func startRecording() throws {
        guard recorder == nil else { return }
        guard let videoSettings = backOutput.recommendedVideoSettingsForAssetWriter(writingTo: .mov) else {
            throw MovieCaptureError.notRecording
        }
        // The audio settings are valid only after the microphone delivered samples. Without a
        // sample rate the writer raises an exception, so the movie gets no sound in that case.
        var audioSettings = audioOutput?.recommendedAudioSettingsForAssetWriter(writingTo: .mov)
        if (audioSettings?[AVSampleRateKey] as? Double ?? 0) <= 0 {
            audioSettings = nil
        }
        recorder = try MovieRecorder(videoSettings: videoSettings, audioSettings: audioSettings)
        recordingStartTime = nil
        reportedDuration = .zero
        captureActivity = .movieCapture()
    }
    
    /// Stops the recording and returns the movie recorder, so that the caller can finish the file.
    ///
    /// After this call, no frame reaches the movie recorder, so the caller can finish it on any queue.
    func stopRecording() -> MovieRecorder? {
        defer {
            recorder = nil
            captureActivity = .idle
        }
        return recorder
    }
    
    // MARK: - Sample buffer delegates
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if output === audioOutput {
            recorder?.append(audioSampleBuffer: sampleBuffer)
            return
        }
        // Decide whether the frame is the small picture or the full picture.
        let isSmallPicture = (output === frontOutput) == (smallPicture == .front)
        if isSmallPicture {
            latestSmallPictureFrame = sampleBuffer
        } else {
            process(fullPictureFrame: sampleBuffer)
        }
    }
    
    /// Mixes a full picture frame with the latest small picture frame, and records the result.
    private func process(fullPictureFrame: CMSampleBuffer) {
        // Mix only while a recording runs. The preview layers show the live pictures by themselves.
        guard let recorder,
              let fullPixelBuffer = fullPictureFrame.imageBuffer,
              let smallPixelBuffer = latestSmallPictureFrame?.imageBuffer,
              let formatDescription = fullPictureFrame.formatDescription else { return }
        
        if !mixer.isPrepared {
            mixer.prepare(with: formatDescription)
        }
        guard let mixedPixelBuffer = mixer.mix(fullPicture: fullPixelBuffer, smallPicture: smallPixelBuffer),
              let outputFormat = mixer.outputFormatDescription else { return }
        
        // Wrap the new pixel buffer in a sample buffer with the time of the source frame.
        let time = fullPictureFrame.presentationTimeStamp
        var timing = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: time, decodeTimeStamp: .invalid)
        var mixedSampleBuffer: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(allocator: nil, imageBuffer: mixedPixelBuffer,
                                                 formatDescription: outputFormat, sampleTiming: &timing,
                                                 sampleBufferOut: &mixedSampleBuffer)
        guard let mixedSampleBuffer else { return }
        recorder.append(videoSampleBuffer: mixedSampleBuffer)
        
        // Report the recording time from the frame times, four times per second.
        let start = recordingStartTime ?? time
        recordingStartTime = start
        let duration = (time - start).seconds
        if duration - reportedDuration >= 0.25 {
            reportedDuration = duration
            captureActivity = .movieCapture(duration: duration)
        }
    }
}
