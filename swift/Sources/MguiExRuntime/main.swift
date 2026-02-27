import AppKit

// Create the application — .accessory means no dock icon, menu bar only
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let writer = StdoutWriter()
let statusBar = StatusBarController(writer: writer)
let notifications = NotificationManager(writer: writer)
let windowManager = WindowManager(writer: writer)
notifications.requestPermission()

// Set up stdin reader — receives messages from Elixir Port
let reader = StdinReader()
reader.onMessage = { message in
    switch message.type {
    case "render":
        statusBar.updateContent(message.payload?.root)
        statusBar.updateStatusBar(
            title: message.payload?.statusBar?.title,
            icon: message.payload?.statusBar?.icon
        )
        if let menuItems = message.payload?.menu {
            statusBar.updateMenu(menuItems)
        }

    case "window":
        if let root = message.payload?.root,
           let windowId = message.payload?.windowId {
            windowManager.openWindow(
                id: windowId,
                root: root,
                title: message.payload?.title,
                width: message.payload?.width,
                height: message.payload?.height
            )
        }

    case "close_window":
        if let windowId = message.payload?.windowId {
            windowManager.closeWindow(id: windowId)
        }

    case "notify":
        if let payload = message.notificationPayload {
            notifications.push(payload)
        }

    case "cancel_notification":
        if let id = message.cancelNotificationId {
            notifications.cancel(id)
        }

    case "quit":
        app.terminate(nil)

    default:
        fputs("MguiEx: Unknown message type: \(message.type)\n", stderr)
    }
}
reader.start()

// Run the app event loop (blocks forever)
app.run()