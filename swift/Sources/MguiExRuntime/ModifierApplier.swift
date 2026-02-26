import SwiftUI

// MARK: - Modifier Chain

/// Iteratively applies an array of modifiers using AnyView type erasure.
/// For dynamic modifier chains this is necessary and the performance cost is acceptable
/// since SwiftUI diffing still works on the ViewNode identity.
struct MguiModifierChain: ViewModifier {
    let modifiers: [ViewNode.ViewModifier]

    func body(content: Content) -> some View {
        var result = AnyView(content)
        for modifier in modifiers {
            result = AnyView(result.applySingleModifier(modifier))
        }
        return result
    }
}

extension View {
    /// Apply an optional array of modifiers. No-op if nil or empty.
    @ViewBuilder
    func applyModifiers(_ modifiers: [ViewNode.ViewModifier]?) -> some View {
        if let modifiers = modifiers, !modifiers.isEmpty {
            self.modifier(MguiModifierChain(modifiers: modifiers))
        } else {
            self
        }
    }

    /// Dispatch a single modifier by type
    @ViewBuilder
    func applySingleModifier(_ modifier: ViewNode.ViewModifier) -> some View {
        switch modifier.type {
        // Layout
        case .frame:        applyFrameMod(modifier.args)
        case .padding:      applyPaddingMod(modifier.args)
        case .cornerRadius: applyCornerRadiusMod(modifier.args)
        case .clipShape:    applyClipShapeMod(modifier.args)
        case .offset:       applyOffsetMod(modifier.args)

        // Appearance
        case .background:      applyBackgroundMod(modifier.args)
        case .foregroundColor:  applyForegroundColorMod(modifier.args)
        case .opacity:          applyOpacityMod(modifier.args)
        case .shadow:           applyShadowMod(modifier.args)
        case .border:           applyBorderMod(modifier.args)

        // Typography
        case .font:  applyFontMod(modifier.args)

        // Transform
        case .scale: applyScaleMod(modifier.args)
        }
    }
}

// MARK: - Layout Modifiers

extension View {
    @ViewBuilder
    func applyFrameMod(_ args: ViewNode.ViewModifier.ModifierArgs) -> some View {
        // First pass: min/max constraints
        self
            .frame(
                minWidth:  args.minWidth.map  { CGFloat($0) },
                maxWidth:  args.maxWidth == "infinity" ? .infinity : nil,
                minHeight: args.minHeight.map { CGFloat($0) },
                maxHeight: args.maxHeight == "infinity" ? .infinity : nil
            )
            // Second pass: exact dimensions (only if not overridden by max)
            .frame(
                width:  args.maxWidth == nil  ? args.width.map  { CGFloat($0) } : nil,
                height: args.maxHeight == nil ? args.height.map { CGFloat($0) } : nil
            )
    }

    @ViewBuilder
    func applyPaddingMod(_ args: ViewNode.ViewModifier.ModifierArgs) -> some View {
        if let value = args.value {
            self.padding(CGFloat(value))
        } else if args.horizontal != nil || args.vertical != nil {
            self
                .padding(.horizontal, CGFloat(args.horizontal ?? 0))
                .padding(.vertical, CGFloat(args.vertical ?? 0))
        } else if args.top != nil || args.leading != nil || args.bottom != nil || args.trailing != nil {
            self.padding(EdgeInsets(
                top:      CGFloat(args.top ?? 0),
                leading:  CGFloat(args.leading ?? 0),
                bottom:   CGFloat(args.bottom ?? 0),
                trailing: CGFloat(args.trailing ?? 0)
            ))
        } else {
            // bare .padding() — use SwiftUI default
            self.padding()
        }
    }

    @ViewBuilder
    func applyCornerRadiusMod(_ args: ViewNode.ViewModifier.ModifierArgs) -> some View {
        if let radius = args.value ?? args.cornerRadius {
            self.cornerRadius(CGFloat(radius))
        } else {
            self
        }
    }

    @ViewBuilder
    func applyClipShapeMod(_ args: ViewNode.ViewModifier.ModifierArgs) -> some View {
        if let shape = args.shape {
            switch shape.lowercased() {
            case "capsule":
                self.clipShape(Capsule())
            case "circle":
                self.clipShape(Circle())
            case "roundedrectangle":
                let radius = args.cornerRadius ?? 10
                self.clipShape(RoundedRectangle(cornerRadius: CGFloat(radius)))
            default:
                self
            }
        } else {
            self
        }
    }

