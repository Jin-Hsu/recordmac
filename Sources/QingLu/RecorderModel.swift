import SwiftUI
import AppKit
import ScreenCaptureKit
import AVFoundation

@MainActor
final class RecorderModel: NSObject, ObservableObject {
    @Published var options = RecordingOptions()
    @Published var isRecording = false
    @Published var isBusy = false
    @Published var status = "准备就绪"
    @Published var lastError: String?
    @Published var lastOutput: URL?
    @Published var elapsedText = "00:00:00"

    private var stream: SCStream?
    private var recordingOutput: SCRecordingOutput?
    private var cameraSession: AVCaptureSession?
    private var cameraOutput: AVCaptureMovieFileOutput?
    private var cameraDelegate: CameraFileDelegate?
    private var timer: Timer?
    private var startedAt: Date?
    private var cameraStartedAt: Date?
    private var cameraTrimOffset: TimeInterval = 0
    private var recordingOverlay: RecordingOverlay?
    private var screenTempURL: URL?
    private var cameraTempURL: URL?
    private var screenRecordingFinished = false
    private var screenFinishContinuation: CheckedContinuation<Void, Never>?

    func chooseOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.canCreateDirectories = true
        if panel.runModal() == .OK, let url = panel.url { options.outputDirectory = url }
    }

    func selectRegion() {
        RegionSelector.select { [weak self] rect in
            Task { @MainActor in self?.options.region = rect }
        }
    }

    func start() async {
        lastError = nil; lastOutput = nil
        guard options.mode == .fullScreen || options.region != nil else {
            fail("请先框选需要录制的区域"); return
        }
        isBusy = true; status = "正在检查录制权限…"
        if options.countdown > 0 {
            for value in stride(from: options.countdown, through: 1, by: -1) {
                status = "将在 \(value) 秒后开始录制"; try? await Task.sleep(for: .seconds(1))
            }
        }
        do {
            try await beginCapture()
            isRecording = true; isBusy = false; startedAt = Date(); status = "正在录制"
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.tick() }
            }
        } catch { fail(readable(error)) }
    }

    func stop() async {
        guard isRecording else { return }
        isBusy = true; status = "正在结束录制…"; timer?.invalidate(); timer = nil
        cameraOutput?.stopRecording()
        do { try await stream?.stopCapture() } catch { fail(readable(error)); return }
        await waitForScreenRecordingToFinish()
        if let cameraDelegate { await cameraDelegate.waitUntilFinished() }
        stream = nil; recordingOutput = nil; isRecording = false
        recordingOverlay?.hide(); recordingOverlay = nil
        await finishOutput()
    }

    private func beginCapture() async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let main = NSScreen.main,
              let number = main.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let display = content.displays.first(where: { $0.displayID == CGDirectDisplayID(number.uint32Value) }) else {
            throw RecorderError.message("找不到主显示器")
        }
        let ownBundleID = Bundle.main.bundleIdentifier
        let ownApplications = content.applications.filter { $0.bundleIdentifier == ownBundleID }
        let filter = SCContentFilter(display: display, excludingApplications: ownApplications, exceptingWindows: [])
        let config = SCStreamConfiguration()
        let source = options.mode == .region ? options.region! : CGRect(x: 0, y: 0, width: display.width, height: display.height)
        config.sourceRect = source
        config.width = max(2, Int(source.width * options.quality.scale)) & ~1
        config.height = max(2, Int(source.height * options.quality.scale)) & ~1
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(options.frameRate))
        config.queueDepth = 6
        config.showsCursor = true
        config.capturesAudio = options.systemAudio
        config.captureMicrophone = options.microphone
        config.sampleRate = 48_000
        config.channelCount = 2
        config.excludesCurrentProcessAudio = true

        let stamp = Self.fileStamp()
        let temp = FileManager.default.temporaryDirectory
        let screenURL = temp.appendingPathComponent("QingLu-screen-\(stamp).mp4")
        try? FileManager.default.removeItem(at: screenURL)
        let recConfig = SCRecordingOutputConfiguration()
        recConfig.outputURL = screenURL
        recConfig.outputFileType = .mp4
        recConfig.videoCodecType = options.quality == .ultra ? .hevc : .h264
        let output = SCRecordingOutput(configuration: recConfig, delegate: self)
        let newStream = SCStream(filter: filter, configuration: config, delegate: nil)
        try newStream.addRecordingOutput(output)
        screenRecordingFinished = false
        screenTempURL = screenURL; recordingOutput = output; stream = newStream

        if options.camera { try startCamera(stamp: stamp) }
        try await newStream.startCapture()
        if let cameraStartedAt { cameraTrimOffset = max(0, Date().timeIntervalSince(cameraStartedAt)) }
        recordingOverlay = RecordingOverlay(sourceRect: options.mode == .region ? source : nil, screen: main)
        recordingOverlay?.show()
    }

    private func startCamera(stamp: String) throws {
        guard AVCaptureDevice.authorizationStatus(for: .video) != .denied else { throw RecorderError.message("摄像头权限被拒绝，请到系统设置中允许") }
        let session = AVCaptureSession(); session.sessionPreset = .high
        guard let device = AVCaptureDevice.default(for: .video) else { throw RecorderError.message("没有找到可用摄像头") }
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw RecorderError.message("无法连接摄像头") }
        session.addInput(input)
        let output = AVCaptureMovieFileOutput(); guard session.canAddOutput(output) else { throw RecorderError.message("无法创建摄像头录像") }
        session.addOutput(output)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("QingLu-camera-\(stamp).mov")
        try? FileManager.default.removeItem(at: url)
        let delegate = CameraFileDelegate()
        cameraTempURL = url; cameraDelegate = delegate; cameraSession = session; cameraOutput = output
        session.startRunning(); cameraStartedAt = Date(); output.startRecording(to: url, recordingDelegate: delegate)
    }

    private func tick() {
        guard let start = startedAt else { return }
        let seconds = Int(Date().timeIntervalSince(start))
        elapsedText = String(format: "%02d:%02d:%02d", seconds / 3600, (seconds / 60) % 60, seconds % 60)
        recordingOverlay?.update(elapsedText: elapsedText)
        if options.durationMinutes > 0 && seconds >= options.durationMinutes * 60 { Task { await stop() } }
    }

    private func finishOutput() async {
        cameraSession?.stopRunning(); cameraSession = nil; cameraOutput = nil
        guard let screenURL = screenTempURL else { fail("没有生成录制文件"); return }
        let finalURL = uniqueOutputURL()
        do {
            if options.camera, let cameraURL = cameraTempURL, FileManager.default.fileExists(atPath: cameraURL.path) {
                status = "正在合成摄像头画中画与声音…"
                try await MediaComposer.compose(screen: screenURL, camera: cameraURL, destination: finalURL, layout: options.cameraLayout, cameraTrimOffset: cameraTrimOffset)
            } else {
                try FileManager.default.moveItem(at: screenURL, to: finalURL)
            }
            lastOutput = finalURL; status = "录制完成：\(finalURL.lastPathComponent)"; isBusy = false
            try? FileManager.default.removeItem(at: cameraTempURL ?? URL(fileURLWithPath: "/nonexistent"))
        } catch { fail("保存失败：\(readable(error))") }
    }

    private func uniqueOutputURL() -> URL {
        let base = "轻录-\(Self.fileStamp())"
        var url = options.outputDirectory.appendingPathComponent(base).appendingPathExtension("mp4")
        var n = 2
        while FileManager.default.fileExists(atPath: url.path) { url = options.outputDirectory.appendingPathComponent("\(base)-\(n)").appendingPathExtension("mp4"); n += 1 }
        return url
    }

    private static func fileStamp() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyyMMdd-HHmmss"; return f.string(from: Date())
    }
    private func readable(_ error: Error) -> String { (error as NSError).localizedDescription }
    private func fail(_ message: String) { lastError = message; status = message; isBusy = false; isRecording = false; timer?.invalidate() }

    private func waitForScreenRecordingToFinish() async {
        if screenRecordingFinished { return }
        await withCheckedContinuation { continuation in
            if screenRecordingFinished { continuation.resume() }
            else { screenFinishContinuation = continuation }
        }
    }

    private func markScreenRecordingFinished() {
        screenRecordingFinished = true
        screenFinishContinuation?.resume()
        screenFinishContinuation = nil
    }
}

extension RecorderModel: SCRecordingOutputDelegate {
    nonisolated func recordingOutputDidStartRecording(_ recordingOutput: SCRecordingOutput) {}
    nonisolated func recordingOutput(_ recordingOutput: SCRecordingOutput, didFailWithError error: any Error) {
        Task { @MainActor in self.markScreenRecordingFinished(); self.fail("录制失败：\(error.localizedDescription)") }
    }
    nonisolated func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {
        Task { @MainActor in self.markScreenRecordingFinished() }
    }
}

final class CameraFileDelegate: NSObject, AVCaptureFileOutputRecordingDelegate {
    private let lock = NSLock()
    private var finished = false
    private var continuation: CheckedContinuation<Void, Never>?

    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        lock.lock(); finished = true; let waiting = continuation; continuation = nil; lock.unlock()
        waiting?.resume()
    }

    func waitUntilFinished() async {
        await withCheckedContinuation { continuation in
            lock.lock()
            if finished { lock.unlock(); continuation.resume(); return }
            self.continuation = continuation
            lock.unlock()
        }
    }
}

enum RecorderError: Error { case message(String) }
extension RecorderError: LocalizedError { var errorDescription: String? { if case .message(let text) = self { return text }; return nil } }
