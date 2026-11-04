import Foundation
import SwiftData

// Identifiers are stable strings on purpose. Siri, donations, and saved shortcuts keep references
// to them, so a UUID() generated at launch would break every saved reference.

@Model
final class Recipe {
    @Attribute(.unique) var id: String
    var name: String
    var summary: String
    var cuisineRawValue: String
    var minutes: Int
    var servings: Int
    var ingredients: [String]
    var instructions: String
    var familyNotes: String
    var revision: Int

    var cuisine: Cuisine { Cuisine(rawValue: cuisineRawValue) ?? .other }

    init(
        id: String,
        name: String,
        summary: String,
        cuisine: Cuisine,
        minutes: Int,
        servings: Int,
        ingredients: [String],
        instructions: String,
        familyNotes: String = "",
        revision: Int = 1
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.cuisineRawValue = cuisine.rawValue
        self.minutes = minutes
        self.servings = servings
        self.ingredients = ingredients
        self.instructions = instructions
        self.familyNotes = familyNotes
        self.revision = revision
    }
}

@Model
final class MealPlanEntry {
    /// One meal per slot, so the identifier is derived from the day and the meal.
    @Attribute(.unique) var id: String
    var date: Date
    var mealRawValue: String
    var recipeID: String

    var meal: MealType { MealType(rawValue: mealRawValue) ?? .dinner }

    init(id: String, date: Date, meal: MealType, recipeID: String) {
        self.id = id
        self.date = date
        self.mealRawValue = meal.rawValue
        self.recipeID = recipeID
    }
}

/// A list Larder shops from. The items live in the Reminders list with the same name, so the
/// identifier stays a stable slug even though the Reminders list's own identifier can change on sync.
struct ShoppingList: Identifiable, Hashable {
    let id: String
    let name: String
}

/// A snapshot of one reminder. EventKit objects aren't `Sendable`, so they're copied into this
/// value right after a fetch.
struct ShoppingItem: Identifiable, Hashable {
    /// The reminder's `calendarItemIdentifier`.
    let id: String
    var name: String
    var isChecked: Bool
    var createdAt: Date
}

@Model
final class JournalEntry {
    @Attribute(.unique) var id: String
    var title: String?
    var message: String
    var date: Date

    init(id: String = UUID().uuidString, title: String?, message: String, date: Date) {
        self.id = id
        self.title = title
        self.message = message
        self.date = date
    }
}
