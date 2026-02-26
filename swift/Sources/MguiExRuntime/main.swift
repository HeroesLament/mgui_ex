import AppKit

// Create the application — .accessory means no dock icon, menu bar only
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let writer = StdoutWriter()
let statusBar = StatusBarController(writer: writer)
let notifications = NotificationManager(writer: writer)
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
