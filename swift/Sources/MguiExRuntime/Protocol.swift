import Foundation

// MARK: - Incoming messages from Elixir

struct RawMessage: Codable {
    let type: String
    let payload: Payload?

    struct Payload: Codable {
        let root: ViewNode?
        let statusBar: StatusBarConfig?
        let menu: [MenuItem]?

        // Window fields
        let windowId: String?
        let width: Double?
        let height: Double?

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

        enum CodingKeys: String, CodingKey {
            case root, statusBar, menu
            case windowId, width, height
            case id, title, body, subtitle, sound, actions
        }

        private static func decodeDouble(from container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Double? {
            if let v = try? container.decode(Double.self, forKey: key) { return v }
            if let v = try? container.decode(Int.self, forKey: key) { return Double(v) }
            return nil
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            root      = try c.decodeIfPresent(ViewNode.self, forKey: .root)
            statusBar = try c.decodeIfPresent(StatusBarConfig.self, forKey: .statusBar)
            menu      = try c.decodeIfPresent([MenuItem].self, forKey: .menu)
            windowId  = try c.decodeIfPresent(String.self, forKey: .windowId)
            width     = Self.decodeDouble(from: c, key: .width)
            height    = Self.decodeDouble(from: c, key: .height)
            id        = try c.decodeIfPresent(String.self, forKey: .id)
            title     = try c.decodeIfPresent(String.self, forKey: .title)
            body      = try c.decodeIfPresent(String.self, forKey: .body)
            subtitle  = try c.decodeIfPresent(String.self, forKey: .subtitle)
            sound     = try c.decodeIfPresent(Bool.self, forKey: .sound)
            actions   = try c.decodeIfPresent([[String: String]].self, forKey: .actions)
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
