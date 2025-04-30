import SwiftUI

struct RoundedBorderTextEditorStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(4)
            .background(Color(.textBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
    }
}

extension View {
    func roundedBorderTextEditor() -> some View {
        modifier(RoundedBorderTextEditorStyle())
    }
}
