import Foundation

struct CustomPrompt: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var systemPrompt: String
    var userPrompt: String
    var iconName: String
    var isEnabled: Bool

    static func == (lhs: CustomPrompt, rhs: CustomPrompt) -> Bool {
        lhs.id == rhs.id
    }
}
