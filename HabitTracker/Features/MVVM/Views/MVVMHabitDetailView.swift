import SwiftUI

/// MVVM Architecture — detail screen for a single habit.
///
/// Receives a pre-constructed ViewModel from its parent.
/// The ViewModel owns the screen's state; the view is a pure renderer.
struct MVVMHabitDetailView: View {
    @State var viewModel: HabitDetailViewModel

    init(viewModel: HabitDetailViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        List {
            habitSection
            statisticsSection
            completionSection
        }
        .navigationTitle(viewModel.habit.name)
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            await viewModel.loadStatistics()
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

    private var habitSection: some View {
        Section("Details") {
            LabeledContent("Frequency", value: viewModel.habit.frequency.displayName)
            if !viewModel.habit.habitDescription.isEmpty {
                Text(viewModel.habit.habitDescription)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statisticsSection: some View {
        Section("Statistics") {
            if let stats = viewModel.statistics {
                MVVMStatisticsGridView(statistics: stats)
            } else if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var completionSection: some View {
        Section {
            Button(
                viewModel.statistics?.isCompletedToday == true ? "Completed Today ✓" : "Mark as Complete",
                action: markComplete
            )
            .disabled(viewModel.statistics?.isCompletedToday == true)
            .frame(maxWidth: .infinity)
            .tint(viewModel.statistics?.isCompletedToday == true ? .green : .accentColor)
        }
    }

    private func markComplete() {
        Task {
            await viewModel.completeHabit()
        }
    }
}
