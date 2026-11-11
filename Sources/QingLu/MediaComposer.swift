import AVFoundation

enum MediaComposer {
    static func compose(screen: URL, camera: URL, destination: URL, layout: CameraLayout, cameraTrimOffset: TimeInterval) async throws {
        let screenAsset = AVURLAsset(url: screen)
        let cameraAsset = AVURLAsset(url: camera)
        let composition = AVMutableComposition()
        guard let screenSource = try await screenAsset.loadTracks(withMediaType: .video).first,
              let screenTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw RecorderError.message("屏幕视频轨道无效")
        }
        let duration = try await screenAsset.load(.duration)
        try screenTrack.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: screenSource, at: .zero)

        let screenAudio = try await screenAsset.loadTracks(withMediaType: .audio)
        for source in screenAudio {
            if let target = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
                try target.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: source, at: .zero)
            }
        }

        guard let cameraSource = try await cameraAsset.loadTracks(withMediaType: .video).first,
              let cameraTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw RecorderError.message("摄像头视频轨道无效")
        }
        let cameraDuration = try await cameraAsset.load(.duration)
        let trimStart = CMTime(seconds: min(cameraTrimOffset, max(0, cameraDuration.seconds - 0.1)), preferredTimescale: 600)
        let availableCameraDuration = CMTimeSubtract(cameraDuration, trimStart)
        let insertDuration = CMTimeMinimum(duration, availableCameraDuration)
        try cameraTrack.insertTimeRange(CMTimeRange(start: trimStart, duration: insertDuration), of: cameraSource, at: .zero)

        let screenSize = try await screenSource.load(.naturalSize)
        let screenTransform = try await screenSource.load(.preferredTransform)
        let oriented = screenSize.applying(screenTransform)
        let renderSize = CGSize(width: abs(oriented.width), height: abs(oriented.height))
        let cameraSize = try await cameraSource.load(.naturalSize)
        let cameraTransform = try await cameraSource.load(.preferredTransform)
        let orientedCamera = cameraSize.applying(cameraTransform)
        let cameraDisplaySize = CGSize(width: abs(orientedCamera.width), height: abs(orientedCamera.height))

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
        let baseLayer = AVMutableVideoCompositionLayerInstruction(assetTrack: screenTrack)
        baseLayer.setTransform(screenTransform.concatenating(CGAffineTransform(translationX: oriented.width < 0 ? renderSize.width : 0, y: oriented.height < 0 ? renderSize.height : 0)), at: .zero)

        var safeLayout = layout
        safeLayout.clamp()
        let pipWidth = renderSize.width * safeLayout.width
        let scale = pipWidth / max(cameraDisplaySize.width, 1)
        let pipHeight = cameraDisplaySize.height * scale
        let x = min(max(renderSize.width * safeLayout.x, 0), renderSize.width - pipWidth)
        let y = min(max(renderSize.height * safeLayout.y, 0), renderSize.height - pipHeight)
        let pipLayer = AVMutableVideoCompositionLayerInstruction(assetTrack: cameraTrack)
        var transform = cameraTransform.concatenating(CGAffineTransform(scaleX: scale, y: scale))
        transform = transform.concatenating(CGAffineTransform(translationX: x, y: y))
        pipLayer.setTransform(transform, at: .zero)
        instruction.layerInstructions = [pipLayer, baseLayer]

        let videoComposition = AVMutableVideoComposition()
        videoComposition.instructions = [instruction]
        videoComposition.renderSize = renderSize
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)

        guard let exporter = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw RecorderError.message("无法创建视频合成器")
        }
        exporter.outputURL = destination; exporter.outputFileType = .mp4; exporter.videoComposition = videoComposition
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            exporter.exportAsynchronously {
                switch exporter.status {
                case .completed: continuation.resume()
                case .failed, .cancelled: continuation.resume(throwing: exporter.error ?? RecorderError.message("视频合成失败"))
                default: continuation.resume(throwing: RecorderError.message("视频合成未完成"))
                }
            }
        }
    }
}
