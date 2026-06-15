import SwiftUI

/// TCA Architecture — root app view.
/// Holds the single root Store for the entire TCA feature tree.
/// Sets the repository in the SwiftUI environment so child views can access it.
struct TCAAppView: View {
    @State private var store: Store<AppFeature>
    private let repository: any HabitRepository

    init(repository: any HabitRepository) {
        self.repository = repository
        _store = State(initialValue: Store(
            initialState: AppFeature.State(),
            reducer: AppFeature(dependencies: AppDependencies(repository: repository))
        ))
    }

    var body: some View {
        TabView(selection: Binding(
            get: { store.state.selectedTab },
            set: { store.send(.tabSelected($0)) }
        )) {
            Tab("Habits", systemImage: "checkmark.circle", value: AppTab.habits) {
                TCAHabitListView(store: store)
            }
            Tab("Statistics", systemImage: "chart.bar", value: AppTab.statistics) {
                TCAStatisticsView(store: store)
            }
        }
        .environment(\.habitRepository, repository)
    }
}
