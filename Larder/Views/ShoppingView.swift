import EventKit
import SwiftUI

struct ShoppingView: View {
    @Environment(LarderStore.self) private var store
    @Environment(\.openURL) private var openURL
    @State private var items: [String: [ShoppingItem]] = [:]
    @State private var isAccessDenied = false

    var body: some View {
        NavigationStack {
            Group {
                if isAccessDenied {
                    ContentUnavailableView {
                        Label("No Access to Reminders", systemImage: "checklist")
                    } description: {
                        Text("Larder keeps your shopping lists in Reminders. Allow access in Settings to see them here.")
                    } actions: {
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                        }
                    }
                } else {
                    lists
                }
            }
            .navigationTitle("Shopping")
        }
        // Reloads whenever this process changes a list, such as when Siri runs an intent while Larder is open.
        .task(id: store.shoppingRevision) {
            await reload()
            // Reminders posts this for changes made here, in the Reminders app, by Siri, or on another device.
            for await _ in NotificationCenter.default.notifications(named: .EKEventStoreChanged).map(\.name) {
                await reload()
            }
        }
    }

    private var lists: some View {
        List(store.allShoppingLists()) { list in
            let listItems = items[list.id] ?? []
            Section {
                if listItems.isEmpty {
                    Text("No items").foregroundStyle(.secondary)
                }
                ForEach(listItems) { item in
                    Toggle(item.name, isOn: checked(item, in: list))
                        .toggleStyle(CheckToggleStyle())
                        .alignmentGuide(.listRowSeparatorLeading) { dimensions in dimensions[.leading] + 38 }
                }
            } header: {
                HStack(alignment: .firstTextBaseline) {
                    Text(list.name)
                        .font(.title2.bold())
                        .foregroundStyle(.tint)
                    Spacer()
                    Text(remaining(in: listItems))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .textCase(nil)
            }
        }
        .listStyle(.plain)
        .refreshable { await reload() }
    }

    /// Updates the row right away, then saves the change to Reminders.
    private func checked(_ item: ShoppingItem, in list: ShoppingList) -> Binding<Bool> {
        Binding {
            item.isChecked
        } set: { isChecked in
            if let index = items[list.id]?.firstIndex(where: { $0.id == item.id }) {
                items[list.id]?[index].isChecked = isChecked
            }
            try? store.setChecked(isChecked, itemID: item.id)
        }
    }

    private func reload() async {
        do {
            var loaded: [String: [ShoppingItem]] = [:]
            for list in store.allShoppingLists() {
                loaded[list.id] = try await store.items(inList: list.id)
            }
            items = loaded
            isAccessDenied = false
        } catch {
            isAccessDenied = !store.hasRemindersAccess
        }
    }

    private func remaining(in items: [ShoppingItem]) -> String {
        guard !items.isEmpty else { return "" }
        let left = items.filter { !$0.isChecked }.count
        return left == 0 ? "All done" : "\(left) left"
    }
}

/// A round checkbox, like the one in Reminders.
private struct CheckToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(configuration.isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                    .contentTransition(.symbolEffect(.replace))
                configuration.label
                    .foregroundStyle(configuration.isOn ? .secondary : .primary)
                    .strikethrough(configuration.isOn)
                Spacer(minLength: 0)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: configuration.isOn)
        .accessibilityAddTraits(configuration.isOn ? .isSelected : [])
    }
}
