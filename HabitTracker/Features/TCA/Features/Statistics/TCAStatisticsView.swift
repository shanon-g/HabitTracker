import SwiftUI

/// TCA Architecture — statistics view.
struct TCAStatisticsView: View {
    let store: Store<AppFeature>

    private var state: StatisticsFeature.State {
        store.state.statistics
    }

    var body: some View {
        NavigationStack {
            Group {
                if state.isLoading {
                    ProgressView()
                } else if state.habitStatistics.isEmpty {
                    ContentUnavailableView(
                        "No Data Yet",
                        systemImage: "chart.bar",
                        description: Text("Add and complete habits to see statistics.")
                    )
                } else {
                    statisticsList
                }
            }
            .navigationTitle("Statistics (TCA)")
        }
        .task {
            store.send(.statistics(.onAppear))
        }
    }

    private var statisticsList: some View {
        List {
            TCAOverviewSection(state: state)
            TCAHabitBreakdownSection(habitStatistics: state.habitStatistics)
        }
    }
}

struct TCAOverviewSection: View {
    let state: StatisticsFeature.State

    var body: some View {
        Section("Overview") {
            LabeledContent("Completed Today") {
                Text("\(state.totalCompletionsToday)").foregroundStyle(.green)
            }
            LabeledContent("Avg. Completion Rate (30d)") {
                Text("\(Int((state.averageCompletionRate * 100).rounded()))%")
            }
            if let top = state.topStreakHabit {
                LabeledContent("Longest Active Streak") {
                    Label("\(top.currentStreak) days — \(top.habit.name)", systemImage: "flame.fill")
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}

struct TCAHabitBreakdownSection: View {
    let habitStatistics: [HabitStatistics]

    var body: some View {
        Section("Habits") {
            ForEach(habitStatistics, id: \.habit.id) { stats in
                TCAStatisticsRowView(statistics: stats)
            }
        }
    }
}

struct TCAStatisticsRowView: View {
    let statistics: HabitStatistics

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(statistics.habit.name).font(.headline)
                Spacer()
                Label("\(statistics.currentStreak)", systemImage: "flame.fill")
                    .font(.caption).foregroundStyle(.orange)
            }
            ProgressView(value: statistics.completionRate).tint(.blue)
            Text("\(statistics.completionRatePercent)% completion rate (30 days)")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

/// Shared statistics grid for detail views.
struct TCAStatisticsGridView: View {
    let statistics: HabitStatistics

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            TCAStatCell(value: "\(statistics.currentStreak)", label: "Streak", icon: "flame.fill", color: .orange)
            TCAStatCell(value: "\(statistics.longestStreak)", label: "Best", icon: "trophy.fill", color: .yellow)
            TCAStatCell(value: "\(statistics.completionRatePercent)%", label: "Rate (30d)", icon: "chart.bar.fill", color: .blue)
            TCAStatCell(value: "\(statistics.totalCompletions)", label: "Total", icon: "checkmark.circle.fill", color: .green)
            TCAStatCell(value: "\(statistics.completionsThisWeek)", label: "This Week", icon: "calendar", color: .purple)
            TCAStatCell(value: "\(statistics.completionsThisMonth)", label: "This Month", icon: "calendar.badge.checkmark", color: .teal)
        }
        .padding(.vertical, 4)
    }
}

struct TCAStatCell: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundStyle(color).font(.title3)
            Text(value).font(.title2.bold())
            Text(label).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
