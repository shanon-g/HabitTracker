import Foundation
import Observation

/// # MVVM Architecture — AddHabitViewModel
///
/// Owns the form state and validation logic for the Add Habit screen.
/// The ViewModel validates input before delegating to the use case.
///
/// This ViewModel demonstrates how validation logic lives in the ViewModel
/// rather than in the view or the domain use case.
@Observable
final class AddHabitViewModel {

    // MARK: - Form State

    var name = ""
    var habitDescription = ""
    var isWeekly = false
    var selectedDays: Set<Weekday> = []

    // MARK: - Derived State

    var frequency: HabitFrequency {
        isWeekly ? .weekly(days: selectedDays) : .daily
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private(set) var isSaving = false
    private(set) var errorMessage: String?
    private(set) var didSave = false

    // MARK: - Use Case

    private let createHabitUseCase: CreateHabitUseCase

    // MARK: - Init

    init(repository: any HabitRepository) {
        self.createHabitUseCase = CreateHabitUseCase(repository: repository)
    }

    // MARK: - Intent

    func saveHabit() async {
        guard isValid else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await createHabitUseCase.execute(
                name: name,
                description: habitDescription,
                frequency: frequency
            )
            didSave = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleDay(_ day: Weekday) {
        if selectedDays.contains(day) {
            selectedDays.remove(day)
        } else {
            selectedDays.insert(day)
        }
    }

    func clearError() {
        errorMessage = nil
    }
}
