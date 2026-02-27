//
//  LocoTheme.swift
//  loco-ios
//
//  Design system for Loco app
//

import SwiftUI

enum LocoTheme {
    
    // MARK: - Colors
    
    enum Colors {
        // Background
        static let cream = Color(hex: "FCFBF4")
        
        // Accent colors from design
        static let softBlue = Color(hex: "B8E1FF")
        static let goldenSand = Color(hex: "F7D08A")
        static let coral = Color(hex: "FF7F50")
        static let navy = Color(hex: "2C3E6B")
        
        // UI elements
        static let textPrimary = Color(hex: "2C3E6B")
        static let textSecondary = Color(hex: "8E99A4")
        static let inputBackground = Color.white
        static let buttonPrimary = Color(hex: "FF8A80")
    }
    
    // MARK: - Typography
    
    enum Typography {
        static func logo(_ size: CGFloat = 48) -> Font {
            .system(size: size, weight: .bold, design: .rounded)
        }
        
        static func body(_ size: CGFloat = 16) -> Font {
            .system(size: size, weight: .regular)
        }
        
        static func button(_ size: CGFloat = 18) -> Font {
            .system(size: size, weight: .semibold)
        }
    }
    
    // MARK: - Spacing
    
    enum Spacing {
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    
    enum Radius {
        static let input: CGFloat = 25
        static let button: CGFloat = 25
        static let circle: CGFloat = 40
    }
}

// MARK: - Color Extension for Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
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
