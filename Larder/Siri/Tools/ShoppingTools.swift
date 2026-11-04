import AppIntents
import Foundation

@AppIntent(.tool)
struct AddRecipeIngredientsIntent {
    static let title: LocalizedStringResource = "Add Recipe Ingredients to Shopping List"
    static let description = IntentDescription(
        "Adds everything a recipe needs to a shopping list and skips what's already on it. For one item that isn't tied to a recipe, use the Add Item to Shopping List tool.",
        searchKeywords: ["buy", "groceries", "shop"]
    )

    @Parameter(title: "Recipe", description: "The recipe whose ingredients to add")
    var recipe: RecipeEntity

    @Parameter(title: "List", description: "The list to add to. Leave empty for Groceries.")
    var list: ShoppingListEntity?

    @Dependency private var store: LarderStore

    init() {}

    init(recipe: RecipeEntity, list: ShoppingListEntity? = nil) {
        self.recipe = recipe
        self.list = list
    }

    @MainActor
    func perform() async throws -> some ReturnsValue<ShoppingListEntity> & ProvidesDialog {
        let listID = list?.id ?? SeedData.defaultListID
        let added = try await store.addItems(recipe.ingredients, toList: listID)
        let updated = try await store.shoppingListEntity(id: listID)
        // Says so when nothing changed, so Siri doesn't report items as added.
        let dialog: IntentDialog = added.isEmpty
            ? "Everything for \(recipe.name) is already on \(updated.name)."
            : "Added \(added.count) items for \(recipe.name) to \(updated.name)."
        return .result(value: updated, dialog: dialog)
    }
}

@AppIntent(.tool)
struct AddItemToShoppingListIntent {
    static let title: LocalizedStringResource = "Add Item to Shopping List"
    static let description = IntentDescription(
        "Adds one thing the person named to a shopping list. For everything a recipe needs, use the Add Recipe Ingredients to Shopping List tool.",
        searchKeywords: ["buy", "groceries", "remember to get"]
    )

    @Parameter(title: "Item", description: "What to buy, with an amount if the person gave one, such as 2 l milk")
    var item: String

    @Parameter(title: "List", description: "The list to add to. Leave empty for Groceries.")
    var list: ShoppingListEntity?

    @Dependency private var store: LarderStore

    @MainActor
    func perform() async throws -> some ReturnsValue<ShoppingListEntity> & ProvidesDialog {
        let listID = list?.id ?? SeedData.defaultListID
        let added = try await store.addItems([item], toList: listID)
        let updated = try await store.shoppingListEntity(id: listID)
        let dialog: IntentDialog = added.isEmpty
            ? "\(item) is already on \(updated.name)."
            : "Added \(item) to \(updated.name)."
        return .result(value: updated, dialog: dialog)
    }
}

@AppIntent(.tool)
struct GetShoppingListIntent {
    static let title: LocalizedStringResource = "Get Shopping List"
    static let description = IntentDescription(
        "Returns what's still to buy and what's already bought on a shopping list. Changes nothing.",
        searchKeywords: ["groceries", "what do I need"]
    )

    @Parameter(title: "List", description: "The list to read. Leave empty for Groceries.")
    var list: ShoppingListEntity?

    @Dependency private var store: LarderStore

    @MainActor
    func perform() async throws -> some ReturnsValue<ShoppingListEntity> & ProvidesDialog {
        let listID = list?.id ?? SeedData.defaultListID
        let entity = try await store.shoppingListEntity(id: listID)
        return .result(value: entity, dialog: "\(entity.name) has \(entity.remainingItems.count) items to buy.")
    }
}

@AppIntent(.tool)
struct ClearShoppingListIntent {
    static let title: LocalizedStringResource = "Clear Shopping List"
    static let description = IntentDescription(
        "Deletes every item from a shopping list after the person confirms. This can't be undone."
    )

    @Parameter(title: "List", description: "The list to empty")
    var list: ShoppingListEntity

    @Dependency private var store: LarderStore

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await requestConfirmation(dialog: "Delete everything on \(list.name)? This can't be undone.")
        try await store.clearList(id: list.id)
        return .result(dialog: "\(list.name) is empty.")
    }
}
