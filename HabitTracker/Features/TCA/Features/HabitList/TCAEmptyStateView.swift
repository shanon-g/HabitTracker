import SwiftUI

/// TCA Architecture — empty state.
struct TCAEmptyStateView: View {
    var body: some View {
        ContentUnavailableView(
            "No Habits Yet",
            systemImage: "checkmark.circle",
            description: Text("Tap + to add your first habit.")
        )
    }
}
