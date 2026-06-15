import SwiftUI

/// MVVM Architecture — root navigation container.
/// Constructs the ViewModel with its dependencies and owns navigation state.
/// Child ViewModels are constructed by the parent and passed down.
struct MVVMRootView: View {
    private let repository: any HabitRepository

    @State private var listViewModel: HabitListViewModel
    @State private var statisticsViewModel: StatisticsViewModel

    init(repository: any HabitRepository) {
        self.repository = repository
        _listViewModel = State(initialValue: HabitListViewModel(repository: repository))
        _statisticsViewModel = State(initialValue: StatisticsViewModel(repository: repository))
    }

    var body: some View {
        TabView {
            Tab("Habits", systemImage: "checkmark.circle") {
                MVVMHabitListView(viewModel: listViewModel, repository: repository)
            }
            Tab("Statistics", systemImage: "chart.bar") {
                MVVMStatisticsView(viewModel: statisticsViewModel)
            }
        }
    }
}
