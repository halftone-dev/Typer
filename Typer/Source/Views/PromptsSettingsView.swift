import SwiftUI

struct PromptsSettingsView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @State private var selectedPromptID: UUID?

    var body: some View {
        VStack {
            HStack(spacing: 0) {
                List(settings.customPrompts, selection: $selectedPromptID) { prompt in
                    HStack {
                        Image(systemName: prompt.iconName)
                            .foregroundColor(selectedPromptID == prompt.id ? .white : .accentColor)
                        Text(prompt.title)
                    }
                }
                .frame(width: 200)
                .listStyle(SidebarListStyle())

                Divider()

                if let selectedID = selectedPromptID,
                   let promptIndex = settings.customPrompts.firstIndex(where: { $0.id == selectedID })
                {
                    promptDetailView(for: $settings.customPrompts[promptIndex])
                        .padding()
                } else {
                    VStack {
                        Spacer()
                        Text("Select a prompt or add a new one")
                            .foregroundColor(.gray)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            Divider()

            HStack {
                Button(action: {
                    var newPrompt = CustomPrompt(
                        title: "New Prompt",
                        systemPrompt: "",
                        userPrompt: "Please transform the following text:\n\n{{text}}",
                        iconName: "text.quote",
                        isEnabled: true
                    )
                    settings.customPrompts.append(newPrompt)
                    selectedPromptID = newPrompt.id
                }) {
                    Label("Add", systemImage: "plus")
                }

                Spacer()

                if selectedPromptID != nil {
                    Button(action: {
                        if let selectedID = selectedPromptID,
                           let index = settings.customPrompts.firstIndex(where: { $0.id == selectedID })
                        {
                            settings.customPrompts.remove(at: index)
                            selectedPromptID = nil
                        }
                    }) {
                        Label("Delete", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
            .padding()
            .navigationTitle("Settings")
        }
    }

    @ViewBuilder
    func promptDetailView(for prompt: Binding<CustomPrompt>) -> some View {
        ScrollView {
            Form {
                Toggle("Enabled", isOn: prompt.isEnabled)
                Divider()
                Section {
                    TextField("Title", text: prompt.title)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    IconPicker(selectedIcon: prompt.iconName)
                }
                .padding(.bottom, 16)

                Section {
                    Text("System Prompt")
                        .font(.headline)
                    TextEditor(text: prompt.systemPrompt)
                        .frame(minHeight: 80, maxHeight: 120)
                        .roundedBorderTextEditor()

                    Text("User Prompt")
                        .font(.headline)
                        .padding(.top, 8)
                    Text("Use {{text}} to reference the selected text")
                        .font(.caption)
                        .foregroundColor(.gray)
                    TextEditor(text: prompt.userPrompt)
                        .frame(minHeight: 80, maxHeight: 120)
                        .roundedBorderTextEditor()
                }
            }
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
