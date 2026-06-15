import Foundation

// MARK: - AddHabit Feature
//
// TCA: this child feature is entirely independent.
// It knows nothing about HabitListFeature — that parent
// routes child actions and decides when to show/dismiss the sheet.

struct AddHabitDependencies: Sendable {
    var repository: any HabitRepository
}

struct AddHabitFeature: Reducer {

    // MARK: State

    struct State: Equatable, Sendable {
        var name = ""
        var habitDescription = ""
        var isWeekly = false
        var selectedDays: Set<Weekday> = []
        var isSaving = false
        var errorMessage: String?

        var frequency: HabitFrequency {
            isWeekly ? .weekly(days: selectedDays) : .daily
        }

        var isValid: Bool {
            !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    // MARK: Action

    enum Action: Sendable {
        case nameChanged(String)
        case descriptionChanged(String)
        case isWeeklyToggled(Bool)
        case dayToggled(Weekday)
        case saveButtonTapped
        case cancelButtonTapped

        // Internal — dispatched by effects
        case saveSucceeded(Habit)
        case saveFailed(String)
    }

    // MARK: Dependencies

    let dependencies: AddHabitDependencies

    // MARK: Reducer

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {

        case .nameChanged(let name):
            state.name = name
            return .none

        case .descriptionChanged(let desc):
            state.habitDescription = desc
            return .none

        case .isWeeklyToggled(let value):
            state.isWeekly = value
            return .none

        case .dayToggled(let day):
            if state.selectedDays.contains(day) {
                state.selectedDays.remove(day)
            } else {
                state.selectedDays.insert(day)
            }
            return .none

        case .saveButtonTapped:
            guard state.isValid else { return .none }
            state.isSaving = true
            let name = state.name
            let desc = state.habitDescription
            let freq = state.frequency
            return .run { [deps = dependencies] send in
                do {
                    let habit = try await CreateHabitUseCase(repository: deps.repository)
                        .execute(name: name, description: desc, frequency: freq)
                    await send(.saveSucceeded(habit))
                } catch {
                    await send(.saveFailed(error.localizedDescription))
                }
            }

        case .saveSucceeded:
            state.isSaving = false
            return .none

        case .saveFailed(let message):
            state.isSaving = false
            state.errorMessage = message
            return .none

        case .cancelButtonTapped:
            return .none
        }
    }
}
