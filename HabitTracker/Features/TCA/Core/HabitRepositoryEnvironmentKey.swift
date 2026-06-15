import SwiftUI

// MARK: - Habit Repository Environment Key
//
// TCA's dependency management is inspired by SwiftUI's Environment.
// The real TCA library uses a `@Dependency` property wrapper backed by `DependencyValues`.
// Here we demonstrate the same concept using SwiftUI's native `@Environment`.
//
// This makes dependencies:
// - Explicit (visible in the view hierarchy)
// - Swappable (preview, test, and production values differ)
// - Testable (inject a mock by setting the environment value)

private struct HabitRepositoryKey: EnvironmentKey {
    static let defaultValue: any HabitRepository = InMemoryHabitRepository()
}

extension EnvironmentValues {
    /// The shared `HabitRepository` for TCA features.
    var habitRepository: any HabitRepository {
        get { self[HabitRepositoryKey.self] }
        set { self[HabitRepositoryKey.self] = newValue }
    }
}
