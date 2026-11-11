import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var model: RecorderModel
    private let accent = Color(red: 0.12, green: 0.55, blue: 0.55)

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor).ignoresSafeArea()
            if model.isRecording { recordingView } else { setupView }
        }
        .tint(accent)
        .preferredColorScheme(.light)
    }

    private var setupView: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 14) {
                    captureCard
                    sourcesCard
                    qualityCard
                    saveCard
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 20)
            }
            footer
        }
    }

    private var header: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color(red: 0.88, green: 0.96, blue: 0.95))
                Image(systemName: "rectangle.inset.filled.and.person.filled")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(accent)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text("轻录").font(.system(size: 21, weight: .semibold))
                Text("把屏幕和讲解清晰地录下来").font(.system(size: 13)).foregroundStyle(.secondary)
            }
            Spacer()
            Label("本地保存", systemImage: "lock.shield")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 26)
        .padding(.top, 25)
        .padding(.bottom, 17)
        .background(.white)
        .overlay(alignment: .bottom) { Divider() }
    }

    private var captureCard: some View {
        card(title: "录制范围", icon: "rectangle.dashed") {
            HStack(spacing: 14) {
                Picker("录制范围", selection: $model.options.mode) {
                    ForEach(CaptureMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .labelsHidden().pickerStyle(.segmented).frame(width: 210)
                if model.options.mode == .region {
                    Button(model.options.region == nil ? "框选区域" : "重新框选") { model.selectRegion() }
                    if let region = model.options.region {
                        Text("\(Int(region.width)) × \(Int(region.height))").font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
        }
    }

    private var sourcesCard: some View {
        card(title: "录制内容", icon: "waveform.and.mic") {
            VStack(spacing: 13) {
                HStack(spacing: 22) {
                    sourceToggle("系统声音", icon: "speaker.wave.2", value: $model.options.systemAudio)
                    sourceToggle("麦克风", icon: "mic", value: $model.options.microphone)
                    sourceToggle("摄像头", icon: "video", value: $model.options.camera)
                    Spacer()
                }
                if model.options.camera {
                    Divider()
                    CameraLayoutEditor(layout: $model.options.cameraLayout, accent: accent)
                }
            }
        }
    }

    private var qualityCard: some View {
        card(title: "画质与时间", icon: "slider.horizontal.3") {
            HStack(spacing: 18) {
                compactPicker("画质", selection: $model.options.quality) {
                    ForEach(VideoQuality.allCases) { Text($0.rawValue).tag($0) }
                }
                compactPicker("帧率", selection: $model.options.frameRate) {
                    Text("30 fps").tag(30); Text("60 fps").tag(60)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("开始前").font(.system(size: 12)).foregroundStyle(.secondary)
                    Stepper("\(model.options.countdown) 秒", value: $model.options.countdown, in: 0...10).frame(width: 105)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("自动停止").font(.system(size: 12)).foregroundStyle(.secondary)
                    Stepper(model.options.durationMinutes == 0 ? "不限时" : "\(model.options.durationMinutes) 分钟", value: $model.options.durationMinutes, in: 0...180, step: 5).frame(width: 125)
                }
                Spacer()
            }
        }
    }

    private var saveCard: some View {
        card(title: "保存位置", icon: "folder") {
            HStack {
                Image(systemName: "folder.fill").foregroundStyle(Color(red: 0.32, green: 0.65, blue: 0.82))
                Text(model.options.outputDirectory.path).font(.system(size: 13)).lineLimit(1).truncationMode(.middle)
                Spacer()
                Button("更改…") { model.chooseOutputDirectory() }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Button { Task { await model.start() } } label: {
                HStack(spacing: 8) {
                    Image(systemName: "record.circle")
                    Text("开始录制").fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 9)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(model.isBusy)

            HStack(spacing: 7) {
                if model.isBusy { ProgressView().controlSize(.small) }
                Text(model.status).font(.system(size: 12)).foregroundStyle(model.lastError == nil ? Color.secondary : Color.red)
                Spacer()
                if let url = model.lastOutput {
                    Button("在访达中显示") { NSWorkspace.shared.activateFileViewerSelecting([url]) }.buttonStyle(.link)
                }
            }
        }
        .padding(.horizontal, 26)
        .padding(.top, 16)
        .padding(.bottom, 22)
        .background(.white)
        .overlay(alignment: .top) { Divider() }
    }

    private var recordingView: some View {
        VStack(spacing: 22) {
            Spacer()
            ZStack {
                Circle().fill(Color.red.opacity(0.1)).frame(width: 72, height: 72)
                Circle().fill(.red).frame(width: 20, height: 20)
            }
            Text(model.elapsedText).font(.system(size: 48, weight: .medium, design: .monospaced)).monospacedDigit()
            Text("正在录制").font(.system(size: 14)).foregroundStyle(.secondary)
            Button { Task { await model.stop() } } label: {
                Label("停止并保存", systemImage: "stop.fill").padding(.horizontal, 22).padding(.vertical, 7)
            }
            .buttonStyle(.borderedProminent).tint(.red).controlSize(.large)
            Spacer()
            Text("停止后会自动整理画面与声音").font(.system(size: 12)).foregroundStyle(.tertiary).padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.97, green: 0.98, blue: 0.98))
    }

    private func card<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(title, systemImage: icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.primary.opacity(0.8))
            content()
        }
        .padding(17)
        .background(.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.black.opacity(0.055), lineWidth: 1) }
    }

    private func sourceToggle(_ title: String, icon: String, value: Binding<Bool>) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(value.wrappedValue ? accent : Color.secondary).frame(width: 20)
            Toggle(title, isOn: value).toggleStyle(.switch).controlSize(.small)
        }
    }

    private func compactPicker<S: Hashable, Content: View>(_ title: String, selection: Binding<S>, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 12)).foregroundStyle(.secondary)
            Picker(title, selection: selection, content: content).labelsHidden().frame(minWidth: 90)
        }
    }
}

