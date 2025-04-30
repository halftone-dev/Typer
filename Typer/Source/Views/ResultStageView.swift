import SwiftUI

struct ResultStageView: View {
    let result: String
    let onApply: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview Result")
                .font(.headline)
                .foregroundColor(.gray)

            ScrollView {
                Text(result)
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
            }
            .frame(maxHeight: 200)

            HStack {
                Button(action: onCancel) {
                    Text("Close")
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: onApply) {
                    Text("Replace")
                        .foregroundColor(.black)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 350)
        .background(
            Color(red: 29 / 255, green: 33 / 255, blue: 42 / 255)
                .cornerRadius(15) // Match the window corner radius
        )
    }
}
