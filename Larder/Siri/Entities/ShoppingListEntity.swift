import AppIntents
import Foundation

/// A small, bounded set that's a poor fit for Spotlight, so `EnumerableEntityQuery` is the right
/// tool. Every lookup runs `allEntities()` in the app, and Siri only queries it when the app is named.
/// The items come from the Reminders list with the same name.
struct ShoppingListEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Shopping List"
    static let defaultQuery = ShoppingListQuery()

    let id: String

    @Property(title: "Name", description: "The list's name, such as Groceries or Farmers Market")
    var name: String

    @Property(title: "Items to Buy", description: "What's still unchecked on the list")
    var remainingItems: [String]

    @Property(title: "Bought Items", description: "What's already checked off the list")
    var boughtItems: [String]

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(remainingItems.count) to buy")
    }

    init(id: String, name: String, remainingItems: [String], boughtItems: [String]) {
        self.id = id
        self.name = name
        self.remainingItems = remainingItems
        self.boughtItems = boughtItems
    }

    init(_ list: ShoppingList, items: [ShoppingItem]) {
        self.init(
            id: list.id,
            name: list.name,
            remainingItems: items.filter { !$0.isChecked }.map(\.name),
            boughtItems: items.filter(\.isChecked).map(\.name)
        )
    }
}

struct ShoppingListQuery: EnumerableEntityQuery {
    @Dependency private var store: LarderStore

    @MainActor
    func allEntities() async throws -> [ShoppingListEntity] {
        var entities: [ShoppingListEntity] = []
        for list in store.allShoppingLists() {
            entities.append(try await store.shoppingListEntity(id: list.id))
        }
        return entities
    }

    @MainActor
    func entities(for identifiers: [ShoppingListEntity.ID]) async throws -> [ShoppingListEntity] {
        var entities: [ShoppingListEntity] = []
        for id in identifiers where store.shoppingList(id: id) != nil {
            entities.append(try await store.shoppingListEntity(id: id))
        }
        return entities
    }
}

extension LarderStore {
    func shoppingListEntity(id: String) async throws -> ShoppingListEntity {
        guard let list = shoppingList(id: id) else { throw LarderError.shoppingListNotFound }
        return ShoppingListEntity(list, items: try await items(inList: id))
    }
}
