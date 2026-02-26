import Foundation

// MARK: - Incoming messages from Elixir

struct RawMessage: Codable {
    let type: String
    let payload: Payload?

    struct Payload: Codable {
        let root: ViewNode?
        let statusBar: StatusBarConfig?
        let menu: [MenuItem]?

        // Notification fields (flattened from payload)
        let id: String?
        let title: String?
        let body: String?
        let subtitle: String?
        let sound: Bool?
        let actions: [[String: String]]?

        struct StatusBarConfig: Codable {
            let title: String?
            let icon: String?
        }
    }

    /// Extract notification payload as [String: Any] dict for NotificationManager.
    var notificationPayload: [String: Any]? {
        guard type == "notify", let p = payload else { return nil }
        var dict: [String: Any] = [:]
        if let id = p.id { dict["id"] = id }
        if let title = p.title { dict["title"] = title }
        if let body = p.body { dict["body"] = body }
        if let subtitle = p.subtitle { dict["subtitle"] = subtitle }
        if let sound = p.sound { dict["sound"] = sound }
        if let actions = p.actions { dict["actions"] = actions }
        return dict
    }

    /// Extract the notification id for cancel messages.
    var cancelNotificationId: String? {
        guard type == "cancel_notification" else { return nil }
        return payload?.id
    }
}

// MARK: - Menu Item Configuration

struct MenuItem: Codable {
    let id: String
    let title: String?
    let icon: String?       // SF Symbol name
    let shortcut: String?   // e.g. "cmd+q", "cmd+,"
    let divider: Bool?
    let enabled: Bool?
    let state: String?      // "on", "off", "mixed" (for checkmarks)
    let children: [MenuItem]?
}

// MARK: - Outgoing events to Elixir

struct OutgoingEvent: Codable {
    let type: String
    let nodeId: String
    let event: String
}
