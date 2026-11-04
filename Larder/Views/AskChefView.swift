import SwiftUI

struct AskChefView: View {
    @Environment(\.dismiss) private var dismiss
    let recipe: RecipeEntity
    let store: LarderStore
    // Created once, after ModelGate confirms the model can run, because a session holds the conversation.
    @State private var chat: RecipeChat?

    var body: some View {
        NavigationStack {
            ModelGate {
                if let chat {
                    AskChefConversation(chat: chat, recipe: recipe)
                } else {
                    ProgressView().onAppear { chat = RecipeChat(recipe: recipe, store: store) }
                }
            }
            .background { ArtworkBackground(palette: ArtworkPalette(id: recipe.id, cuisine: recipe.cuisine)) }
            .navigationTitle("Ask Chef")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .environment(\.colorScheme, .dark)
    }
}

private struct AskChefConversation: View {
    let chat: RecipeChat
    let recipe: RecipeEntity
    @State private var question = ""

    private let suggestions = ["What can I substitute?", "Can I make it ahead?", "Add olive oil to my groceries"]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if chat.messages.isEmpty {
                    intro
                }
                ForEach(chat.messages) { message in
                    bubble(message)
                }
                if !chat.proposedItems.isEmpty, !chat.isResponding {
                    Button("Add \(chat.proposedItems.joined(separator: ", ")) to Groceries", systemImage: "cart.badge.plus") {
                        Task { await chat.addProposedItems() }
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.white)
                    .foregroundStyle(.black)
                }
                if let added = chat.addedMessage {
                    Text(added).font(.footnote).foregroundStyle(.secondary)
                }
            }
            .padding(20)
        }
        .defaultScrollAnchor(.bottom)
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                ChefComposer(prompt: "Ask about this recipe", text: $question, isBusy: chat.isResponding) {
                    send(question)
                }
                // In testing, the model occasionally suggested an ingredient the notes ruled out.
                Text("Chef can make mistakes. Always check allergens yourself.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 14) {
            RecipeArtwork(
                id: recipe.id,
                name: recipe.name,
                cuisine: recipe.cuisine,
                ingredients: recipe.ingredients,
                style: .thumbnail,
                cornerRadius: 14
            )
            .frame(width: 84, height: 84)
            Text("Ask About \(recipe.name)")
                .font(.largeTitle.bold())
            VStack(alignment: .leading, spacing: 10) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button(suggestion) { send(suggestion) }
                        .buttonStyle(.glass)
                }
            }
        }
    }

    @ViewBuilder
    private func bubble(_ message: RecipeChat.Message) -> some View {
        switch message.role {
        case .person:
            Text(message.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .glassEffect(in: .rect(cornerRadius: 20))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.leading, 40)
        case .chef:
            if message.text.isEmpty {
                ProgressView()
            } else {
                Text(message.text)
            }
        }
    }

    private func send(_ text: String) {
        guard !text.isEmpty, !chat.isResponding else { return }
        question = ""
        Task { await chat.ask(text) }
    }
}
