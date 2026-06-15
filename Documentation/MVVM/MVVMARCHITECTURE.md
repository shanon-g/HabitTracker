# MVVM + Use Cases Architecture

## Philosophy

MVVM separates **what to show** from **how to show it**.

A ViewModel takes domain data from Use Cases and shapes it for a specific screen. It knows about presentation concepts — loading states, error messages, sorted lists — while remaining ignorant of SwiftUI layout.

The key question MVVM answers: **what does this specific screen need to know, and who is responsible for knowing it?**

Each screen has its own ViewModel. The ViewModel owns that screen's state. When you navigate away, the ViewModel goes with you. When you navigate back, a new ViewModel is created fresh. This per-screen scoping is both a strength and a weakness.

Use Cases own the business rules. ViewModels coordinate Use Cases but do not contain business logic themselves. The layering is deliberate:

```
View → ViewModel → Use Case → Domain → Repository
```

---

## Folder Structure

```
Features/MVVM/
  ViewModels/
    HabitListViewModel.swift    ← List screen state + coordination
    HabitDetailViewModel.swift  ← Detail screen state + completion
    AddHabitViewModel.swift     ← Form state + validation + creation
    StatisticsViewModel.swift   ← Aggregated stats for summary screen
  Views/
    MVVMRootView.swift          ← Constructs ViewModels with dependencies; owns tabs
    MVVMHabitListView.swift     ← Binds to HabitListViewModel
    MVVMHabitDetailView.swift   ← Binds to HabitDetailViewModel
    MVVMAddHabitView.swift      ← Binds to AddHabitViewModel
    MVVMStatisticsView.swift    ← Binds to StatisticsViewModel
    MVVMHabitRowView.swift      ← Props-only; no ViewModel
    MVVMStatisticsGridView.swift
    MVVMEmptyStateView.swift
```

---

## Data Flow

```
MVVMRootView
  ├── creates: HabitListViewModel(repository:)
  └── creates: StatisticsViewModel(repository:)
         │
         ▼
  MVVMHabitListView(@State var viewModel)
  ├── reads: viewModel.habits
  ├── reads: viewModel.statistics
  ├── calls: viewModel.loadHabits()
  ├── calls: viewModel.createHabit(...)
  └── navigates to: MVVMHabitDetailView
            │
            ▼ (creates HabitDetailViewModel for this habit)
       MVVMHabitDetailView(@State var viewModel)
       ├── reads: viewModel.statistics
       └── calls: viewModel.completeHabit()
```

Each screen manages its own lifecycle. When `MVVMHabitDetailView` appears, it creates its own `HabitDetailViewModel`, loads statistics, and owns that data independently.

---

## State Ownership

**Each ViewModel owns its screen's state.**

- `HabitListViewModel` owns: `habits`, `statistics`, `isLoading`, `errorMessage`
- `HabitDetailViewModel` owns: `statistics` for a specific habit, `isLoading`, `errorMessage`
- `AddHabitViewModel` owns: form fields (`name`, `description`), validation state, `isSaving`, `didSave`
- `StatisticsViewModel` owns: aggregated statistics, computed summaries

Views declare `@State var viewModel: SomeViewModel` and receive a constructed ViewModel from their parent. The parent (e.g., `MVVMRootView`) owns the dependency construction.

**Key contrast with MV**: state is not shared. If you complete a habit in `HabitDetailView`, `HabitListView` does not automatically see the update. The parent must trigger a reload (via `onSave` callback or similar).

---

## Dependency Flow

```
MVVMRootView (receives repository)
    ├── HabitListViewModel(repository:)
    │       ├── CreateHabitUseCase(repository:)
    │       ├── CompleteHabitUseCase(repository:)
    │       ├── DeleteHabitUseCase(repository:)
    │       └── GenerateStatisticsUseCase(repository:)
    └── StatisticsViewModel(repository:)
            ├── repository (for fetching habits)
            └── GenerateStatisticsUseCase(repository:)

MVVMHabitListView
    └── constructs HabitDetailViewModel(habit:, repository:) on navigation
    └── constructs AddHabitViewModel(repository:) on sheet presentation
```

Dependencies are passed from parent views to child ViewModels. The repository flows down the tree through constructor injection.

---

## Business Logic Placement

| Concern              | Location           |
|----------------------|--------------------|
| State mutation       | ViewModel          |
| Presentation logic   | ViewModel          |
| Input validation     | ViewModel          |
| Business rules       | Use Cases          |
| Persistence          | HabitRepository    |
| Layout & rendering   | Views              |

The ViewModel knows about presentation concepts: "is the save button enabled?", "what text should the error alert show?", "should the list be sorted by name?". Use Cases know about domain concepts: "is this habit already completed today?", "what is the current streak?".

---

## Navigation

Navigation in MVVM uses `NavigationLink` with a closure-based destination:

```swift
NavigationLink {
    MVVMHabitDetailView(
        viewModel: HabitDetailViewModel(habit: habit, repository: repository)
    )
} label: {
    MVVMHabitRowView(...)
}
```

The parent view constructs the destination ViewModel and passes it to the destination view. This means:
- Each navigation creates a fresh ViewModel (and a fresh data load)
- The ViewModel lifecycle is tied to the view lifecycle
- There is no shared navigation state

---

## Testing Strategy

Test each ViewModel independently:

```swift
let repository = InMemoryHabitRepository()
let vm = HabitListViewModel(repository: repository)
await vm.loadHabits()
#expect(vm.habits.isEmpty)

await vm.createHabit(name: "Run", description: "", frequency: .daily)
#expect(vm.habits.count == 1)
```

Advantages:
- Each ViewModel is independently testable
- No shared state between tests
- Validation logic in `AddHabitViewModel` is directly verifiable

---

## Advantages

- **Screen isolation** — each screen's state is entirely contained in its ViewModel
- **Focused state** — no screen knows about data it doesn't need
- **Independent testability** — each ViewModel can be tested in isolation
- **Familiar pattern** — widely understood across iOS, Android, and web
- **Clear responsibilities** — presentation logic has an obvious home

## Disadvantages

- **State synchronization** — updating shared data across screens requires callbacks or re-loading
- **Boilerplate** — one ViewModel per screen multiplies files quickly
- **Navigation complexity** — constructing ViewModels during navigation creates coupling between parent and child
- **Duplication** — multiple ViewModels may implement similar patterns (load, error, loading state)

## When to Use

- Medium-to-large applications with many screens
- Teams where clear per-screen ownership matters
- Apps where most screens are relatively independent
- Teams migrating from UIKit MVVM
- When testability of individual screens is a priority
