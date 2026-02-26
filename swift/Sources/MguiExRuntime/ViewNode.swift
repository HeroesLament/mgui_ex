import Foundation

struct ViewNode: Codable, Identifiable, Equatable {
    var id: String
    let type: ViewType
    var props: Props
    var children: [ViewNode]?
    var modifiers: [ViewModifier]?

    static func == (lhs: ViewNode, rhs: ViewNode) -> Bool {
        lhs.id == rhs.id &&
        lhs.type == rhs.type &&
        lhs.props == rhs.props &&
        lhs.children == rhs.children &&
        lhs.modifiers == rhs.modifiers
    }

    enum ViewType: String, Codable {
        // Layout
        case vstack = "VStack"
        case hstack = "HStack"
        case zstack = "ZStack"
        case spacer = "Spacer"
        case divider = "Divider"

        // Content
        case text = "Text"
        case image = "Image"
        case label = "Label"
        case link = "Link"
        case progressView = "ProgressView"

        // Input controls
        case button = "Button"
        case textField = "TextField"
        case secureField = "SecureField"
        case toggle = "Toggle"
        case picker = "Picker"

        // Containers
        case scrollView = "ScrollView"
        case list = "List"
        case form = "Form"
        case section = "Section"
        case group = "Group"
    }

    struct PickerOption: Codable, Equatable {
        var value: String
        var label: String
    }

    struct Props: Equatable {
        // Text/content
        var content: String?
        var label: String?

        // Legacy inline styling (fallback)
        var font: String?
        var foregroundColor: String?

        // Layout (constructor args)
        var alignment: String?
        var spacing: Double?

        // Legacy padding
        var padding: Double?

        // Interaction
        var disabled: Bool?

        // Image / SF Symbols
        var systemName: String?
        var imageScale: String?

        // ProgressView
        var value: Double?
        var total: Double?

        // TextField / SecureField
        var placeholder: String?
        var text: String?
        var style: String?         // "plain", "roundedBorder"

        // Toggle
        var isOn: Bool?

        // Picker
        var selection: String?
        var options: [PickerOption]?
        var pickerStyle: String?   // "menu", "segmented", "inline", "radioGroup"

        // ScrollView
        var axes: String?          // "vertical", "horizontal", "both"
        var showsIndicators: Bool?

        // Section
        var header: String?
        var footer: String?

        // Form
        var formStyle: String?     // "grouped", "columns"

        // Link
        var url: String?

        init() {}
    }
}

// MARK: - Custom Codable for Props

extension ViewNode.Props: Codable {
    enum CodingKeys: String, CodingKey {
        case content, label, font, foregroundColor, alignment
        case spacing, padding, disabled
        case systemName, imageScale
        case value, total
        case placeholder, text, style
        case isOn
        case selection, options, pickerStyle
        case axes, showsIndicators
        case header, footer
        case formStyle
        case url
    }

