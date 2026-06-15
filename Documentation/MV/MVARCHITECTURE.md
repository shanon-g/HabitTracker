# MV + Use Cases Architecture

## Philosophy

The MV architecture asks a simple question: **how far can SwiftUI's native data flow scale before you need to add another layer?**

Modern SwiftUI (iOS 17+) introduced `@Observable`, which makes class instances first-class citizens in the reactive system. A `@Observable` class can replace an `ObservableObject` with less code, less boilerplate, and more precise updates.

The MV architecture pushes this observation model to its natural limit: a single `HabitStore` replaces a fleet of ViewModels. Views read state directly from the store injected via `@Environment`. There are no intermediaries between the view and its data.

Use Cases remain a first-class concept. Business logic does **not** live in the Store — it lives in domain Use Cases. The Store's job is coordination: it calls Use Cases, receives results, and publishes state changes.

---

## Folder Structure

```
Features/MV/
  Store/
    HabitStore.swift         ← Single source of truth; coordinates use cases
  Views/
    MVRootView.swift         ← Injects store into environment; owns navigation
    MVHabitListView.swift    ← Reads from @Environment(HabitStore.self)
    MVHabitDetailView.swift  ← Reads from @Environment(HabitStore.self)
    MVHabitRowView.swift     ← Receives data as props; no direct store access
    MVAddHabitView.swift     ← Local @State for form; calls store actions
    MVStatisticsView.swift   ← Reads from @Environment(HabitStore.self)
    MVStatisticsGridView.swift
    MVEmptyStateView.swift
```

---

## Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                     HabitStore (@Observable)                │
│  - habits: [Habit]                                          │
│  - statistics: [UUID: HabitStatistics]                      │
│  - isLoading: Bool                                          │
│  - error: HabitError?                                       │
│                                                             │
│  Uses: CreateHabitUseCase, CompleteHabitUseCase,            │
│        DeleteHabitUseCase, GenerateStatisticsUseCase        │
└─────────────────────┬───────────────────────────────────────┘
                      │ @Environment injection
        ┌─────────────┼────────────────┐
        ▼             ▼                ▼
  HabitListView  HabitDetailView  StatisticsView
     (reads)        (reads)          (reads)
     (calls)        (calls)
```

Views read state and call store methods. The store updates state. SwiftUI re-renders automatically.

---

## State Ownership

**The Store owns all state.**

- Views declare `@Environment(HabitStore.self) private var store`
- Views read `store.habits`, `store.statistics`, etc.
- Views trigger mutations by calling `store.createHabit(...)`, `store.completeHabit(...)`, etc.
- State is never duplicated between views — all views share the same store instance

This is the key difference from MVVM: in MVVM, each screen has its own ViewModel with its own copy of state. In MV, all screens share a single state source.

---

## Dependency Flow

```
MVRootView
    └── HabitStore (owns all use cases)
            ├── CreateHabitUseCase     → HabitRepository
            ├── CompleteHabitUseCase   → HabitRepository
            ├── DeleteHabitUseCase     → HabitRepository
            └── GenerateStatisticsUseCase → HabitRepository → CalculateStreakUseCase
                                                             → CalculateCompletionRateUseCase
```

The `repository: any HabitRepository` is injected at the `MVRootView` level and flows down through the store.

---

## Business Logic Placement

| Concern              | Location           |
|----------------------|--------------------|
| State mutation       | HabitStore         |
| Coordination         | HabitStore         |
| Business rules       | Use Cases          |
| Persistence          | HabitRepository    |
| Form validation      | View (@State)      |
| Layout & rendering   | Views              |

The Store knows **what** needs to happen. Use Cases know **how** to do it.

---

## Navigation

Navigation uses SwiftUI's value-based `NavigationStack` pattern:

```swift
NavigationStack {
    MVHabitListView()
        .navigationDestination(for: Habit.self) { habit in
            MVHabitDetailView(habit: habit)
        }
}
```

`NavigationLink(value: habit)` pushes a destination by type. Navigation state is owned by `MVRootView` and driven by SwiftUI's native stack. There is no router or coordinator layer.

---

## Testing Strategy

Test the Store directly:
```swift
let repository = InMemoryHabitRepository()
let store = HabitStore(repository: repository)
await store.createHabit(name: "Run", ...)
#expect(store.habits.count == 1)
```

- Use `InMemoryHabitRepository` for fast, isolated tests
- Test store methods directly (they're async and testable)
- Do **not** test views directly — test the Store

---

## Advantages

- **Minimal boilerplate** — no ViewModel per screen
- **Shared state** — all screens see the same data immediately
- **Native SwiftUI** — `@Observable`, `@Environment`, and `@State` are all framework-standard
- **Simple mental model** — one store, one truth, one place to look

## Disadvantages

- **Coarse state granularity** — all views re-evaluate when any store property changes
- **Growing store** — as features grow, the store accumulates responsibilities
- **Harder to unit test in isolation** — you must test the whole store, not individual screens
- **Shared state can cause surprises** — a change in one view affects all others immediately

## When to Use

- Small-to-medium applications
- Apps where most features share state (e.g., a dashboard that shows multiple views of the same data)
- Teams familiar with reactive/unidirectional data flow
- Projects where simplicity and velocity matter more than strict separation