private struct CameraLayoutEditor: View {
    @Binding var layout: CameraLayout
    let accent: Color
    @State private var dragStart: CameraLayout?

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            GeometryReader { geometry in
                let size = geometry.size
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 7).fill(Color(red: 0.94, green: 0.96, blue: 0.97))
                    Image(systemName: "macwindow").foregroundStyle(.secondary.opacity(0.35)).frame(maxWidth: .infinity, maxHeight: .infinity)
                    cameraBox(in: size)
                }
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .overlay { RoundedRectangle(cornerRadius: 7).stroke(Color.black.opacity(0.08)) }
            }
            .frame(width: 245, height: 138)

            VStack(alignment: .leading, spacing: 11) {
                Text("拖动摄像头框调整位置").font(.system(size: 13, weight: .medium))
                Text("最终视频会按照这里的位置与大小合成").font(.system(size: 11)).foregroundStyle(.secondary)
                HStack {
                    Image(systemName: "minus.magnifyingglass").foregroundStyle(.secondary)
                    Slider(value: Binding(get: { Double(layout.width) }, set: { layout.width = CGFloat($0); layout.clamp() }), in: 0.14...0.45)
                    Image(systemName: "plus.magnifyingglass").foregroundStyle(.secondary)
                }.frame(width: 245)
                Button("恢复右下角") { layout = CameraLayout() }.buttonStyle(.link).font(.system(size: 12))
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func cameraBox(in size: CGSize) -> some View {
        let w = size.width * layout.width
        let h = size.height * layout.height
        RoundedRectangle(cornerRadius: 5)
            .fill(accent.opacity(0.88))
            .overlay {
                VStack(spacing: 2) {
                    Image(systemName: "video.fill").font(.system(size: 12))
                    Text("摄像头").font(.system(size: 9, weight: .medium))
                }.foregroundStyle(.white)
            }
            .frame(width: w, height: h)
            .offset(x: size.width * layout.x, y: size.height * layout.y)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if dragStart == nil { dragStart = layout }
                        guard let start = dragStart else { return }
                        layout.x = start.x + value.translation.width / size.width
                        layout.y = start.y + value.translation.height / size.height
                        layout.clamp()
                    }
                    .onEnded { _ in dragStart = nil }
            )
    }
}
