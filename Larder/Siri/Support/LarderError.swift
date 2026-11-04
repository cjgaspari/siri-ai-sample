import Foundation

/// Siri reads these messages and uses them to decide what to do next, so each one says what went
/// wrong and what would fix it. Only `CustomLocalizedStringResourceConvertible` errors carry a message.
enum LarderError: Error, CustomLocalizedStringResourceConvertible {
    case recipeNotFound
    case plannedMealNotFound
    case shoppingListNotFound
    case remindersAccessDenied
    case emptyIngredients
    case invalidCookTime
    case invalidDayCount

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .recipeNotFound:
            "That recipe isn't in Larder anymore. Choose another recipe."
        case .plannedMealNotFound:
            "That meal isn't on the meal plan anymore. Get the meal plan again to see what's planned."
        case .shoppingListNotFound:
            "That shopping list doesn't exist. Use Groceries or Farmers Market."
        case .remindersAccessDenied:
            "Larder can't reach Reminders, where shopping lists are kept. Ask the person to open Larder and allow access to Reminders, or turn it on in Settings."
        case .emptyIngredients:
            "A recipe needs at least one ingredient. Ask the person what goes in it."
        case .invalidCookTime:
            "The cook time has to be at least one minute. Ask the person how long it takes."
        case .invalidDayCount:
            "The number of days has to be between 1 and 31."
        }
    }
}
