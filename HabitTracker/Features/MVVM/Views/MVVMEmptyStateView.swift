import SwiftUI

/// MVVM Architecture — empty state placeholder.
struct MVVMEmptyStateView: View {
    var body: some View {
        ContentUnavailableView(
            "No Habits Yet",
            systemImage: "checkmark.circle",
            description: Text("Tap + to add your first habit.")
        )
    }
}
