import Foundation
import MessagePack

class StdoutWriter {
    private let encoder = MessagePackEncoder()
    private let lock = NSLock()

    func sendEvent(nodeId: String, event: String) {
        let msg = OutgoingEvent(type: "event", nodeId: nodeId, event: event)
        lock.lock()
        defer { lock.unlock() }
        do {
            let packed = try encoder.encode(msg)
            writeFrame(packed)
        } catch {
            fputs("MguiEx: Failed to encode event: \(error)\n", stderr)
        }
    }

    func sendNotificationEvent(id: String, event: String, action: String? = nil, text: String? = nil) {
        let msg = NotificationLifecycleEvent(type: "notification", id: id, event: event, action: action, text: text)
        lock.lock()
        defer { lock.unlock() }
        do {
            let packed = try encoder.encode(msg)
            writeFrame(packed)
        } catch {
            fputs("MguiEx: Failed to encode notification event: \(error)\n", stderr)
        }
    }

    private func writeFrame(_ packed: Data) {
        var length = UInt32(packed.count).bigEndian
        let lengthData = Data(bytes: &length, count: 4)
        FileHandle.standardOutput.write(lengthData)
        FileHandle.standardOutput.write(packed)
    }
}

struct NotificationLifecycleEvent: Codable {
    let type: String
    let id: String
    let event: String
    let action: String?
    let text: String?
}
