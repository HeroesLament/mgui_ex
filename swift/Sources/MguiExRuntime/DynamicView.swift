import SwiftUI

struct DynamicView: View {
    let node: ViewNode
    let onEvent: (String, String) -> Void

    var body: some View {
        buildView(for: node)
            .applyModifiers(node.modifiers)
            .applyLegacyPadding(node.props.padding, hasModifier: hasModifier(.padding))
            .applyLegacyFont(node.props.font, hasModifier: hasModifier(.font))
            .applyLegacyForeground(node.props.foregroundColor, hasModifier: hasModifier(.foregroundColor))
            .disabled(node.props.disabled ?? false)
    }

    private func hasModifier(_ type: ViewNode.ViewModifier.ModifierType) -> Bool {
        node.modifiers?.contains(where: { $0.type == type }) ?? false
    }

    @ViewBuilder
    var childViews: some View {
        if let children = node.children {
            ForEach(children) { child in
                DynamicView(node: child, onEvent: onEvent)
            }
        }
    }

    @ViewBuilder
    func buildView(for node: ViewNode) -> some View {
        switch node.type {

        // MARK: Layout
        case .vstack:
            VStack(
                alignment: HorizontalAlignment(mgui: node.props.alignment),
                spacing: node.props.spacing.map { CGFloat($0) }
            ) { childViews }

        case .hstack:
            HStack(
                alignment: VerticalAlignment(mgui: node.props.alignment),
                spacing: node.props.spacing.map { CGFloat($0) }
            ) { childViews }

        case .zstack:
            ZStack(alignment: Alignment(mgui: node.props.alignment)) { childViews }

        case .spacer:
            Spacer()

        case .divider:
            Divider()

        // MARK: Content
        case .text:
            Text(node.props.content ?? "")

        case .image:
            if let systemName = node.props.systemName {
                Image(systemName: systemName)
                    .applyImageScale(node.props.imageScale)
            } else {
                Image(systemName: "questionmark.circle")
            }

        case .label:
            if let systemName = node.props.systemName {
                Label(node.props.content ?? "", systemImage: systemName)
            } else {
                Label(node.props.content ?? "", systemImage: "circle")
            }

        case .link:
            if let urlStr = node.props.url, let url = URL(string: urlStr) {
                Link(node.props.content ?? urlStr, destination: url)
            } else {
                Text(node.props.content ?? "Invalid URL")
            }

        case .progressView:
            if let value = node.props.value {
                ProgressView(value: value, total: node.props.total ?? 1.0)
            } else {
                ProgressView()
            }

        // MARK: Input Controls
        case .button:
            Button(action: { onEvent(node.id, "tap") }) {
                if let children = node.children, !children.isEmpty {
                    ForEach(children) { child in
                        DynamicView(node: child, onEvent: onEvent)
                    }
                } else {
                    Text(node.props.label ?? node.props.content ?? "Button")
                }
            }

        case .textField:
            StatefulTextField(
                placeholder: node.props.placeholder ?? "",
                initialText: node.props.text ?? "",
                style: node.props.style,
                nodeId: node.id,
                onEvent: onEvent
            )

        case .secureField:
            StatefulSecureField(
                placeholder: node.props.placeholder ?? "",
                initialText: node.props.text ?? "",
                style: node.props.style,
                nodeId: node.id,
                onEvent: onEvent
            )

        case .toggle:
            StatefulToggle(
                label: node.props.label ?? "",
                isOn: node.props.isOn ?? false,
                nodeId: node.id,
                onEvent: onEvent
            )

        case .picker:
            StatefulPicker(
                label: node.props.label ?? "",
                selection: node.props.selection ?? "",
                options: node.props.options ?? [],
                pickerStyle: node.props.pickerStyle,
                nodeId: node.id,
                onEvent: onEvent
            )

        // MARK: Containers
        case .scrollView:
            ScrollView(scrollAxes(from: node.props.axes),
                       showsIndicators: node.props.showsIndicators ?? true) {
                VStack { childViews }
            }

        case .list:
            List { childViews }

        case .form:
            buildForm()

        case .section:
            Section {
                childViews
            } header: {
                if let header = node.props.header {
                    Text(header)
                }
            } footer: {
                if let footer = node.props.footer {
                    Text(footer)
                }
            }

        case .group:
            Group { childViews }
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func buildForm() -> some View {
        let style = node.props.formStyle ?? "grouped"
        switch style.lowercased() {
        case "columns":
            Form { childViews }.formStyle(.columns)
        default:
            Form { childViews }.formStyle(.grouped)
        }
    }

    private func scrollAxes(from axes: String?) -> Axis.Set {
        switch axes?.lowercased() {
        case "horizontal": return .horizontal
        case "both": return [.horizontal, .vertical]
        default: return .vertical
        }
    }
}

// MARK: - Legacy inline style fallbacks

extension View {
    @ViewBuilder
    func applyLegacyPadding(_ padding: Double?, hasModifier: Bool) -> some View {
        if !hasModifier, let p = padding {
            self.padding(CGFloat(p))
        } else {
            self
        }
    }

    @ViewBuilder
    func applyLegacyFont(_ font: String?, hasModifier: Bool) -> some View {
        if !hasModifier, let fontName = font {
            self.font(Font.mguiNamed(fontName, size: nil, weight: nil))
        } else {
            self
        }
    }

    @ViewBuilder
    func applyLegacyForeground(_ color: String?, hasModifier: Bool) -> some View {
        if !hasModifier, let colorName = color {
            self.foregroundStyle(Color(mguiColor: colorName))
        } else {
            self
        }
    }
}

// MARK: - Image scale helper

extension View {
    @ViewBuilder
    func applyImageScale(_ scale: String?) -> some View {
        switch scale {
        case "small":  self.imageScale(.small)
        case "large":  self.imageScale(.large)
        default:       self.imageScale(.medium)
        }
    }
}
