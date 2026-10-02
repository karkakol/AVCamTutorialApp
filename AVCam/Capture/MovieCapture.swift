/*
See the LICENSE.txt file for this sample's licensing information.

Abstract:
An object that manages a movie capture output to record videos.
*/

import AVFoundation
import Combine

enum MovieCaptureError: Error {
    case notRecording
}

/// An object that manages a movie capture output to record videos.
final class MovieCapture: OutputService {
    
    /// A value that indicates the current state of movie capture.
    @Published private(set) var captureActivity: CaptureActivity = .idle
    
    /// The capture output type for this service.
    let output = AVCaptureMovieFileOutput()
    // An internal alias for the output.
    private var movieOutput: AVCaptureMovieFileOutput { output }
    
    // A delegate object to respond to movie capture events.
    private var delegate: MovieCaptureDelegate?
    
    // The interval at which to update the recording time.
    private let refreshInterval = TimeInterval(0.25)
    private var timerCancellable: AnyCancellable?
    
    // A Boolean value that indicates whether the currently selected camera's
    // active format supports HDR.
    private var isHDRSupported = false
    
    /// A stream of the results of recordings that end without a request from the app,
    /// for example because of an interruption or a full disk.
    let unexpectedResults: AsyncStream<Result<Movie, Error>>
    private let unexpectedResultsContinuation: AsyncStream<Result<Movie, Error>>.Continuation
    
    init() {
        let (unexpectedResults, continuation) = AsyncStream.makeStream(of: Result<Movie, Error>.self)
        self.unexpectedResults = unexpectedResults
        self.unexpectedResultsContinuation = continuation
    }

    // MARK: - Capturing a movie

    /// Starts movie recording.
    func startRecording() {
        // Return early if already recording.
        guard !movieOutput.isRecording else { return }

        // Start a timer to update the recording time.
        startMonitoringDuration()

        let delegate = MovieCaptureDelegate()
        // Handle a recording that ends before the app stops it.
        delegate.unexpectedFinishHandler = { [weak self] result in
            guard let self else { return }
            stopMonitoringDuration()
            self.delegate = nil
            unexpectedResultsContinuation.yield(result)
        }
        self.delegate = delegate
        movieOutput.startRecording(to: URL.movieFileURL, recordingDelegate: delegate)
    }
    
    /// Stops movie recording.
    /// - Returns: A `Movie` object that represents the captured movie.
    func stopRecording() async throws -> Movie {
        // Use a continuation to adapt the delegate-based capture API to an async interface.
        return try await withCheckedThrowingContinuation { continuation in
            guard let delegate, movieOutput.isRecording else {
                // The output isn't recording, so the delegate receives no callback. Don't wait for one.
                stopMonitoringDuration()
                continuation.resume(throwing: MovieCaptureError.notRecording)
                return
            }
            // Set the continuation on the delegate to handle the capture result.
            delegate.continuation = continuation
            
            /// Stops recording, which causes the output to call the `MovieCaptureDelegate` object.
            movieOutput.stopRecording()
            stopMonitoringDuration()
        }
    }
    
    // MARK: - Movie capture delegate
    /// A delegate object that responds to the capture output finalizing movie recording.
    private class MovieCaptureDelegate: NSObject, AVCaptureFileOutputRecordingDelegate {
        
        var continuation: CheckedContinuation<Movie, Error>?
        
        /// A closure to call when the recording ends before the app stops it.
        var unexpectedFinishHandler: ((Result<Movie, Error>) -> Void)?
        
        func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
            let result: Result<Movie, Error>
            if let error, !isMovieUsable(after: error) {
                // The movie file isn't usable. Report the error.
                result = .failure(error)
            } else {
                // The movie file is complete. Report a new movie object.
                result = .success(Movie(url: outputFileURL))
            }
            
            if let continuation {
                // The app asked to stop the recording. Return the result to the caller.
                continuation.resume(with: result)
            } else {
                // The recording ended by itself. Nobody waits for the result, so report it separately.
                unexpectedFinishHandler?(result)
            }
        }
        
        /// Returns a Boolean value that indicates whether the output wrote a complete movie file although an error occurred.
        ///
        /// A recording can stop with an error, for example when it reaches a size limit or
        /// when the disk is full, and still produce a file that plays.
        private func isMovieUsable(after error: Error) -> Bool {
            let userInfo = (error as NSError).userInfo
            return userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool ?? false
        }
    }
    
    // MARK: - Monitoring recorded duration
    
    // Starts a timer to update the recording time.
    private func startMonitoringDuration() {
        captureActivity = .movieCapture()
        timerCancellable = Timer.publish(every: refreshInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                // Poll the movie output for its recorded duration.
                let duration = movieOutput.recordedDuration.seconds
                captureActivity = .movieCapture(duration: duration)
            }
    }
    
    /// Stops the timer and resets the time to `CMTime.zero`.
    private func stopMonitoringDuration() {
        timerCancellable?.cancel()
        captureActivity = .idle
    }
    
    func updateConfiguration(for device: AVCaptureDevice) {
        // The app supports HDR video capture if the active format supports it.
        isHDRSupported = device.activeFormat10BitVariant != nil

        // The output has a video connection only while the session contains it, which is the
        // case in video capture mode. Adding the output creates a new connection, so the service
        // configures it here rather than when recording starts.
        guard let connection = movieOutput.connection(with: .video) else { return }

        // Configure the connection for HEVC capture.
        if movieOutput.availableVideoCodecTypes.contains(.hevc) {
            movieOutput.setOutputSettings([AVVideoCodecKey: AVVideoCodecType.hevc], for: connection)
        }

        // Stabilize the video this output records. Stabilization crops the video to leave room to
        // correct for camera motion, so configuring it here, rather than when recording starts,
        // avoids changing the framing at the moment recording begins. Passing `auto` lets the
        // system choose a mode that suits the active format and frame rate.
        if connection.isVideoStabilizationSupported {
            connection.preferredVideoStabilizationMode = .auto
        }
    }

    // MARK: - Configuration
    /// Returns the capabilities for this capture service.
    var capabilities: CaptureCapabilities {
        CaptureCapabilities(isHDRSupported: isHDRSupported)
    }
}
