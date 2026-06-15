import Foundation
import Observation

/// # MVVM Architecture — StatisticsViewModel
///
/// Aggregates statistics for all habits into a single summary screen.
/// Demonstrates how a ViewModel coordinates multiple use cases
/// and shapes data specifically for the view's presentation needs.
@Observable
final class StatisticsViewModel {

    // MARK: - State

    private(set) var habitStatistics: [HabitStatistics] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    // Computed presentation properties — shaped for the view, not raw domain data.
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

    // MARK: - Use Cases

    private let generateStatisticsUseCase: GenerateStatisticsUseCase
    private let repository: any HabitRepository

    // MARK: - Init

    init(repository: any HabitRepository) {
        self.repository = repository
        self.generateStatisticsUseCase = GenerateStatisticsUseCase(repository: repository)
    }

    // MARK: - Intent

    func loadStatistics() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let habits = try await repository.fetchHabits()
            habitStatistics = try await withThrowingTaskGroup(of: HabitStatistics.self) { group in
                for habit in habits {
                    group.addTask { [self] in
                        try await generateStatisticsUseCase.execute(habit: habit)
                    }
                }
                var results: [HabitStatistics] = []
                for try await stats in group {
                    results.append(stats)
                }
                return results.sorted { $0.habit.name < $1.habit.name }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearError() {
        errorMessage = nil
    }
}
