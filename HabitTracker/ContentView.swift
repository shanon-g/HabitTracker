import SwiftUI
import SwiftData

// MARK: - App Entry Point

@main
struct HabitTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ArchitectureSelectorView()
                .modelContainer(ModelContainer.habitTracker)
        }
    }
}

// MARK: - Architecture Selector

/// Top-level view that lets you explore all three architecture implementations
/// side-by-side in the same app, using the same shared persistence layer.
struct ArchitectureSelectorView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = ArchitectureTab.mv

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("MV", systemImage: "m.circle.fill", value: ArchitectureTab.mv) {
                MVStack(modelContext: modelContext)
            }
            Tab("MVVM", systemImage: "v.circle.fill", value: ArchitectureTab.mvvm) {
                MVVMStack(modelContext: modelContext)
            }
            Tab("TCA", systemImage: "t.circle.fill", value: ArchitectureTab.tca) {
                TCAStack(modelContext: modelContext)
            }
        }
    }
}

enum ArchitectureTab: Equatable {
    case mv, mvvm, tca
}

// MARK: - Architecture Stacks
// Each stack constructs its own repository from the shared ModelContext.
// All three architectures share the same underlying SwiftData store —
// a key property of the domain-layer abstraction.

struct MVStack: View {
    let modelContext: ModelContext
    var body: some View {
        MVRootView(repository: SwiftDataHabitRepository(modelContext: modelContext))
    }
}

struct MVVMStack: View {
    let modelContext: ModelContext
    var body: some View {
        MVVMRootView(repository: SwiftDataHabitRepository(modelContext: modelContext))
    }
}

struct TCAStack: View {
    let modelContext: ModelContext
    var body: some View {
        TCAAppView(repository: SwiftDataHabitRepository(modelContext: modelContext))
    }
}

#Preview {
    ArchitectureSelectorView()
        .modelContainer(ModelContainer.preview)
}