    private static func decodeDouble(from container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Double? {
        if let v = try? container.decode(Double.self, forKey: key) { return v }
        if let v = try? container.decode(Int.self, forKey: key) { return Double(v) }
        return nil
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        content         = try c.decodeIfPresent(String.self, forKey: .content)
        label           = try c.decodeIfPresent(String.self, forKey: .label)
        font            = try c.decodeIfPresent(String.self, forKey: .font)
        foregroundColor = try c.decodeIfPresent(String.self, forKey: .foregroundColor)
        alignment       = try c.decodeIfPresent(String.self, forKey: .alignment)
        spacing         = Self.decodeDouble(from: c, key: .spacing)
        padding         = Self.decodeDouble(from: c, key: .padding)
        disabled        = try c.decodeIfPresent(Bool.self, forKey: .disabled)
        systemName      = try c.decodeIfPresent(String.self, forKey: .systemName)
        imageScale      = try c.decodeIfPresent(String.self, forKey: .imageScale)
        value           = Self.decodeDouble(from: c, key: .value)
        total           = Self.decodeDouble(from: c, key: .total)
        placeholder     = try c.decodeIfPresent(String.self, forKey: .placeholder)
        text            = try c.decodeIfPresent(String.self, forKey: .text)
        style           = try c.decodeIfPresent(String.self, forKey: .style)
        isOn            = try c.decodeIfPresent(Bool.self, forKey: .isOn)
        selection       = try c.decodeIfPresent(String.self, forKey: .selection)
        options         = try c.decodeIfPresent([ViewNode.PickerOption].self, forKey: .options)
        pickerStyle     = try c.decodeIfPresent(String.self, forKey: .pickerStyle)
        axes            = try c.decodeIfPresent(String.self, forKey: .axes)
        showsIndicators = try c.decodeIfPresent(Bool.self, forKey: .showsIndicators)
        header          = try c.decodeIfPresent(String.self, forKey: .header)
        footer          = try c.decodeIfPresent(String.self, forKey: .footer)
        formStyle       = try c.decodeIfPresent(String.self, forKey: .formStyle)
        url             = try c.decodeIfPresent(String.self, forKey: .url)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(content, forKey: .content)
        try c.encodeIfPresent(label, forKey: .label)
        try c.encodeIfPresent(font, forKey: .font)
        try c.encodeIfPresent(foregroundColor, forKey: .foregroundColor)
        try c.encodeIfPresent(alignment, forKey: .alignment)
        try c.encodeIfPresent(spacing, forKey: .spacing)
        try c.encodeIfPresent(padding, forKey: .padding)
        try c.encodeIfPresent(disabled, forKey: .disabled)
        try c.encodeIfPresent(systemName, forKey: .systemName)
        try c.encodeIfPresent(imageScale, forKey: .imageScale)
        try c.encodeIfPresent(value, forKey: .value)
        try c.encodeIfPresent(total, forKey: .total)
        try c.encodeIfPresent(placeholder, forKey: .placeholder)
        try c.encodeIfPresent(text, forKey: .text)
        try c.encodeIfPresent(style, forKey: .style)
        try c.encodeIfPresent(isOn, forKey: .isOn)
        try c.encodeIfPresent(selection, forKey: .selection)
        try c.encodeIfPresent(options, forKey: .options)
        try c.encodeIfPresent(pickerStyle, forKey: .pickerStyle)
        try c.encodeIfPresent(axes, forKey: .axes)
        try c.encodeIfPresent(showsIndicators, forKey: .showsIndicators)
        try c.encodeIfPresent(header, forKey: .header)
        try c.encodeIfPresent(footer, forKey: .footer)
        try c.encodeIfPresent(formStyle, forKey: .formStyle)
        try c.encodeIfPresent(url, forKey: .url)
    }
}

// MARK: - View Modifier

extension ViewNode {
    struct ViewModifier: Codable, Equatable {
        let type: ModifierType
        let args: ModifierArgs

        enum ModifierType: String, Codable {
            case frame, padding, cornerRadius, clipShape, offset
            case background, foregroundColor, opacity, shadow, border
            case font
            case scale
        }

        struct ModifierArgs: Equatable {
            var width: Double?
            var height: Double?
            var maxWidth: String?
            var maxHeight: String?
            var minWidth: Double?
            var minHeight: Double?

            var value: Double?
            var top: Double?
            var leading: Double?
            var bottom: Double?
            var trailing: Double?
            var horizontal: Double?
            var vertical: Double?

            var color: String?

            var fontName: String?
            var fontSize: Double?
            var fontWeight: String?

            var opacity: Double?
            var cornerRadius: Double?
            var shape: String?

            var shadowColor: String?
            var shadowRadius: Double?
            var shadowX: Double?
            var shadowY: Double?

            var borderColor: String?
            var borderWidth: Double?

            var scale: Double?
            var offsetX: Double?
            var offsetY: Double?
        }
    }
}

// MARK: - Custom Codable for ModifierArgs

extension ViewNode.ViewModifier.ModifierArgs: Codable {
    enum CodingKeys: String, CodingKey {
        case width, height, maxWidth, maxHeight, minWidth, minHeight
        case value, top, leading, bottom, trailing, horizontal, vertical
        case color
        case fontName, fontSize, fontWeight
        case opacity, cornerRadius, shape
        case shadowColor, shadowRadius, shadowX, shadowY
        case borderColor, borderWidth
        case scale, offsetX, offsetY
    }

