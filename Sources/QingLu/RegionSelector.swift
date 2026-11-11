import AppKit

@MainActor
enum RegionSelector {
    private static var window: NSWindow?

    static func select(completion: @escaping (CGRect) -> Void) {
        guard let screen = NSScreen.main else { return }
        let view = SelectionView(frame: screen.frame)
        let panel = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        panel.level = .screenSaver
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.ignoresMouseEvents = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        view.onCancel = { panel.orderOut(nil); window = nil }
        view.onSelect = { globalRect in
            panel.orderOut(nil); window = nil
            let localX = globalRect.minX - screen.frame.minX
            let localYFromTop = screen.frame.maxY - globalRect.maxY
            completion(CGRect(x: localX, y: localYFromTop, width: globalRect.width, height: globalRect.height))
        }
        panel.contentView = view; window = panel
        panel.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
}

final class SelectionView: NSView {
    var onSelect: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?
    private var start: CGPoint?
    private var current: CGPoint?

    override var acceptsFirstResponder: Bool { true }
    override func mouseDown(with event: NSEvent) { start = convert(event.locationInWindow, from: nil); current = start; needsDisplay = true }
    override func mouseDragged(with event: NSEvent) { current = convert(event.locationInWindow, from: nil); needsDisplay = true }
    override func mouseUp(with event: NSEvent) {
        current = convert(event.locationInWindow, from: nil)
        guard let rect = selectionRect, rect.width >= 20, rect.height >= 20 else { return }
        let global = window?.convertToScreen(rect) ?? rect
        onSelect?(global)
    }
    override func keyDown(with event: NSEvent) { if event.keyCode == 53 { onCancel?() } }

    private var selectionRect: CGRect? {
        guard let a = start, let b = current else { return nil }
        return CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.48).setFill(); bounds.fill()
        guard let rect = selectionRect else {
            drawHint("拖动鼠标框选录制区域 · 按 Esc 取消", at: CGPoint(x: bounds.midX, y: bounds.midY)); return
        }
        NSColor.clear.setFill(); rect.fill(using: .copy)
        NSColor.systemPurple.setStroke(); let path = NSBezierPath(rect: rect); path.lineWidth = 3; path.stroke()
        drawHint("\(Int(rect.width)) × \(Int(rect.height))", at: CGPoint(x: rect.midX, y: max(28, rect.minY - 24)))
    }

    private func drawHint(_ text: String, at point: CGPoint) {
        let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: NSColor.white, .font: NSFont.systemFont(ofSize: 16, weight: .semibold), .backgroundColor: NSColor.black.withAlphaComponent(0.65)]
        let string = NSAttributedString(string: "  \(text)  ", attributes: attrs); let size = string.size()
        string.draw(at: CGPoint(x: point.x - size.width / 2, y: point.y - size.height / 2))
    }
}