    @ViewBuilder
    func applyOffsetMod(_ args: ViewNode.ViewModifier.ModifierArgs) -> some View {
        self.offset(
            x: CGFloat(args.offsetX ?? 0),
            y: CGFloat(args.offsetY ?? 0)
        )
    }
}

// MARK: - Appearance Modifiers

extension View {
    @ViewBuilder
    func applyBackgroundMod(_ args: ViewNode.ViewModifier.ModifierArgs) -> some View {
        if let colorName = args.color {
            self.background(Color(mguiColor: colorName))
        } else {
            self
        }
    }

    @ViewBuilder
    func applyForegroundColorMod(_ args: ViewNode.ViewModifier.ModifierArgs) -> some View {
        if let colorName = args.color {
            self.foregroundStyle(Color(mguiColor: colorName))
        } else {
            self
        }
    }

    @ViewBuilder
    func applyOpacityMod(_ args: ViewNode.ViewModifier.ModifierArgs) -> some View {
        if let opacity = args.opacity {
            self.opacity(opacity)
        } else {
            self
        }
    }

    @ViewBuilder
    func applyShadowMod(_ args: ViewNode.ViewModifier.ModifierArgs) -> some View {
        let color = args.shadowColor.map { Color(mguiColor: $0) } ?? Color.black.opacity(0.2)
        let radius = CGFloat(args.shadowRadius ?? 4)
        let x = CGFloat(args.shadowX ?? 0)
        let y = CGFloat(args.shadowY ?? 2)
        self.shadow(color: color, radius: radius, x: x, y: y)
    }

    @ViewBuilder
    func applyBorderMod(_ args: ViewNode.ViewModifier.ModifierArgs) -> some View {
        let color = args.borderColor.map { Color(mguiColor: $0) } ?? Color.gray
        let width = CGFloat(args.borderWidth ?? 1)

        if let shape = args.shape {
            switch shape.lowercased() {
            case "capsule":
                self.overlay(Capsule().stroke(color, lineWidth: width))
            case "circle":
                self.overlay(Circle().stroke(color, lineWidth: width))
            case "roundedrectangle":
                let radius = CGFloat(args.cornerRadius ?? 10)
                self.overlay(RoundedRectangle(cornerRadius: radius).stroke(color, lineWidth: width))
            default:
                self.border(color, width: width)
            }
        } else {
            self.border(color, width: width)
        }
    }
}

// MARK: - Font Modifier

extension View {
    @ViewBuilder
    func applyFontMod(_ args: ViewNode.ViewModifier.ModifierArgs) -> some View {
        if let fontName = args.fontName {
            // Named system style or custom font
            let font = Font.mguiNamed(fontName, size: args.fontSize, weight: args.fontWeight)
            self.font(font)
        } else if let size = args.fontSize {
            self.font(.system(size: CGFloat(size), weight: Font.Weight.mgui(args.fontWeight)))
        } else {
            self
        }
    }
}

extension Font {
    static func mguiNamed(_ name: String, size: Double?, weight: String?) -> Font {
        switch name.lowercased() {
        case "largetitle":  return .largeTitle
        case "title":       return .title
        case "title2":      return .title2
        case "title3":      return .title3
        case "headline":    return .headline
        case "subheadline": return .subheadline
        case "body":        return .body
        case "callout":     return .callout
        case "caption":     return .caption
        case "caption2":    return .caption2
        case "footnote":    return .footnote
        default:
            // Try as custom font family
            if let fontSize = size {
                if let nsFont = NSFont(name: name, size: CGFloat(fontSize)) {
                    return Font(nsFont)
                }
                return .system(size: CGFloat(fontSize), weight: Font.Weight.mgui(weight))
            }
            return .body
        }
    }
}

extension Font.Weight {
    static func mgui(_ weight: String?) -> Font.Weight {
        switch weight?.lowercased() {
        case "ultralight": return .ultraLight
        case "thin":       return .thin
        case "light":      return .light
        case "regular":    return .regular
        case "medium":     return .medium
        case "semibold":   return .semibold
        case "bold":       return .bold
        case "heavy":      return .heavy
        case "black":      return .black
        default:           return .regular
        }
    }
}

// MARK: - Transform Modifiers

extension View {
    @ViewBuilder
    func applyScaleMod(_ args: ViewNode.ViewModifier.ModifierArgs) -> some View {
        if let scale = args.scale {
            self.scaleEffect(CGFloat(scale))
        } else {
            self
        }
    }
}
