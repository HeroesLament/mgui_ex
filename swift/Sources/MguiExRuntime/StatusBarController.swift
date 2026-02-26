import AppKit
import SwiftUI

class StatusBarController: NSObject {
    private var statusItem: NSStatusItem
    private var popover: NSPopover
    private let viewStore = ViewStore()
    private let writer: StdoutWriter
    private var rightClickMenu: NSMenu?
    private let popoverWidth: CGFloat = 300

    init(writer: StdoutWriter) {
        self.writer = writer
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true

        super.init()

        if let button = statusItem.button {
            button.title = "mgui"
            button.action = #selector(handleStatusBarClick)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        viewStore.onEvent = { [weak self] nodeId, event in
            self?.writer.sendEvent(nodeId: nodeId, event: event)
        }

        let hostingController = NSHostingController(
            rootView: PopoverContentView(store: viewStore)
        )
        popover.contentViewController = hostingController
        popover.contentSize = NSSize(width: popoverWidth, height: 200)
    }

    @objc private func handleStatusBarClick() {
        guard let event = NSApp.currentEvent else {
            togglePopover()
            return
        }

        if event.type == .rightMouseUp {
            showRightClickMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            // Measure the SwiftUI content and size the popover to fit
            recalculatePopoverSize()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
            popover.contentViewController?.view.window?.makeKeyAndOrderFront(nil)
        }
    }

    func updateContent(_ node: ViewNode?) {
        viewStore.node = node
        // If popover is already showing, resize it to fit new content
        if popover.isShown {
            DispatchQueue.main.async { [weak self] in
                self?.recalculatePopoverSize()
            }
        }
    }

    /// Measure SwiftUI content and update popover.contentSize
    private func recalculatePopoverSize() {
        guard let hostingController = popover.contentViewController as? NSHostingController<PopoverContentView> else { return }

        // Ask the hosting view for its ideal size given the fixed width
        let fittingSize = hostingController.sizeThatFits(in: NSSize(width: popoverWidth, height: CGFloat.greatestFiniteMagnitude))
        let height = max(fittingSize.height, 50)  // minimum 50pt
        popover.contentSize = NSSize(width: popoverWidth, height: height)
    }

    func updateStatusBar(title: String?, icon: String?) {
        guard let button = statusItem.button else { return }

        if let title = title {
            button.title = title
        }

        if let iconName = icon {
            button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: iconName)
            if button.title.isEmpty {
                button.imagePosition = .imageOnly
            } else {
                button.imagePosition = .imageLeading
            }
        }
    }

    // MARK: - Right-Click Menu

    func updateMenu(_ items: [MenuItem]) {
        rightClickMenu = buildMenu(from: items)
    }

    private func showRightClickMenu() {
        guard let menu = rightClickMenu else { return }
        guard let button = statusItem.button else { return }
        statusItem.menu = menu
        button.performClick(nil)
        statusItem.menu = nil
    }

    private func buildMenu(from items: [MenuItem]) -> NSMenu {
        let menu = NSMenu()

        for item in items {
            if item.divider == true {
                menu.addItem(NSMenuItem.separator())
            } else {
                let (keyEquiv, modifiers) = parseShortcut(item.shortcut)

                let menuItem = NSMenuItem(
                    title: item.title ?? "",
                    action: item.children?.isEmpty == false ? nil : #selector(menuItemClicked(_:)),
                    keyEquivalent: keyEquiv
                )
                menuItem.keyEquivalentModifierMask = modifiers
                menuItem.target = self
                menuItem.representedObject = item.id

                if let iconName = item.icon {
                    menuItem.image = NSImage(systemSymbolName: iconName,
                                             accessibilityDescription: iconName)
                }

                if let state = item.state {
                    switch state {
                    case "on":    menuItem.state = .on
                    case "mixed": menuItem.state = .mixed
                    default:      menuItem.state = .off
                    }
                }

                if item.enabled == false {
                    menuItem.isEnabled = false
                }

                if let children = item.children, !children.isEmpty {
                    menuItem.submenu = buildMenu(from: children)
                }

                menu.addItem(menuItem)
            }
        }

        return menu
    }

    @objc private func menuItemClicked(_ sender: NSMenuItem) {
        guard let itemId = sender.representedObject as? String else { return }
        writer.sendEvent(nodeId: itemId, event: "menu:tap")
    }

    private func parseShortcut(_ shortcut: String?) -> (String, NSEvent.ModifierFlags) {
        guard let shortcut = shortcut else { return ("", []) }

        var modifiers: NSEvent.ModifierFlags = []
        var key = ""

        let parts = shortcut.lowercased().split(separator: "+")
        for part in parts {
            switch part {
            case "cmd", "command":  modifiers.insert(.command)
            case "shift":           modifiers.insert(.shift)
            case "alt", "option":   modifiers.insert(.option)
            case "ctrl", "control": modifiers.insert(.control)
            default:                key = String(part)
            }
        }

        return (key, modifiers)
    }
}

// MARK: - Popover content

struct PopoverContentView: View {
    var store: ViewStore

    var body: some View {
        Group {
            if let node = store.node {
                DynamicView(node: node, onEvent: { nodeId, event in
                    store.onEvent?(nodeId, event)
                })
            } else {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Waiting for content...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
        }
        .frame(width: 300)
    }
}
