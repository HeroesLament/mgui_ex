import Foundation
import SwiftUI
import AppKit

// MARK: - SwiftUI Color Parsing

extension Color {
    /// Parse a color string like "red", "#FF5733", "blue:0.5"
    init(mguiColor: String) {
        // Check for opacity suffix  e.g. "red:0.8" or "#FF5733:0.5"
        if let colonIndex = mguiColor.lastIndex(of: ":") {
            let colorPart = String(mguiColor[..<colonIndex])
            let opacityPart = String(mguiColor[mguiColor.index(after: colonIndex)...])

            if let opacity = Double(opacityPart) {
                let baseColor = Color.parseBaseColor(colorPart)
                self = baseColor.opacity(opacity)
                return
            }
        }

        self = Color.parseBaseColor(mguiColor)
    }

    private static func parseBaseColor(_ s: String) -> Color {
        switch s.lowercased() {
        // Basic
        case "red":     return .red
        case "blue":    return .blue
        case "green":   return .green
        case "yellow":  return .yellow
        case "orange":  return .orange
        case "purple":  return .purple
        case "pink":    return .pink
        case "white":   return .white
        case "black":   return .black
        case "gray", "grey": return .gray
        case "clear":   return .clear

        // Extended
        case "indigo":  return .indigo
        case "cyan":    return .cyan
        case "mint":    return .mint
        case "teal":    return .teal
        case "brown":   return .brown

        // Semantic
        case "primary":                return .primary
        case "secondary":              return .secondary
        case "accentcolor", "accent":  return .accentColor

        default:
            if s.hasPrefix("#") {
                return Color(hex: s)
            }
            return .primary
        }
    }

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Alignment Parsing

extension HorizontalAlignment {
    init(mgui: String?) {
        switch mgui?.lowercased() {
        case "leading":  self = .leading
        case "trailing": self = .trailing
        default:         self = .center
        }
    }
}

extension VerticalAlignment {
    init(mgui: String?) {
        switch mgui?.lowercased() {
        case "top":    self = .top
        case "bottom": self = .bottom
        default:       self = .center
        }
    }
}

extension Alignment {
    init(mgui: String?) {
        switch mgui?.lowercased() {
        case "topleading":    self = .topLeading
        case "top":           self = .top
        case "toptrailing":   self = .topTrailing
        case "leading":       self = .leading
        case "trailing":      self = .trailing
        case "bottomleading": self = .bottomLeading
        case "bottom":        self = .bottom
        case "bottomtrailing": self = .bottomTrailing
        default:              self = .center
        }
    }
}
