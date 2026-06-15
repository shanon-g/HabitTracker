import SwiftUI

/// MVVM Architecture — statistics summary screen.
struct MVVMStatisticsView: View {
    @State var viewModel: StatisticsViewModel

    init(viewModel: StatisticsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.habitStatistics.isEmpty {
                    ContentUnavailableView(
                        "No Data Yet",
                        systemImage: "chart.bar",
                        description: Text("Add and complete habits to see statistics.")
                    )
                } else {
                    statisticsList
                }
            }
            .navigationTitle("Statistics (MVVM)")
        }
        .task {
            await viewModel.loadStatistics()
        }
    }

    private var statisticsList: some View {
        List {
            MVVMOverviewSection(viewModel: viewModel)
            MVVMHabitBreakdownSection(habitStatistics: viewModel.habitStatistics)
        }
    }
}

/// Overview summary section.
struct MVVMOverviewSection: View {
    let viewModel: StatisticsViewModel

    var body: some View {
        Section("Overview") {
            LabeledContent("Completed Today") {
                Text("\(viewModel.totalCompletionsToday)")
                    .foregroundStyle(.green)
            }
            LabeledContent("Avg. Completion Rate (30d)") {
                Text("\(Int((viewModel.averageCompletionRate * 100).rounded()))%")
            }
            if let top = viewModel.topStreakHabit {
                LabeledContent("Longest Active Streak") {
                    Label("\(top.currentStreak) days — \(top.habit.name)", systemImage: "flame.fill")
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}

/// Per-habit breakdown section.
struct MVVMHabitBreakdownSection: View {
    let habitStatistics: [HabitStatistics]

    var body: some View {
        Section("Habits") {
            ForEach(habitStatistics, id: \.habit.id) { stats in
                MVVMStatisticsRowView(statistics: stats)
            }
        }
    }
}

struct MVVMStatisticsRowView: View {
    let statistics: HabitStatistics

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(statistics.habit.name)
                    .font(.headline)
                Spacer()
                Label("\(statistics.currentStreak)", systemImage: "flame.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            ProgressView(value: statistics.completionRate)
                .tint(.blue)
            Text("\(statistics.completionRatePercent)% completion rate (30 days)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
