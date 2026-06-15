import SwiftUI

/// MVVM Architecture — habit list screen.
///
/// The view binds to its own dedicated ViewModel.
/// Unlike MV, the view does not receive a global store —
/// it receives a scoped ViewModel constructed by its parent.
struct MVVMHabitListView: View {
    @State var viewModel: HabitListViewModel
    private let repository: any HabitRepository

    @State private var isShowingAddHabit = false

    init(viewModel: HabitListViewModel, repository: any HabitRepository) {
        _viewModel = State(initialValue: viewModel)
        self.repository = repository
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.habits.isEmpty && !viewModel.isLoading {
                    MVVMEmptyStateView()
                } else {
                    habitList
                }
            }
            .navigationTitle("Habits (MVVM)")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add Habit", systemImage: "plus", action: showAddHabit)
                }
            }
            .sheet(isPresented: $isShowingAddHabit) {
                MVVMAddHabitView(
                    viewModel: AddHabitViewModel(repository: repository),
                    onSave: handleHabitAdded
                )
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                }
            }
            .alert(
                "Error",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.clearError() } }
                )
            ) {
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
        .task {
            await viewModel.loadHabits()
        }
    }

    private var habitList: some View {
        List {
            ForEach(viewModel.habits) { habit in
                NavigationLink {
                    MVVMHabitDetailView(
                        viewModel: HabitDetailViewModel(habit: habit, repository: repository)
                    )
                } label: {
                    MVVMHabitRowView(habit: habit, statistics: viewModel.statistics[habit.id])
                }
            }
            .onDelete(perform: deleteHabits)
        }
    }

    private func showAddHabit() {
        isShowingAddHabit = true
    }

    private func deleteHabits(at offsets: IndexSet) {
        Task {
            await viewModel.deleteHabits(at: offsets)
        }
    }

    private func handleHabitAdded() {
        Task {
            await viewModel.loadHabits()
        }
    }
}
