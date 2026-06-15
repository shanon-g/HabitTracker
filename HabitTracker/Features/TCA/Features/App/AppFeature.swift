import Foundation

// MARK: - App Feature (Root Coordinator)
//
// TCA: the App feature coordinates top-level navigation and owns child feature stores.
// This demonstrates how TCA composes features — each tab's state is a slice of AppFeature.State.

struct AppDependencies: Sendable {
    var repository: any HabitRepository
}

struct AppFeature: Reducer {

    // MARK: State
    //
    // The app's entire state tree lives here.
    // Every screen's state is a property of this root state.

    struct State: Equatable, Sendable {
        var habitList = HabitListFeature.State()
        var statistics = StatisticsFeature.State()
        var selectedTab: AppTab = .habits
    }

    // MARK: Action

    enum Action: Sendable {
        case habitList(HabitListFeature.Action)
        case statistics(StatisticsFeature.Action)
        case tabSelected(AppTab)
    }

    // MARK: Dependencies

    let dependencies: AppDependencies

    // MARK: Reducer

    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        switch action {

        case .habitList(let childAction):
            let childReducer = HabitListFeature(
                dependencies: HabitListDependencies(repository: dependencies.repository)
            )
            let effect = childReducer.reduce(into: &state.habitList, action: childAction)
            return effect.map(Action.habitList)

        case .statistics(let childAction):
            let childReducer = StatisticsFeature(
                dependencies: StatisticsDependencies(repository: dependencies.repository)
            )
            let effect = childReducer.reduce(into: &state.statistics, action: childAction)
            return effect.map(Action.statistics)

        case .tabSelected(let tab):
            state.selectedTab = tab
            // When switching to statistics, refresh them.
            if tab == .statistics {
                return .send(.statistics(.onAppear))
            }
            return .none
        }
    }
}

// MARK: - AppTab

enum AppTab: Equatable, Sendable {
    case habits
    case statistics
}
