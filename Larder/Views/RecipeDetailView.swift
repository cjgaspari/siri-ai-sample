import AppIntents
import SwiftUI

struct RecipeDetailView: View {
    @Environment(LarderStore.self) private var store
    let recipe: Recipe
    @State private var confirmation: String?
    @State private var isAskingChef = false
    @State private var isTitleVisible = false

    private var palette: ArtworkPalette { ArtworkPalette(id: recipe.id, cuisine: recipe.cuisine) }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                header
                actions
                ingredients
                method
                if !recipe.familyNotes.isEmpty { familyNotes }
                Text("\(recipe.servings) servings, \(recipe.duration)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y + geometry.contentInsets.top > 340
        } action: { _, isPastHeader in
            withAnimation(.easeInOut(duration: 0.2)) { isTitleVisible = isPastHeader }
        }
        .background { ArtworkBackground(palette: palette) }
        .environment(\.colorScheme, .dark)
        .toolbarColorScheme(.dark, for: .navigationBar, .tabBar)
        .navigationTitle(recipe.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(recipe.name)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .opacity(isTitleVisible ? 1 : 0)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Ask Chef", systemImage: "sparkles") { isAskingChef = true }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu("More", systemImage: "ellipsis") {
                    Button("Plan for Dinner Tonight", systemImage: "calendar.badge.plus", action: planForTonight)
                    Button("Add Ingredients to Groceries", systemImage: "cart.badge.plus", action: addIngredients)
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let confirmation {
                ConfirmationHUD(message: confirmation)
                    .environment(\.colorScheme, .dark)
                    .padding(.bottom, 16)
            }
        }
        .task(id: confirmation) {
            guard confirmation != nil else { return }
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation { confirmation = nil }
        }
        .sensoryFeedback(.success, trigger: confirmation) { _, new in new != nil }
        .sheet(isPresented: $isAskingChef) {
            AskChefView(recipe: RecipeEntity(recipe), store: store)
        }
        // One primary item on screen: this is how Siri resolves "this recipe".
        .userActivity("com.artemnovichkov.Larder.viewRecipe") { activity in
            activity.title = recipe.name
            activity.appEntityIdentifier = EntityIdentifier(for: RecipeEntity.self, identifier: recipe.id)
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            RecipeArtwork(recipe, cornerRadius: 16)
                .frame(maxWidth: 270)
                .shadow(color: .black.opacity(0.4), radius: 24, y: 14)
                .padding(.bottom, 6)
            VStack(spacing: 4) {
                Text(recipe.name)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(recipe.byline)
                    .font(.headline)
                    .foregroundStyle(palette.colors[0].mix(with: .white, by: 0.45))
            }
            Text(recipe.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var actions: some View {
        GlassEffectContainer {
            HStack(spacing: 12) {
                Button {
                    store.startCooking(recipeID: recipe.id)
                } label: {
                    Label("Cook", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(.white)
                .foregroundStyle(.black)

                Button(action: planForTonight) {
                    Label("Tonight", systemImage: "calendar.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
            }
            .font(.headline)
            .controlSize(.large)
        }
    }

    private var ingredients: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                sectionTitle("Ingredients")
                Spacer()
                Button("Add to Groceries", systemImage: "cart.badge.plus", action: addIngredients)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
            }
            .padding(.bottom, 6)
            ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { index, ingredient in
                if index > 0 { Divider() }
                Text(ingredient)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 11)
            }
        }
    }

    private var method: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Method")
            ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.title3.bold())
                        .foregroundStyle(.secondary)
                        .frame(width: 24, alignment: .leading)
                    Text(step)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var familyNotes: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Family Notes", systemImage: "heart.text.square.fill")
                .font(.headline)
            Text(recipe.familyNotes)
            Text("Siri asks to unlock the device before reading this.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 18))
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.title3.bold())
            .accessibilityAddTraits(.isHeader)
    }

    private func planForTonight() {
        do {
            let today = Date.now
            try store.planMeal(recipeID: recipe.id, on: today, meal: .dinner)
            withAnimation { confirmation = "Planned for Dinner Tonight" }
            // The system only donates intents it runs. A tap in the app's own UI has to donate by hand.
            let intent = PlanMealIntent(recipe: RecipeEntity(recipe), date: today, meal: .dinner)
            Task { try? await IntentDonationManager.shared.donate(intent: intent) }
        } catch {
            withAnimation { confirmation = error.localizedDescription }
        }
    }

    private func addIngredients() {
        Task {
            do {
                let added = try await store.addItems(recipe.ingredients, toList: SeedData.defaultListID)
                withAnimation { confirmation = "Added \(added.count) Items to Groceries" }
                let intent = AddRecipeIngredientsIntent(recipe: RecipeEntity(recipe))
                _ = try? await IntentDonationManager.shared.donate(intent: intent)
            } catch {
                withAnimation { confirmation = error.localizedDescription }
            }
        }
    }
}
