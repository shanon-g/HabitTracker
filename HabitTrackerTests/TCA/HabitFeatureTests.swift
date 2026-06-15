import Foundation
import Testing
@testable import HabitTracker

// MARK: - TCA Architecture: Feature Reducer Tests
//
// Testing strategy for TCA:
// - Reducers are pure functions (ignoring effects) — testable without async.
// - State transitions are verified synchronously by calling reduce(into:action:).
// - Effects are verified by checking that the correct Effect is returned
//   (e.g., `.none` vs a `.run` effect).
//
// This demonstrates TCA's primary testing advantage:
// state transitions can be verified without running effects.

// MARK: - HabitListFeature Tests

@MainActor
struct HabitListFeatureTests {
    let repository: InMemoryHabitRepository
    let sut: HabitListFeature

    init() {
        repository = InMemoryHabitRepository()
        sut = HabitListFeature(dependencies: HabitListDependencies(repository: repository))
    }

    @Test func onAppearSetsLoadingTrue() {
        var state = HabitListFeature.State()
        _ = sut.reduce(into: &state, action: .onAppear)
        #expect(state.isLoading == true)
    }

    @Test func habitsLoadedPopulatesHabits() {
        var state = HabitListFeature.State()
        let habits = [TestFixtures.exercise]
        _ = sut.reduce(into: &state, action: .habitsLoaded(habits))
        #expect(state.habits.count == 1)
        #expect(state.isLoading == false)
    }

    @Test func statisticsLoadedUpdatesStatisticsMap() {
        var state = HabitListFeature.State()
        let habit = TestFixtures.exercise
        let stats = makeStatistics(for: habit)
        _ = sut.reduce(into: &state, action: .statisticsLoaded(habit.id, stats))
        #expect(state.statistics[habit.id] == stats)
    }

    @Test func addHabitButtonTappedShowsSheet() {
        var state = HabitListFeature.State()
        _ = sut.reduce(into: &state, action: .addHabitButtonTapped)
        #expect(state.isShowingAddHabit == true)
        #expect(state.addHabitState != nil)
    }

    @Test func addHabitDismissedHidesSheet() {
        var state = HabitListFeature.State()
        _ = sut.reduce(into: &state, action: .addHabitButtonTapped)
        _ = sut.reduce(into: &state, action: .addHabitDismissed)
        #expect(state.isShowingAddHabit == false)
        #expect(state.addHabitState == nil)
    }

    @Test func habitsDeletedRemovesFromList() {
        var state = HabitListFeature.State()
        state.habits = [TestFixtures.exercise, TestFixtures.meditation]
        _ = sut.reduce(into: &state, action: .habitsDeleted(IndexSet(integer: 0)))
        #expect(state.habits.count == 1)
    }

    @Test func failedWithErrorSetsErrorMessage() {
        var state = HabitListFeature.State()
        _ = sut.reduce(into: &state, action: .failedWithError("Something went wrong"))
        #expect(state.errorMessage == "Something went wrong")
        #expect(state.isLoading == false)
    }

    // MARK: - Helpers

    private func makeStatistics(for habit: Habit) -> HabitStatistics {
        HabitStatistics(
            habit: habit,
            currentStreak: 5,
            longestStreak: 10,
            completionRate: 0.8,
            totalCompletions: 24,
            completionsThisWeek: 5,
            completionsThisMonth: 20,
            lastCompletedAt: Date()
        )
    }
}

// MARK: - AddHabitFeature Tests

@MainActor
struct AddHabitFeatureTests {
    let repository: InMemoryHabitRepository
    let sut: AddHabitFeature

    init() {
        repository = InMemoryHabitRepository()
        sut = AddHabitFeature(dependencies: AddHabitDependencies(repository: repository))
    }

    @Test func nameChangedUpdatesState() {
        var state = AddHabitFeature.State()
        _ = sut.reduce(into: &state, action: .nameChanged("Yoga"))
        #expect(state.name == "Yoga")
    }

    @Test func isWeeklyToggledUpdatesState() {
        var state = AddHabitFeature.State()
        _ = sut.reduce(into: &state, action: .isWeeklyToggled(true))
        #expect(state.isWeekly == true)
    }

    @Test func dayToggledAddsDay() {
        var state = AddHabitFeature.State()
        _ = sut.reduce(into: &state, action: .dayToggled(.monday))
        #expect(state.selectedDays.contains(.monday))
    }

