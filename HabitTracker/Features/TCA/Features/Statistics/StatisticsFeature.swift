import Foundation

// MARK: - Statistics Feature

struct StatisticsDependencies: Sendable {
    var repository: any HabitRepository
    var generateStatistics: GenerateStatisticsUseCase

    init(repository: any HabitRepository) {
        self.repository = repository
        self.generateStatistics = GenerateStatisticsUseCase(repository: repository)
    }
}

struct StatisticsFeature: Reducer {

    // MARK: State

    struct State: Equatable, Sendable {
        var habitStatistics: [HabitStatistics] = []
        var isLoading = false
        var errorMessage: String?

        // Computed for the view — derived from value-type state, always consistent.
        var topStreakHabit: HabitStatistics? {
            habitStatistics.max { $0.currentStreak < $1.currentStreak }
        }

        var averageCompletionRate: Double {
            guard !habitStatistics.isEmpty else { return 0 }
            return habitStatistics.reduce(0) { $0 + $1.completionRate } / Double(habitStatistics.count)
        }

        var totalCompletionsToday: Int {
            habitStatistics.filter { $0.isCompletedToday }.count
        }
    }

    // MARK: Action

    enum Action: Sendable {
        case onAppear
        case statisticsLoaded([HabitStatistics])
        case failedWithError(String)
    }

    // MARK: Dependencies

    let dependencies: StatisticsDependencies

    // MARK: Reducer

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {

        case .onAppear:
            state.isLoading = true
            return .run { [deps = dependencies] send in
                do {
                    let habits = try await deps.repository.fetchHabits()
                    let allStats = try await withThrowingTaskGroup(of: HabitStatistics.self) { group in
                        for habit in habits {
                            group.addTask {
                                try await deps.generateStatistics.execute(habit: habit)
                            }
                        }
                        var results: [HabitStatistics] = []
                        for try await stats in group {
                            results.append(stats)
                        }
                        return results.sorted { $0.habit.name < $1.habit.name }
                    }
                    await send(.statisticsLoaded(allStats))
                } catch {
                    await send(.failedWithError(error.localizedDescription))
                }
            }

        case .statisticsLoaded(let stats):
            state.isLoading = false
            state.habitStatistics = stats
            return .none

        case .failedWithError(let message):
            state.isLoading = false
            state.errorMessage = message
            return .none
        }
    }
}
