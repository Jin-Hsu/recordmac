import Foundation
import CoreGraphics

enum CaptureMode: String, CaseIterable, Identifiable {
    case fullScreen = "全屏"
    case region = "区域"
    var id: String { rawValue }
}

enum VideoQuality: String, CaseIterable, Identifiable {
    case standard = "标准"
    case high = "高清"
    case ultra = "超清"
    var id: String { rawValue }
    var scale: CGFloat { self == .standard ? 0.65 : (self == .high ? 1 : 1.25) }
    var bitRate: Int { self == .standard ? 4_000_000 : (self == .high ? 9_000_000 : 16_000_000) }
}

enum CameraPosition: String, CaseIterable, Identifiable {
    case topLeft = "左上", topRight = "右上", bottomLeft = "左下", bottomRight = "右下"
    var id: String { rawValue }
}

struct CameraLayout: Equatable {
    /// 以最终视频左上角为原点的归一化坐标。
    var x: CGFloat = 0.72
    var y: CGFloat = 0.70
    var width: CGFloat = 0.25
    var aspectRatio: CGFloat = 16.0 / 9.0

    var height: CGFloat { width / aspectRatio }

    mutating func clamp() {
        width = min(max(width, 0.14), 0.45)
        x = min(max(x, 0), 1 - width)
        y = min(max(y, 0), 1 - height)
    }
}

struct RecordingOptions {
    var mode: CaptureMode = .fullScreen
    var region: CGRect?
    var systemAudio = true
    var microphone = true
    var camera = false
    var cameraLayout = CameraLayout()
    var quality: VideoQuality = .high
    var frameRate = 30
    var countdown = 3
    var durationMinutes = 0
    var outputDirectory = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask).first!
}
