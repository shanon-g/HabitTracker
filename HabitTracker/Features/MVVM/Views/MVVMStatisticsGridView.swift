import SwiftUI

/// MVVM Architecture — statistics grid in detail view.
struct MVVMStatisticsGridView: View {
    let statistics: HabitStatistics

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            MVVMStatCell(value: "\(statistics.currentStreak)", label: "Streak", icon: "flame.fill", color: .orange)
            MVVMStatCell(value: "\(statistics.longestStreak)", label: "Best", icon: "trophy.fill", color: .yellow)
            MVVMStatCell(value: "\(statistics.completionRatePercent)%", label: "Rate (30d)", icon: "chart.bar.fill", color: .blue)
            MVVMStatCell(value: "\(statistics.totalCompletions)", label: "Total", icon: "checkmark.circle.fill", color: .green)
            MVVMStatCell(value: "\(statistics.completionsThisWeek)", label: "This Week", icon: "calendar", color: .purple)
            MVVMStatCell(value: "\(statistics.completionsThisMonth)", label: "This Month", icon: "calendar.badge.checkmark", color: .teal)
        }
        .padding(.vertical, 4)
    }
}

struct MVVMStatCell: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)
            Text(value)
                .font(.title2.bold())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
