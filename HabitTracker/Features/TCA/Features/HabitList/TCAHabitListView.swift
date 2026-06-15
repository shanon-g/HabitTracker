import SwiftUI

/// TCA Architecture — habit list view.
///
/// Receives the root App store and reads from `store.state.habitList`.
/// All mutations go through `store.send(.habitList(.someAction))`.
///
/// Compare to MV (reads from environment) and MVVM (receives its own ViewModel):
/// TCA views receive the store and address state via key paths.
struct TCAHabitListView: View {
    let store: Store<AppFeature>

    private var state: HabitListFeature.State {
        store.state.habitList
    }

    var body: some View {
        NavigationStack {
            Group {
                if state.habits.isEmpty && !state.isLoading {
                    TCAEmptyStateView()
                } else {
                    habitList
                }
            }
            .navigationTitle("Habits (TCA)")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Habit", systemImage: "plus") {
                        store.send(.habitList(.addHabitButtonTapped))
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { state.isShowingAddHabit },
                set: { if !$0 { store.send(.habitList(.addHabitDismissed)) } }
            )) {
                if state.addHabitState != nil {
                    TCAAddHabitView(store: store)
                }
            }
            .overlay {
                if state.isLoading {
                    ProgressView()
                }
            }
            .alert(
                "Error",
                isPresented: Binding(
                    get: { state.errorMessage != nil },
                    set: { _ in }
                )
            ) {
            } message: {
                Text(state.errorMessage ?? "")
            }
        }
        .task {
            store.send(.habitList(.onAppear))
        }
    }

    private var habitList: some View {
        List {
            ForEach(state.habits) { habit in
                NavigationLink {
                    TCAHabitDetailView(habit: habit)
                } label: {
                    TCAHabitRowView(
                        habit: habit,
                        statistics: state.statistics[habit.id],
                        onComplete: { store.send(.habitList(.completeHabitButtonTapped(habit))) }
                    )
                }
            }
            .onDelete { store.send(.habitList(.deleteHabits($0))) }
        }
    }
}
