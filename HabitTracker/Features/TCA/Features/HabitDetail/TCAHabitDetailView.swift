import SwiftUI

/// TCA Architecture — habit detail view.
///
/// Reads its repository dependency from the SwiftUI environment —
/// demonstrating how TCA's dependency injection flows through the hierarchy.
/// A local Store<HabitDetailFeature> is created on demand, scoped to this screen.
struct TCAHabitDetailView: View {
    let habit: Habit
    @Environment(\.habitRepository) private var repository
    @State private var detailStore: Store<HabitDetailFeature>?

    init(habit: Habit) {
        self.habit = habit
    }

    private var state: HabitDetailFeature.State? {
        detailStore?.state
    }

    var body: some View {
        List {
            habitSection
            statisticsSection
            completionSection
        }
        .navigationTitle(habit.name)
#if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .onAppear(perform: createStoreIfNeeded)
        .task {
            detailStore?.send(.onAppear)
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { state?.errorMessage != nil },
                set: { _ in }
            )
        ) {
        } message: {
            Text(state?.errorMessage ?? "")
        }
    }

    private var habitSection: some View {
        Section("Details") {
            LabeledContent("Frequency", value: habit.frequency.displayName)
            if !habit.habitDescription.isEmpty {
                Text(habit.habitDescription).foregroundStyle(.secondary)
            }
        }
    }

    private var statisticsSection: some View {
        Section("Statistics") {
            if let stats = state?.statistics {
                TCAStatisticsGridView(statistics: stats)
            } else if state?.isLoading == true {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
    }

    private var completionSection: some View {
        Section {
            Button(
                state?.statistics?.isCompletedToday == true ? "Completed Today ✓" : "Mark as Complete"
            ) {
                detailStore?.send(.completeButtonTapped)
            }
            .disabled(state?.statistics?.isCompletedToday == true)
            .frame(maxWidth: .infinity)
            .tint(state?.statistics?.isCompletedToday == true ? .green : .accentColor)
        }
    }

    private func createStoreIfNeeded() {
        guard detailStore == nil else { return }
        detailStore = Store(
            initialState: HabitDetailFeature.State(habit: habit),
            reducer: HabitDetailFeature(dependencies: HabitDetailDependencies(repository: repository))
        )
    }
}
