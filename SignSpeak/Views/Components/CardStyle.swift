import SwiftUI

/// Rounded pale-turquoise container used for dashboard tiles, lesson cards and list sections.
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.cardBackground, in: .rect(cornerRadius: Theme.Radius.card))
            .shadow(color: .brandTurquoise.opacity(0.15), radius: 12, y: 4)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}

/// Reusable card container with pale-turquoise background, 20 pt corner radius, and subtle shadow.
struct CardView<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            content
        }
        .cardStyle()
    }
}
