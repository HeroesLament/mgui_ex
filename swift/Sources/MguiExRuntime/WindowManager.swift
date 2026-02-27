import AppKit
import SwiftUI

class WindowManager {
    private var windows: [String: NSWindow] = [:]
    private let writer: StdoutWriter

    init(writer: StdoutWriter) {
        self.writer = writer
    }

    func openWindow(id: String, root: ViewNode, title: String?, width: Double?, height: Double?) {
        // If window already exists, just update content and bring to front
        if let existing = windows[id], existing.isVisible {
            updateWindow(id: id, root: root)
            existing.makeKeyAndOrderFront(nil as AnyObject?)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let w = CGFloat(width ?? 300)
        let h = CGFloat(height ?? 200)

        let writerRef = self.writer
        let windowId = id
        let mgr = self
        let onEvent: (String, String) -> Void = { nodeId, event in
            // Auto-close: if a button id ends with "-close", close this window
            if event == "tap" && nodeId.hasSuffix("-close") {
                DispatchQueue.main.async {
                    mgr.closeWindow(id: windowId)
                }
            }
            writerRef.sendEvent(nodeId: nodeId, event: event)
        }

        let contentView = DynamicView(node: root, onEvent: onEvent)

        let hostingController = NSHostingController(rootView:
            contentView
                .frame(width: w, height: h)
                .padding(0)
        )

        let window = NSWindow(contentViewController: hostingController)
        window.title = title ?? ""
        window.setContentSize(NSSize(width: w, height: h))
        window.styleMask = NSWindow.StyleMask([.titled, .closable])
        window.isReleasedWhenClosed = false
        window.center()

        // Clean up reference when window closes
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.windows.removeValue(forKey: windowId)
            self?.writer.sendEvent(nodeId: windowId, event: "window:closed")
        }

        windows[id] = window
        window.makeKeyAndOrderFront(nil as AnyObject?)
        NSApp.activate(ignoringOtherApps: true)
    }

    func updateWindow(id: String, root: ViewNode) {
        guard let window = windows[id] else { return }

        let writerRef = self.writer
        let onEvent: (String, String) -> Void = { nodeId, event in
            writerRef.sendEvent(nodeId: nodeId, event: event)
        }

        let contentView = DynamicView(node: root, onEvent: onEvent)

        let size = window.contentView?.frame.size ?? NSSize(width: 300, height: 200)
        let hostingController = NSHostingController(rootView:
            contentView
                .frame(width: size.width, height: size.height)
                .padding(0)
        )
        window.contentViewController = hostingController
    }

    func closeWindow(id: String) {
        if let window = windows[id] {
            window.close()
            windows.removeValue(forKey: id)
        }
    }
}
