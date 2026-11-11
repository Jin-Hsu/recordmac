import AppKit

@MainActor
final class RecordingOverlay {
    private var borderWindow: NSWindow?
    private var statusWindow: NSWindow?
    private let sourceRect: CGRect?
    private let screen: NSScreen
    private let statusView = RecordingStatusView(frame: NSRect(x: 0, y: 0, width: 142, height: 34))

    init(sourceRect: CGRect?, screen: NSScreen) {
        self.sourceRect = sourceRect
        self.screen = screen
    }

    func show() {
        if let sourceRect {
            let globalRect = CGRect(
                x: screen.frame.minX + sourceRect.minX,
                y: screen.frame.maxY - sourceRect.maxY,
                width: sourceRect.width,
                height: sourceRect.height
            )
            let window = overlayWindow(frame: globalRect)
            window.contentView = RecordingBorderView(frame: CGRect(origin: .zero, size: globalRect.size))
            window.orderFrontRegardless()
            borderWindow = window
        }

        let reference = borderWindow?.frame ?? screen.visibleFrame
        let x = min(max(reference.midX - 71, screen.visibleFrame.minX + 8), screen.visibleFrame.maxX - 150)
        let preferredY = reference.maxY + 8
        let y = preferredY + 34 < screen.visibleFrame.maxY ? preferredY : reference.maxY - 42
        let status = overlayWindow(frame: CGRect(x: x, y: y, width: 142, height: 34))
        status.contentView = statusView
        status.orderFrontRegardless()
        statusWindow = status
    }

    func update(elapsedText: String) { statusView.elapsedText = elapsedText; statusView.needsDisplay = true }
    func hide() { borderWindow?.orderOut(nil); statusWindow?.orderOut(nil); borderWindow = nil; statusWindow = nil }

    private func overlayWindow(frame: CGRect) -> NSWindow {
        let window = NSWindow(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        return window
    }
}

private final class RecordingBorderView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let inset = bounds.insetBy(dx: 2, dy: 2)
        let path = NSBezierPath(roundedRect: inset, xRadius: 4, yRadius: 4)
        NSColor.systemRed.withAlphaComponent(0.9).setStroke()
        path.lineWidth = 3
        path.setLineDash([8, 5], count: 2, phase: 0)
        path.stroke()
    }
}

private final class RecordingStatusView: NSView {
    var elapsedText = "00:00:00"
    override func draw(_ dirtyRect: NSRect) {
        let background = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 17, yRadius: 17)
        NSColor(calibratedWhite: 0.12, alpha: 0.92).setFill(); background.fill()
        NSColor.systemRed.setFill(); NSBezierPath(ovalIn: CGRect(x: 13, y: 12, width: 10, height: 10)).fill()
        let text = "录制中  \(elapsedText)" as NSString
        text.draw(at: CGPoint(x: 31, y: 9), withAttributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white
        ])
    }
}
