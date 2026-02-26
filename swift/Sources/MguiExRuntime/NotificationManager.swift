import Foundation
import UserNotifications

/// Manages macOS notifications via UNUserNotificationCenter.
///
/// Handles:
/// - Permission requests (first use)
/// - Displaying notifications with actions
/// - Routing lifecycle events (delivered, interacted, dismissed) back to Elixir
///
/// In dev mode (no .app bundle / permission denied), falls back to AppleScript
/// `display notification` for basic fire-and-forget notifications.
class NotificationManager: NSObject, UNUserNotificationCenterDelegate {

    private var center: UNUserNotificationCenter?
    private let writer: StdoutWriter
    private var permissionGranted = false
    private var permissionRequested = false
    private let hasBundle: Bool

    init(writer: StdoutWriter) {
        self.writer = writer

        // UNUserNotificationCenter crashes if there's no .app bundle
        // Detect this by checking if the bundle has a valid identifier
        let bundleId = Bundle.main.bundleIdentifier
        self.hasBundle = bundleId != nil && !bundleId!.isEmpty
        
        super.init()

        if hasBundle {
            let c = UNUserNotificationCenter.current()
            c.delegate = self
            self.center = c
            fputs("MguiEx: UNUserNotificationCenter available (bundle: \(bundleId!))\n", stderr)
        } else {
            fputs("MguiEx: No app bundle detected, using AppleScript fallback for notifications\n", stderr)
        }
    }

    // MARK: - Setup

    func requestPermission() {
        guard hasBundle, let center = center else { return }
        guard !permissionRequested else { return }
        permissionRequested = true

        center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, error in
            self?.permissionGranted = granted
            if let error = error {
                fputs("MguiEx: Notification permission error: \(error)\n", stderr)
            }
            if !granted {
                fputs("MguiEx: Notification permission denied, will use AppleScript fallback\n", stderr)
            }
        }
    }

    // MARK: - Push

    func push(_ payload: [String: Any]) {
        guard let id = payload["id"] as? String,
              let title = payload["title"] as? String else {
            fputs("MguiEx: Notification missing id or title\n", stderr)
            return
        }

        let body = payload["body"] as? String
        let subtitle = payload["subtitle"] as? String
        let sound = payload["sound"] as? Bool ?? true
        let actions = payload["actions"] as? [[String: Any]] ?? []

        if permissionGranted, center != nil {
            pushViaUNCenter(id: id, title: title, body: body, subtitle: subtitle, sound: sound, actions: actions)
        } else {
            pushViaAppleScript(id: id, title: title, body: body, subtitle: subtitle, sound: sound)
        }
    }

    // MARK: - Cancel

    func cancel(_ id: String) {
        center?.removePendingNotificationRequests(withIdentifiers: [id])
        center?.removeDeliveredNotifications(withIdentifiers: [id])
    }

    // MARK: - UNCenter path

    private func pushViaUNCenter(id: String, title: String, body: String?, subtitle: String?, sound: Bool, actions: [[String: Any]]) {
        guard let center = center else {
            pushViaAppleScript(id: id, title: title, body: body, subtitle: subtitle, sound: sound)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        if let body = body { content.body = body }
        if let subtitle = subtitle { content.subtitle = subtitle }
        if sound { content.sound = .default }

        // Register action category if actions provided
        if !actions.isEmpty {
            let categoryId = "mgui_ex.\(id)"
            content.categoryIdentifier = categoryId

            let unActions = actions.map { actionDict -> UNNotificationAction in
                let actionId = actionDict["id"] as? String ?? "default"
                let actionTitle = actionDict["title"] as? String ?? actionId
                let destructive = actionDict["destructive"] as? Bool ?? false

                var options: UNNotificationActionOptions = []
                if destructive { options.insert(.destructive) }

                return UNNotificationAction(
                    identifier: actionId,
                    title: actionTitle,
                    options: options
                )
            }

            let category = UNNotificationCategory(
                identifier: categoryId,
                actions: unActions,
                intentIdentifiers: [],
                options: .customDismissAction
            )
            center.setNotificationCategories([category])
        }

        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)

        center.add(request) { [weak self] error in
            if let error = error {
                fputs("MguiEx: Failed to add notification: \(error)\n", stderr)
                self?.sendLifecycleEvent(id: id, event: "error", extra: ["reason": "\(error)"])
            } else {
                // Notification was accepted by the system — it's delivered
                self?.sendLifecycleEvent(id: id, event: "delivered")
            }
        }
    }

    // MARK: - AppleScript fallback (dev mode)

    private func pushViaAppleScript(id: String, title: String, body: String?, subtitle: String?, sound: Bool) {
        var script = "display notification"

        if let body = body {
            script += " \"\(escapeAppleScript(body))\""
        } else {
            script += " \"\""
        }

        script += " with title \"\(escapeAppleScript(title))\""

        if let subtitle = subtitle {
            script += " subtitle \"\(escapeAppleScript(subtitle))\""
        }

        if sound {
            script += " sound name \"default\""
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                // AppleScript doesn't give us real lifecycle, so auto-deliver
                sendLifecycleEvent(id: id, event: "delivered")
            } else {
                sendLifecycleEvent(id: id, event: "error", extra: ["reason": "osascript exit \(process.terminationStatus)"])
            }
        } catch {
            fputs("MguiEx: AppleScript notification failed: \(error)\n", stderr)
            sendLifecycleEvent(id: id, event: "error", extra: ["reason": "\(error)"])
        }
    }

    private func escapeAppleScript(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
         .replacingOccurrences(of: "\"", with: "\\\"")
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Called when a notification is about to be presented while the app is in foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner even when app is "foreground" (status bar apps are always foreground)
        completionHandler([.banner, .sound])
    }

    /// Called when user interacts with a notification (tap, action button, dismiss).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let id = response.notification.request.identifier
        let actionId = response.actionIdentifier

        switch actionId {
        case UNNotificationDismissActionIdentifier:
            sendLifecycleEvent(id: id, event: "dismissed")

        case UNNotificationDefaultActionIdentifier:
            sendLifecycleEvent(id: id, event: "interacted", extra: ["action": "default"])

        default:
            // Custom action button
            var extra: [String: String] = ["action": actionId]

            // If it's a text input action, grab the text
            if let textResponse = response as? UNTextInputNotificationResponse {
                extra["text"] = textResponse.userText
            }

            sendLifecycleEvent(id: id, event: "interacted", extra: extra)
        }

        completionHandler()
    }

    // MARK: - Send events back to Elixir

    private func sendLifecycleEvent(id: String, event: String, extra: [String: String] = [:]) {
        writer.sendNotificationEvent(
            id: id,
            event: event,
            action: extra["action"],
            text: extra["text"]
        )
    }
}