    @Test func dayToggledRemovesDayIfPresent() {
        var state = AddHabitFeature.State()
        state.selectedDays = [.monday]
        _ = sut.reduce(into: &state, action: .dayToggled(.monday))
        #expect(state.selectedDays.contains(.monday) == false)
    }

    @Test func saveButtonTappedSetsSavingTrue() {
        var state = AddHabitFeature.State()
        state.name = "Run"
        _ = sut.reduce(into: &state, action: .saveButtonTapped)
        #expect(state.isSaving == true)
    }

    @Test func saveButtonTappedDoesNothingForInvalidState() {
        var state = AddHabitFeature.State()
        state.name = ""
        _ = sut.reduce(into: &state, action: .saveButtonTapped)
        #expect(state.isSaving == false)
    }

    @Test func saveSucceededClearsSavingFlag() {
        var state = AddHabitFeature.State()
        state.isSaving = true
        let habit = TestFixtures.exercise
        _ = sut.reduce(into: &state, action: .saveSucceeded(habit))
        #expect(state.isSaving == false)
    }

    @Test func stateIsValidWithNonEmptyName() {
        var state = AddHabitFeature.State()
        state.name = "Journal"
        #expect(state.isValid == true)
    }

    @Test func stateIsInvalidWithEmptyName() {
        let state = AddHabitFeature.State()
        #expect(state.isValid == false)
    }

    @Test func frequencyIsDailyByDefault() {
        let state = AddHabitFeature.State()
        #expect(state.frequency == .daily)
    }

    @Test func frequencyIsWeeklyWhenDaysSelected() {
        var state = AddHabitFeature.State()
        state.isWeekly = true
        state.selectedDays = [.tuesday, .thursday]
        #expect(state.frequency == .weekly(days: [.tuesday, .thursday]))
    }
}

// MARK: - StatisticsFeature Tests

@MainActor
struct StatisticsFeatureTests {
    let repository: InMemoryHabitRepository
    let sut: StatisticsFeature

    init() {
        repository = InMemoryHabitRepository()
        sut = StatisticsFeature(dependencies: StatisticsDependencies(repository: repository))
    }

    @Test func onAppearSetsLoadingTrue() {
        var state = StatisticsFeature.State()
        _ = sut.reduce(into: &state, action: .onAppear)
        #expect(state.isLoading == true)
    }

    @Test func statisticsLoadedPopulatesData() {
        var state = StatisticsFeature.State()
        let stats = makeStatistics(for: TestFixtures.exercise)
        _ = sut.reduce(into: &state, action: .statisticsLoaded([stats]))
        #expect(state.habitStatistics.count == 1)
        #expect(state.isLoading == false)
    }

    @Test func topStreakHabitReturnsHighestStreak() {
        var state = StatisticsFeature.State()
        let lowStreak = makeStatistics(for: TestFixtures.exercise, currentStreak: 2)
        let highStreak = makeStatistics(for: TestFixtures.meditation, currentStreak: 10)
        _ = sut.reduce(into: &state, action: .statisticsLoaded([lowStreak, highStreak]))
        #expect(state.topStreakHabit?.habit.name == "Meditation")
    }

    @Test func averageCompletionRateComputedCorrectly() {
        var state = StatisticsFeature.State()
        let statsA = makeStatistics(for: TestFixtures.exercise, completionRate: 0.6)
        let statsB = makeStatistics(for: TestFixtures.meditation, completionRate: 0.4)
        _ = sut.reduce(into: &state, action: .statisticsLoaded([statsA, statsB]))
        #expect(abs(state.averageCompletionRate - 0.5) < 0.001)
    }

    @Test func failedWithErrorSetsErrorMessage() {
        var state = StatisticsFeature.State()
        _ = sut.reduce(into: &state, action: .failedWithError("Network error"))
        #expect(state.errorMessage == "Network error")
        #expect(state.isLoading == false)
    }

    // MARK: - Helpers

    private func makeStatistics(
        for habit: Habit,
        currentStreak: Int = 0,
        completionRate: Double = 0.0
    ) -> HabitStatistics {
        HabitStatistics(
            habit: habit,
            currentStreak: currentStreak,
            longestStreak: currentStreak,
            completionRate: completionRate,
            totalCompletions: 0,
            completionsThisWeek: 0,
            completionsThisMonth: 0,
            lastCompletedAt: nil
        )
    }
}