    private static func decodeDouble(from container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Double? {
        if let v = try? container.decode(Double.self, forKey: key) { return v }
        if let v = try? container.decode(Int.self, forKey: key) { return Double(v) }
        return nil
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        width      = Self.decodeDouble(from: c, key: .width)
        height     = Self.decodeDouble(from: c, key: .height)
        maxWidth   = try c.decodeIfPresent(String.self, forKey: .maxWidth)
        maxHeight  = try c.decodeIfPresent(String.self, forKey: .maxHeight)
        minWidth   = Self.decodeDouble(from: c, key: .minWidth)
        minHeight  = Self.decodeDouble(from: c, key: .minHeight)
        value      = Self.decodeDouble(from: c, key: .value)
        top        = Self.decodeDouble(from: c, key: .top)
        leading    = Self.decodeDouble(from: c, key: .leading)
        bottom     = Self.decodeDouble(from: c, key: .bottom)
        trailing   = Self.decodeDouble(from: c, key: .trailing)
        horizontal = Self.decodeDouble(from: c, key: .horizontal)
        vertical   = Self.decodeDouble(from: c, key: .vertical)
        color      = try c.decodeIfPresent(String.self, forKey: .color)
        fontName   = try c.decodeIfPresent(String.self, forKey: .fontName)
        fontSize   = Self.decodeDouble(from: c, key: .fontSize)
        fontWeight = try c.decodeIfPresent(String.self, forKey: .fontWeight)
        opacity     = Self.decodeDouble(from: c, key: .opacity)
        cornerRadius = Self.decodeDouble(from: c, key: .cornerRadius)
        shape       = try c.decodeIfPresent(String.self, forKey: .shape)
        shadowColor  = try c.decodeIfPresent(String.self, forKey: .shadowColor)
        shadowRadius = Self.decodeDouble(from: c, key: .shadowRadius)
        shadowX      = Self.decodeDouble(from: c, key: .shadowX)
        shadowY      = Self.decodeDouble(from: c, key: .shadowY)
        borderColor = try c.decodeIfPresent(String.self, forKey: .borderColor)
        borderWidth = Self.decodeDouble(from: c, key: .borderWidth)
        scale   = Self.decodeDouble(from: c, key: .scale)
        offsetX = Self.decodeDouble(from: c, key: .offsetX)
        offsetY = Self.decodeDouble(from: c, key: .offsetY)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(width, forKey: .width)
        try c.encodeIfPresent(height, forKey: .height)
        try c.encodeIfPresent(maxWidth, forKey: .maxWidth)
        try c.encodeIfPresent(maxHeight, forKey: .maxHeight)
        try c.encodeIfPresent(minWidth, forKey: .minWidth)
        try c.encodeIfPresent(minHeight, forKey: .minHeight)
        try c.encodeIfPresent(value, forKey: .value)
        try c.encodeIfPresent(top, forKey: .top)
        try c.encodeIfPresent(leading, forKey: .leading)
        try c.encodeIfPresent(bottom, forKey: .bottom)
        try c.encodeIfPresent(trailing, forKey: .trailing)
        try c.encodeIfPresent(horizontal, forKey: .horizontal)
        try c.encodeIfPresent(vertical, forKey: .vertical)
        try c.encodeIfPresent(color, forKey: .color)
        try c.encodeIfPresent(fontName, forKey: .fontName)
        try c.encodeIfPresent(fontSize, forKey: .fontSize)
        try c.encodeIfPresent(fontWeight, forKey: .fontWeight)
        try c.encodeIfPresent(opacity, forKey: .opacity)
        try c.encodeIfPresent(cornerRadius, forKey: .cornerRadius)
        try c.encodeIfPresent(shape, forKey: .shape)
        try c.encodeIfPresent(shadowColor, forKey: .shadowColor)
        try c.encodeIfPresent(shadowRadius, forKey: .shadowRadius)
        try c.encodeIfPresent(shadowX, forKey: .shadowX)
        try c.encodeIfPresent(shadowY, forKey: .shadowY)
        try c.encodeIfPresent(borderColor, forKey: .borderColor)
        try c.encodeIfPresent(borderWidth, forKey: .borderWidth)
        try c.encodeIfPresent(scale, forKey: .scale)
        try c.encodeIfPresent(offsetX, forKey: .offsetX)
        try c.encodeIfPresent(offsetY, forKey: .offsetY)
    }
}
