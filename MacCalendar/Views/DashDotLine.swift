//
//  DashDotLine.swift
//  MacCalendar
//
//  Created by next on 2026/1/30.
//
import SwiftUI

struct DashDotLine: View {
    // 建议使用 .separator 或 .secondary.opacity(0.3)
    var color: Color = Color(NSColor.separatorColor)
    
    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: 0, y: size.height / 2))
            path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
            
            context.stroke(
                path,
                with: .color(color),
                style: StrokeStyle(
                    lineWidth: 0.5,       // 减薄线条，更有高级感
                    lineCap: .round,
                    dash: [3, 3],        // 缩短线段和间距，形成细腻的虚线
                    dashPhase: 0
                )
            )
        }
        .frame(height: 1) // 保持细微的高度占位
        .opacity(0.6)     // 进一步降低视觉权重
    }
}
