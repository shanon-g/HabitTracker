import Foundation
import Testing
@testable import HabitTracker

// MARK: - MVVM Architecture: HabitListViewModel Tests
//
// Testing strategy for MVVM:
// - Each ViewModel is independently instantiable.
// - Inject InMemoryHabitRepository to remove persistence as a variable.
// - Test that ViewModels correctly translate domain data to presentation state.
// - ViewModels do NOT need protocol wrappers — @Observable instances are directly testable.

@MainActor
struct HabitListViewModelTests {
    let repository: InMemoryHabitRepository
    let sut: HabitListViewModel

    init() {
        repository = InMemoryHabitRepository()
        sut = HabitListViewModel(repository: repository)
    }

    @Test func initialStateIsEmpty() {
        #expect(sut.habits.isEmpty)
        #expect(sut.isLoading == false)
        #expect(sut.errorMessage == nil)
    }

    @Test func loadHabitsPopulatesHabits() async throws {
        try await repository.saveHabit(TestFixtures.exercise)
        await sut.loadHabits()
        #expect(sut.habits.count == 1)
    }

    @Test func createHabitAppendsToHabits() async {
        await sut.createHabit(name: "Swim", description: "", frequency: .daily)
        #expect(sut.habits.count == 1)
        #expect(sut.habits.first?.name == "Swim")
    }

    @Test func createHabitWithEmptyNameSetsErrorMessage() async {
        await sut.createHabit(name: "", description: "", frequency: .daily)
        #expect(sut.errorMessage != nil)
        #expect(sut.habits.isEmpty)
    }

    @Test func clearErrorResetsErrorMessage() async {
        await sut.createHabit(name: "", description: "", frequency: .daily)
        sut.clearError()
        #expect(sut.errorMessage == nil)
    }

    @Test func deleteHabitsRemovesFromList() async {
        await sut.createHabit(name: "Run", description: "", frequency: .daily)
        #expect(sut.habits.count == 1)
        await sut.deleteHabits(at: IndexSet(integer: 0))
        #expect(sut.habits.isEmpty)
    }

    @Test func completeHabitUpdatesStatistics() async {
        await sut.createHabit(name: "Meditate", description: "", frequency: .daily)
        let habit = sut.habits.first!
        await sut.completeHabit(habit)
        #expect(sut.statistics[habit.id]?.isCompletedToday == true)
    }

    @Test func loadHabitsSetsLoadingToFalseAfterCompletion() async {
        await sut.loadHabits()
        #expect(sut.isLoading == false)
    }
}

// MARK: - MVVM Architecture: StatisticsViewModel Tests

@MainActor
struct StatisticsViewModelTests {
    let repository: InMemoryHabitRepository
    let sut: StatisticsViewModel

    init() {
        repository = InMemoryHabitRepository()
        sut = StatisticsViewModel(repository: repository)
    }

    @Test func initialStateHasNoStatistics() {
        #expect(sut.habitStatistics.isEmpty)
        #expect(sut.averageCompletionRate == 0.0)
        #expect(sut.topStreakHabit == nil)
    }

    @Test func loadStatisticsPopulatesData() async throws {
        try await repository.saveHabit(TestFixtures.exercise)
        await sut.loadStatistics()
        #expect(sut.habitStatistics.count == 1)
    }

    @Test func averageCompletionRateIsZeroWithNoCompletions() async throws {
        try await repository.saveHabit(TestFixtures.exercise)
        await sut.loadStatistics()
        #expect(sut.averageCompletionRate == 0.0)
    }

    @Test func totalCompletionsTodayCountsCompletedHabits() async throws {
        let habit = TestFixtures.exercise
        try await repository.saveHabit(habit)
        try await repository.saveCompletion(HabitCompletion(habitId: habit.id, completedAt: Date()))
        await sut.loadStatistics()
        #expect(sut.totalCompletionsToday == 1)
    }

    @Test func habitStatisticsAreSortedByName() async throws {
        try await repository.saveHabit(TestFixtures.meditation)
        try await repository.saveHabit(TestFixtures.exercise)
        await sut.loadStatistics()
        let names = sut.habitStatistics.map { $0.habit.name }
        #expect(names == names.sorted())
    }
}

// MARK: - MVVM Architecture: AddHabitViewModel Tests

@MainActor
struct AddHabitViewModelTests {
    let repository: InMemoryHabitRepository
    let sut: AddHabitViewModel

    init() {
        repository = InMemoryHabitRepository()
        sut = AddHabitViewModel(repository: repository)
    }

    @Test func isValidFalseForEmptyName() {
        sut.name = ""
        #expect(sut.isValid == false)
    }

    @Test func isValidTrueForNonEmptyName() {
        sut.name = "Yoga"
        #expect(sut.isValid == true)
    }

    @Test func frequencyIsDailyByDefault() {
        #expect(sut.frequency == .daily)
    }

    @Test func frequencyIsWeeklyWhenToggled() {
        sut.isWeekly = true
        sut.selectedDays = [.monday, .wednesday]
        #expect(sut.frequency == .weekly(days: [.monday, .wednesday]))
    }

    @Test func toggleDayAddsDay() {
        sut.toggleDay(.monday)
        #expect(sut.selectedDays.contains(.monday))
    }

    @Test func toggleDayRemovesDayIfAlreadySelected() {
        sut.toggleDay(.monday)
        sut.toggleDay(.monday)
        #expect(sut.selectedDays.contains(.monday) == false)
    }

    @Test func saveHabitSetsSavedFlag() async {
        sut.name = "Journal"
        await sut.saveHabit()
        #expect(sut.didSave == true)
    }

    @Test func saveHabitDoesNothingIfInvalid() async {
        sut.name = ""
        await sut.saveHabit()
        #expect(sut.didSave == false)
    }
}
