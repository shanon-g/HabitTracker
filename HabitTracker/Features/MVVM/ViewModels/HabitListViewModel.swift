import Foundation
import Observation

/// # MVVM Architecture — HabitListViewModel
///
/// ## Responsibilities:
/// - Own presentation state for the habit list screen
/// - Coordinate calls to Use Cases
/// - Translate domain errors into user-facing strings
///
/// ## What the ViewModel does NOT own:
/// - Business logic (in Use Cases)
/// - Persistence (in Repository)
/// - Navigation destinations (driven by the view via state)
///
/// Unlike the MV Store, this ViewModel is screen-scoped.
/// Each screen has its own ViewModel with focused state.
@Observable
final class HabitListViewModel {

    // MARK: - State

    private(set) var habits: [Habit] = []
    private(set) var statistics: [UUID: HabitStatistics] = [:]
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    // MARK: - Use Cases

    private let repository: any HabitRepository
    private let createHabitUseCase: CreateHabitUseCase
    private let completeHabitUseCase: CompleteHabitUseCase
    private let deleteHabitUseCase: DeleteHabitUseCase
    private let generateStatisticsUseCase: GenerateStatisticsUseCase

    // MARK: - Init

    init(repository: any HabitRepository) {
        self.repository = repository
        self.createHabitUseCase = CreateHabitUseCase(repository: repository)
        self.completeHabitUseCase = CompleteHabitUseCase(repository: repository)
        self.deleteHabitUseCase = DeleteHabitUseCase(repository: repository)
        self.generateStatisticsUseCase = GenerateStatisticsUseCase(repository: repository)
    }

    // MARK: - Intent Methods

    func loadHabits() async {
        isLoading = true
        defer { isLoading = false }
        do {
            habits = try await repository.fetchHabits()
            await refreshStatistics()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createHabit(name: String, description: String, frequency: HabitFrequency) async {
        do {
            let habit = try await createHabitUseCase.execute(
                name: name,
                description: description,
                frequency: frequency
            )
            habits.append(habit)
            if let stats = try? await generateStatisticsUseCase.execute(habit: habit) {
                statistics[habit.id] = stats
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func completeHabit(_ habit: Habit) async {
        do {
            _ = try await completeHabitUseCase.execute(habit: habit)
            if let stats = try? await generateStatisticsUseCase.execute(habit: habit) {
                statistics[habit.id] = stats
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteHabits(at offsets: IndexSet) async {
        let targets = offsets.map { habits[$0] }
        for habit in targets {
            do {
                try await deleteHabitUseCase.execute(habitId: habit.id)
                habits.removeAll { $0.id == habit.id }
                statistics.removeValue(forKey: habit.id)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func clearError() {
        errorMessage = nil
    }

    // MARK: - Private

    private func refreshStatistics() async {
        await withDiscardingTaskGroup { group in
            for habit in habits {
                group.addTask { [weak self] in
                    guard let self else { return }
                    if let stats = try? await generateStatisticsUseCase.execute(habit: habit) {
                        statistics[habit.id] = stats
                    }
                }
            }
        }
    }
}
