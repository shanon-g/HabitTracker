import Foundation

// MARK: - HabitDetail Feature

struct HabitDetailDependencies: Sendable {
    var repository: any HabitRepository
    var generateStatistics: GenerateStatisticsUseCase

    init(repository: any HabitRepository) {
        self.repository = repository
        self.generateStatistics = GenerateStatisticsUseCase(repository: repository)
    }
}

struct HabitDetailFeature: Reducer {

    // MARK: State

    struct State: Equatable, Sendable {
        let habit: Habit
        var statistics: HabitStatistics?
        var isLoading = false
        var errorMessage: String?
    }

    // MARK: Action

    enum Action: Sendable {
        case onAppear
        case completeButtonTapped
        case statisticsLoaded(HabitStatistics)
        case completionRecorded(HabitCompletion)
        case failedWithError(String)
    }

    // MARK: Dependencies

    let dependencies: HabitDetailDependencies

    // MARK: Reducer

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {

        case .onAppear:
            state.isLoading = true
            let habit = state.habit
            return .run { [deps = dependencies] send in
                do {
                    let stats = try await deps.generateStatistics.execute(habit: habit)
                    await send(.statisticsLoaded(stats))
                } catch {
                    await send(.failedWithError(error.localizedDescription))
                }
            }

        case .statisticsLoaded(let stats):
            state.isLoading = false
            state.statistics = stats
            return .none

        case .completeButtonTapped:
            let habit = state.habit
            return .run { [deps = dependencies] send in
                do {
                    let completion = try await CompleteHabitUseCase(repository: deps.repository)
                        .execute(habit: habit)
                    await send(.completionRecorded(completion))
                    let stats = try await deps.generateStatistics.execute(habit: habit)
                    await send(.statisticsLoaded(stats))
                } catch {
                    await send(.failedWithError(error.localizedDescription))
                }
            }

        case .completionRecorded:
            return .none

        case .failedWithError(let message):
            state.isLoading = false
            state.errorMessage = message
            return .none
        }
    }
}
