import Foundation
import SwiftUI

// MARK: - HabitList Feature
//
// TCA Architecture: each feature is a self-contained Reducer
// with explicit State, Action, and side-effect management.
//
// Compare this to MVVM where state and logic live in a ViewModel class:
// - TCA: state is a value type (struct), mutations are atomic, testable
// - TCA: all possible events are encoded as enum cases (exhaustive by compiler)
// - TCA: effects are declared, not hidden in async methods

// MARK: - Dependencies

/// Dependencies for HabitListFeature — explicit, injected, swappable.
/// TCA's dependency model makes the dependency graph fully visible at the feature level.
struct HabitListDependencies: Sendable {
    var repository: any HabitRepository
    var generateStatistics: GenerateStatisticsUseCase

    init(repository: any HabitRepository) {
        self.repository = repository
        self.generateStatistics = GenerateStatisticsUseCase(repository: repository)
    }
}

// MARK: - Reducer

struct HabitListFeature: Reducer {

    // MARK: State
    //
    // State is a value type. Every mutation produces a new value.
    // This makes state transitions predictable and easy to test.

    struct State: Equatable, Sendable {
        var habits: [Habit] = []
        var statistics: [UUID: HabitStatistics] = [:]
        var isLoading = false
        var errorMessage: String?
        var isShowingAddHabit = false

        // Child feature state — AddHabit sheet state is owned here.
        var addHabitState: AddHabitFeature.State? = nil
    }

    // MARK: Action
    //
    // All possible events — user actions, lifecycle events, and async results —
    // are encoded as enum cases. The compiler enforces exhaustiveness.
    // This creates a complete audit trail of everything that can happen in a feature.

    enum Action: Sendable {
        // Lifecycle
        case onAppear

        // User interactions
        case addHabitButtonTapped
        case completeHabitButtonTapped(Habit)
        case deleteHabits(IndexSet)
        case addHabitDismissed

        // Async results (internal — dispatched by effects)
        case habitsLoaded([Habit])
        case statisticsLoaded(UUID, HabitStatistics)
        case habitCompleted(HabitCompletion)
        case habitsDeleted(IndexSet)
        case failedWithError(String)

        // Child actions — routed to the AddHabit child reducer
        case addHabit(AddHabitFeature.Action)
    }

    // MARK: Dependencies

    let dependencies: HabitListDependencies

    // MARK: Reducer

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {

        case .onAppear:
            state.isLoading = true
            return .run { send in
                do {
                    let habits = try await dependencies.repository.fetchHabits()
                    await send(.habitsLoaded(habits))
                } catch {
                    await send(.failedWithError(error.localizedDescription))
                }
            }

        case .habitsLoaded(let habits):
            state.isLoading = false
            state.habits = habits
            // Fan out to load statistics for each habit concurrently.
            return .run { [deps = dependencies] send in
                await withDiscardingTaskGroup { group in
                    for habit in habits {
                        group.addTask {
                            if let stats = try? await deps.generateStatistics.execute(habit: habit) {
                                await send(.statisticsLoaded(habit.id, stats))
                            }
                        }
                    }
                }
            }

        case .statisticsLoaded(let habitId, let stats):
            state.statistics[habitId] = stats
            return .none

        case .addHabitButtonTapped:
            state.isShowingAddHabit = true
            state.addHabitState = AddHabitFeature.State()
            return .none

        case .addHabitDismissed:
            state.isShowingAddHabit = false
            state.addHabitState = nil
            return .none

        case .addHabit(let childAction):
            // Route child actions to the AddHabit reducer.
            guard var childState = state.addHabitState else { return .none }
            let childReducer = AddHabitFeature(dependencies: AddHabitDependencies(repository: dependencies.repository))
            let childEffect = childReducer.reduce(into: &childState, action: childAction)
            state.addHabitState = childState

            // If the child completed successfully, reload the list.
            if case .saveSucceeded(let habit) = childAction {
                state.habits.append(habit)
                state.isShowingAddHabit = false
                state.addHabitState = nil
            }

            return childEffect.map(Action.addHabit)

        case .completeHabitButtonTapped(let habit):
            return .run { [deps = dependencies] send in
                do {
                    let completion = try await CompleteHabitUseCase(repository: deps.repository)
                        .execute(habit: habit)
                    await send(.habitCompleted(completion))
                    if let stats = try? await deps.generateStatistics.execute(habit: habit) {
                        await send(.statisticsLoaded(habit.id, stats))
                    }
                } catch {
                    await send(.failedWithError(error.localizedDescription))
                }
            }

        case .habitCompleted:
            return .none

        case .deleteHabits(let offsets):
            let targets = offsets.map { state.habits[$0] }
            return .run { [deps = dependencies] send in
                for habit in targets {
                    do {
                        try await DeleteHabitUseCase(repository: deps.repository).execute(habitId: habit.id)
                    } catch {
                        await send(.failedWithError(error.localizedDescription))
                        return
                    }
                }
                await send(.habitsDeleted(offsets))
            }

        case .habitsDeleted(let offsets):
            let removed = offsets.map { state.habits[$0] }
            state.habits.remove(atOffsets: offsets)
            for habit in removed {
                state.statistics.removeValue(forKey: habit.id)
            }
            return .none

        case .failedWithError(let message):
            state.isLoading = false
            state.errorMessage = message
            return .none
        }
    }
}

// MARK: - Effect Map Helper

extension Effect {
    func map<NewAction: Sendable>(_ transform: @escaping @Sendable (Action) -> NewAction) -> Effect<NewAction> {
        Effect<NewAction> { dispatch in
            await self.operation { @MainActor action in
                dispatch(transform(action))
            }
        }
    }
}
