import SwiftUI

/// Maps goal SF Symbol icons to distinct colors.
enum GoalIconPalette {
    static func color(for icon: String) -> Color {
        iconColors[icon] ?? fallbackColor(for: icon)
    }
    
    private static let iconColors: [String: Color] = [
        "star.fill": .yellow,
        "heart.fill": .pink,
        "bolt.fill": .yellow,
        "flame.fill": .orange,
        "figure.run": .orange,
        "book.fill": .brown,
        "brain.head.profile": .purple,
        "leaf.fill": .green,
        "lightbulb.fill": .yellow,
        "hammer.fill": .gray,
        "drop.fill": .cyan,
        "moon.fill": .indigo,
        "sun.max.fill": .orange,
        "pencil": .blue,
        "music.note": .pink,
        "gamecontroller.fill": .purple,
        "cart.fill": .green,
        "phone.fill": .green,
        "envelope.fill": .blue,
        "house.fill": .teal,
        "car.fill": .blue,
        "airplane": .cyan,
        "graduationcap.fill": .indigo,
        "dollarsign.circle.fill": .green,
    ]
    
    private static let fallbackColors: [Color] = [
        .blue, .purple, .pink, .teal, .indigo, .mint, .cyan, .orange
    ]
    
    private static func fallbackColor(for icon: String) -> Color {
        let index = abs(icon.hashValue) % fallbackColors.count
        return fallbackColors[index]
    }
}

struct GoalIconView: View {
    let icon: String
    var size: CGFloat = 14
    var isActive: Bool = true
    
    private var tint: Color {
        isActive ? GoalIconPalette.color(for: icon) : .gray
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(isActive ? 0.18 : 0.08))
                .frame(width: size + 10, height: size + 10)
            
            Image(systemName: icon)
                .font(.system(size: size, weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(width: size + 10, height: size + 10)
    }
}
