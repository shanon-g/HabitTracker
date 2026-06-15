import Foundation
import Observation

/// # MVVM Architecture — HabitDetailViewModel
///
/// Owns the presentation state for a single habit's detail screen.
/// Focuses only on what this screen needs — no global state leaks in.
///
/// This per-screen scoping is a key MVVM advantage:
/// a feature's complexity is contained to its ViewModel.
@Observable
final class HabitDetailViewModel {

    // MARK: - State

    private(set) var statistics: HabitStatistics?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    let habit: Habit

    // MARK: - Use Cases

    private let completeHabitUseCase: CompleteHabitUseCase
    private let generateStatisticsUseCase: GenerateStatisticsUseCase

    // MARK: - Init

    init(habit: Habit, repository: any HabitRepository) {
        self.habit = habit
        self.completeHabitUseCase = CompleteHabitUseCase(repository: repository)
        self.generateStatisticsUseCase = GenerateStatisticsUseCase(repository: repository)
    }

    // MARK: - Intent

    func loadStatistics() async {
        isLoading = true
        defer { isLoading = false }
        do {
            statistics = try await generateStatisticsUseCase.execute(habit: habit)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func completeHabit() async {
        do {
            _ = try await completeHabitUseCase.execute(habit: habit)
            statistics = try await generateStatisticsUseCase.execute(habit: habit)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearError() {
        errorMessage = nil
    }
}
