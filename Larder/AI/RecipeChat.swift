import Foundation
import FoundationModels
import Observation

/// A multi-turn conversation. The session keeps the transcript, so follow-up questions have context.
@MainActor
@Observable
final class RecipeChat {
    struct Message: Identifiable {
        enum Role { case person, chef }

        let id = UUID()
        let role: Role
        var text: String
    }

    private(set) var messages: [Message] = []
    private(set) var isResponding = false
    /// Items the model offered to add. Nothing changes until the person confirms.
    private(set) var proposedItems: [String] = []
    private(set) var addedMessage: String?

    private let store: LarderStore
    @ObservationIgnored private var session: LanguageModelSession?

    init(recipe: RecipeEntity, store: LarderStore) {
        self.store = store
        // Family notes can go into the prompt because this model runs on the device.
        let session = LanguageModelSession(
            tools: [ProposeGroceriesTool(chat: self)],
            instructions: ChefPrompts.chatInstructions(
                name: recipe.name,
                servings: recipe.servings,
                minutes: recipe.minutes,
                ingredients: recipe.ingredients,
                familyNotes: recipe.familyNotes
            )
        )
        session.prewarm()
        self.session = session
    }

    func ask(_ question: String) async {
        guard let session else { return }
        messages.append(Message(role: .person, text: question))
        messages.append(Message(role: .chef, text: ""))
        let index = messages.count - 1
        isResponding = true
        proposedItems = []
        addedMessage = nil
        defer { isResponding = false }

        do {
            for try await snapshot in session.streamResponse(to: question) {
                messages[index].text = snapshot.content
            }
        } catch {
            messages[index].text = ChefModel.message(for: error)
        }
    }

    func propose(_ items: [String]) {
        proposedItems = items
    }

    func addProposedItems() async {
        do {
            let added = try await store.addItems(proposedItems, toList: SeedData.defaultListID)
            addedMessage = added.isEmpty ? "Already on Groceries." : "Added \(added.count) to Groceries."
            proposedItems = []
        } catch {
            addedMessage = error.localizedDescription
        }
    }
}
