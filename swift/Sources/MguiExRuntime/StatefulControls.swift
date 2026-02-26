import SwiftUI

// MARK: - Stateful TextField

struct StatefulTextField: View {
    let placeholder: String
    let initialText: String
    let fieldStyle: String?
    let nodeId: String
    let onEvent: (String, String) -> Void

    @State private var text: String

    init(placeholder: String, initialText: String, style: String?, nodeId: String,
         onEvent: @escaping (String, String) -> Void) {
        self.placeholder = placeholder
        self.initialText = initialText
        self.fieldStyle = style
        self.nodeId = nodeId
        self.onEvent = onEvent
        self._text = State(initialValue: initialText)
    }

    var body: some View {
        TextField(placeholder, text: $text)
            .onSubmit {
                onEvent(nodeId, "submit:\(text)")
            }
            .onChange(of: text) { _, newValue in
                onEvent(nodeId, "change:\(newValue)")
            }
            .applyTextFieldStyle(fieldStyle)
    }
}

// MARK: - Stateful SecureField

struct StatefulSecureField: View {
    let placeholder: String
    let initialText: String
    let fieldStyle: String?
    let nodeId: String
    let onEvent: (String, String) -> Void

    @State private var text: String

    init(placeholder: String, initialText: String, style: String?, nodeId: String,
         onEvent: @escaping (String, String) -> Void) {
        self.placeholder = placeholder
        self.initialText = initialText
        self.fieldStyle = style
        self.nodeId = nodeId
        self.onEvent = onEvent
        self._text = State(initialValue: initialText)
    }

    var body: some View {
        SecureField(placeholder, text: $text)
            .onSubmit {
                onEvent(nodeId, "submit:\(text)")
            }
            .onChange(of: text) { _, newValue in
                onEvent(nodeId, "change:\(newValue)")
            }
            .applyTextFieldStyle(fieldStyle)
    }
}

// MARK: - Stateful Toggle

struct StatefulToggle: View {
    let label: String
    let initialValue: Bool
    let nodeId: String
    let onEvent: (String, String) -> Void

    @State private var isOn: Bool

    init(label: String, isOn: Bool, nodeId: String,
         onEvent: @escaping (String, String) -> Void) {
        self.label = label
        self.initialValue = isOn
        self.nodeId = nodeId
        self.onEvent = onEvent
        self._isOn = State(initialValue: isOn)
    }

    var body: some View {
        Toggle(label, isOn: $isOn)
            .onChange(of: isOn) { _, newValue in
                onEvent(nodeId, "change:\(newValue)")
            }
    }
}

// MARK: - Stateful Picker

struct StatefulPicker: View {
    let label: String
    let initialSelection: String
    let options: [ViewNode.PickerOption]
    let pickerStyle: String?
    let nodeId: String
    let onEvent: (String, String) -> Void

    @State private var selection: String

    init(label: String, selection: String, options: [ViewNode.PickerOption],
         pickerStyle: String?, nodeId: String,
         onEvent: @escaping (String, String) -> Void) {
        self.label = label
        self.initialSelection = selection
        self.options = options
        self.pickerStyle = pickerStyle
        self.nodeId = nodeId
        self.onEvent = onEvent
        self._selection = State(initialValue: selection)
    }

    var body: some View {
        Picker(label, selection: $selection) {
            ForEach(options, id: \.value) { option in
                Text(option.label).tag(option.value)
            }
        }
        .onChange(of: selection) { _, newValue in
            onEvent(nodeId, "change:\(newValue)")
        }
        .applyPickerStyle(pickerStyle)
    }
}

// MARK: - Style Helpers

extension View {
    @ViewBuilder
    func applyTextFieldStyle(_ style: String?) -> some View {
        switch style?.lowercased() {
        case "plain":
            self.textFieldStyle(.plain)
        case "roundedborder":
            self.textFieldStyle(.roundedBorder)
        default:
            self.textFieldStyle(.roundedBorder)  // sensible default for menu bar
        }
    }

    @ViewBuilder
    func applyPickerStyle(_ style: String?) -> some View {
        switch style?.lowercased() {
        case "segmented":
            self.pickerStyle(.segmented)
        case "inline":
            self.pickerStyle(.inline)
        case "radiogroup":
            self.pickerStyle(.radioGroup)
        case "menu":
            self.pickerStyle(.menu)
        default:
            self.pickerStyle(.menu)  // sensible default for menu bar popover
        }
    }
}
