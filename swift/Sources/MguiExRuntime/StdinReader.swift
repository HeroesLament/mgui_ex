import AppKit
import Foundation
import MessagePack

class StdinReader {
    private let queue = DispatchQueue(label: "mgui_ex.stdin", qos: .userInteractive)
    private let decoder = MessagePackDecoder()

    var onMessage: ((RawMessage) -> Void)?

    func start() {
        queue.async { [weak self] in
            self?.readLoop()
        }
    }

    private func readLoop() {
        let stdin = FileHandle.standardInput
        var buffer = Data()

        while true {
            let chunk = stdin.availableData
            if chunk.isEmpty {
                // stdin closed — Elixir process died, exit cleanly
                DispatchQueue.main.async {
                    NSApplication.shared.terminate(nil)
                }
                return
            }

            buffer.append(chunk)

            // Extract complete messages (4-byte BE length prefix + msgpack body)
            while buffer.count >= 4 {
                let length = buffer.prefix(4).withUnsafeBytes { ptr -> UInt32 in
                    let raw = ptr.load(as: UInt32.self)
                    return UInt32(bigEndian: raw)
                }

                let totalNeeded = 4 + Int(length)
                guard buffer.count >= totalNeeded else { break }

                let messageData = Data(buffer[4..<totalNeeded])
                buffer = Data(buffer[totalNeeded...])

                do {
                    let message = try decoder.decode(RawMessage.self, from: messageData)
                    DispatchQueue.main.async { [weak self] in
                        self?.onMessage?(message)
                    }
                } catch {
                    fputs("MguiEx: Failed to decode message: \(error)\n", stderr)
                }
            }
        }
    }
}
