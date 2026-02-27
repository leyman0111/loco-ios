//
//  LocoLogoView.swift
//  loco-ios
//
//  Shared Loco logo component matching the design mockup:
//  "Loc" in bold navy + custom map pin replacing the "o"
//  The pin is a teardrop shape (navy) with a coral circle inside
//

import SwiftUI

struct LocoLogoView: View {
    var fontSize: CGFloat = 56
    
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            Text("Loc")
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .foregroundColor(LocoTheme.Colors.navy)
            
            // Custom map pin replacing the letter "O"
            MapPinLogoShape(fontSize: fontSize)
        }
    }
}

// MARK: - Custom Map Pin Logo Shape

struct MapPinLogoShape: View {
    var fontSize: CGFloat
    
    // Pin dimensions scaled to font size
    private var pinWidth: CGFloat { fontSize * 0.72 }
    private var pinHeight: CGFloat { fontSize * 0.95 }
    private var dotSize: CGFloat { fontSize * 0.22 }
    
    var body: some View {
        ZStack(alignment: .top) {
            // Teardrop pin body drawn with Canvas
            Canvas { context, size in
                let w = size.width
                let h = size.height
                
                // The teardrop: circle on top, pointed bottom
                let circleRadius = w / 2
                let circleCenter = CGPoint(x: w / 2, y: circleRadius)
                
                var path = Path()
                // Circle arc (top part)
                path.addArc(
                    center: circleCenter,
                    radius: circleRadius,
                    startAngle: .degrees(150),
                    endAngle: .degrees(30),
                    clockwise: false
                )
                // Lines converging to bottom point
                path.addLine(to: CGPoint(x: w / 2, y: h))
                path.closeSubpath()
                
                context.fill(path, with: .color(LocoTheme.Colors.navy))
            }
            .frame(width: pinWidth, height: pinHeight)
            
            // Coral dot inside pin (like the "o" hole)
            Circle()
                .fill(LocoTheme.Colors.coral)
                .frame(width: dotSize, height: dotSize)
                .offset(y: pinWidth / 2 - dotSize / 2)
        }
        .frame(width: pinWidth, height: pinHeight)
        // Align baseline with text
        .alignmentGuide(.firstTextBaseline) { d in d[.bottom] + fontSize * 0.08 }
    }
}

#Preview {
    VStack(spacing: 32) {
        LocoLogoView(fontSize: 56)
        LocoLogoView(fontSize: 28)
    }
    .padding()
    .background(Color(hex: "FCFBF4"))
}
