import SwiftUI

struct IconPicker: View {
    @Binding var selectedIcon: String
    @State private var searchText = ""
    @State private var showIconPicker = false

    // Common SF Symbols that would be useful for prompts
    private let commonIcons = [
        "text.quote", "text.bubble", "pencil", "doc.text",
        "wand.and.stars", "sparkles", "lightbulb", "brain",
        "list.bullet", "checkmark.circle", "arrow.right.circle",
        "doc.on.doc", "envelope", "paperplane", "book",
        "highlighter", "trash", "folder", "gear",
        "keyboard", "textformat", "bold", "italic",
        "underline", "list.number", "list.bullet", "person",
        "person.2", "heart", "star", "eyes",
        "hand.raised", "hand.thumbsup", "hand.thumbsdown", "exclamationmark.bubble",
    ]

    var filteredIcons: [String] {
        if searchText.isEmpty {
            return commonIcons
        } else {
            return commonIcons.filter { $0.contains(searchText.lowercased()) }
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("Icon")
                .font(.headline)

            HStack {
                Image(systemName: selectedIcon)
                    .font(.system(size: 24))
                    .frame(width: 40, height: 40)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(6)

                Button("Choose Icon") {
                    showIconPicker = true
                }
            }
        }
        .sheet(isPresented: $showIconPicker) {
            VStack {
                TextField("Search icons", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()

                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))]) {
                        ForEach(filteredIcons, id: \.self) { iconName in
                            Button(action: {
                                selectedIcon = iconName
                                showIconPicker = false
                            }) {
                                VStack {
                                    Image(systemName: iconName)
                                        .font(.system(size: 24))
                                        .frame(width: 40, height: 40)
                                        .padding(5)
                                    Text(iconName)
                                        .font(.system(size: 9))
                                        .lineLimit(1)
                                }
                                .padding(5)
                                .background(selectedIcon == iconName ? Color.blue.opacity(0.2) : Color.clear)
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding()
                }

                Button("Cancel") {
                    showIconPicker = false
                }
                .padding()
            }
            .frame(width: 400, height: 500)
        }
    }
}
