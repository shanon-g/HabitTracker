# TCA + Use Cases Architecture

## Philosophy

TCA (The Composable Architecture) is built on a single premise: **the entire state of a feature can be described as a value type, and every event that can happen is described as an enum case.**

This sounds simple. The implications are profound.

When state is a value type (struct), every mutation produces a new value. There is no "hidden" state, no observable side effects of reading state, and no shared mutable references. Testing a state transition is as simple as constructing a state, calling a function, and inspecting the result — no async, no stubs, no mocks required.

When every event is an enum case, the compiler enforces that you handle every possible event. There are no "invisible" paths through your code. The full lifecycle of a feature — user interactions, async results, lifecycle events — is visible at a glance.

Use Cases fit naturally into TCA's Effects system. Effects describe async work. A Use Case is called inside an `Effect.run` closure, and its result is sent back to the reducer as an action.

> **Note:** This repository includes a micro-TCA implementation that demonstrates TCA's architecture faithfully without an external dependency. In production, use [Point-Free's Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture).

---

## Folder Structure

```
Features/TCA/
  Core/
    TCACore.swift                         ← Micro-TCA: Reducer, Effect, Store, Send
    HabitRepositoryEnvironmentKey.swift   ← @Environment key for dependency injection
  Features/
    App/
      AppFeature.swift     ← Root reducer composing all child features
      TCAAppView.swift     ← Root view; owns the single AppFeature store
    HabitList/
      HabitListFeature.swift  ← Reducer with State, Action, Dependencies
      TCAHabitListView.swift  ← Reads from store.state.habitList
      TCAHabitRowView.swift
      TCAEmptyStateView.swift
    HabitDetail/
      HabitDetailFeature.swift
      TCAHabitDetailView.swift
    AddHabit/
      AddHabitFeature.swift
      TCAAddHabitView.swift
    Statistics/
      StatisticsFeature.swift
      TCAStatisticsView.swift
```

---

## Data Flow

TCA enforces a strict unidirectional data flow:

```
View
  │  store.send(.someAction)
  ▼
Reducer
  │  reduce(into: &state, action: .someAction) → Effect
  │  (synchronous state mutation)
  ▼
Store (publishes new state)
  │  Effect executes async work
  ▼
Effect
  │  await send(.resultAction)
  ▼
Reducer again (processes the result action)
  │
  ▼
Store (publishes updated state)
  │
  ▼
View re-renders
```

Every single state change flows through this pipeline. There are no "side paths" where state changes happen outside the reducer.

---

## State Ownership

**The Store owns all state as a single value tree.**

```swift
AppFeature.State
├── habitList: HabitListFeature.State
│       ├── habits: [Habit]
│       ├── statistics: [UUID: HabitStatistics]
│       ├── isLoading: Bool
│       ├── errorMessage: String?
│       ├── isShowingAddHabit: Bool
│       └── addHabitState: AddHabitFeature.State?
└── statistics: StatisticsFeature.State
        ├── habitStatistics: [HabitStatistics]
        ├── isLoading: Bool
        └── errorMessage: String?
```

The entire app state is inspectable at any point. You can snapshot it, serialize it, restore it, and replay any sequence of actions.

**Key contrast with MV and MVVM**: in TCA, state is a value type tree. In MV and MVVM, state is spread across reference-type classes. TCA's state is inherently testable and reproducible.

---

## Dependency Flow

TCA's dependencies are explicit at the reducer level, not hidden in closures or singletons.

```swift
struct HabitListFeature: Reducer {
    let dependencies: HabitListDependencies  // ← explicit, injected
    
    func reduce(into state: inout State, action: Action) -> Effect<Action> {
        // dependencies is used inside effects
        return .run { [deps = dependencies] send in
            let habits = try await deps.repository.fetchHabits()
            await send(.habitsLoaded(habits))
        }
    }
}
```

Dependencies are constructed at app startup and passed down:

```
TCAAppView
  └── Store<AppFeature>(
            reducer: AppFeature(
                dependencies: AppDependencies(repository: repository)
            )
        )
        └── (routes to child reducers with their own dependencies)
```

For screen-level dependencies (like `HabitDetailFeature`), the repository is propagated via SwiftUI's `@Environment`, demonstrating TCA's own pattern of environment-based dependency injection.

---

## Business Logic Placement

| Concern              | Location                      |
|----------------------|-------------------------------|
| State mutation       | Reducer (`reduce` function)   |
| Event description    | Action enum                   |
| Side effects / I/O   | Effect.run closures           |
| Business rules       | Use Cases (inside Effects)    |
| Persistence          | HabitRepository               |
| Layout & rendering   | Views                         |

The reducer is responsible for state transitions only. It delegates I/O to Effects, which delegate business logic to Use Cases.

---

## Feature Composition

TCA's most powerful feature is composition. The `AppFeature` reducer routes child actions to child reducers:

```swift
case .habitList(let childAction):
    let childReducer = HabitListFeature(dependencies: ...)
    let effect = childReducer.reduce(into: &state.habitList, action: childAction)
    return effect.map(Action.habitList)  // ← lift child effect to parent action space
```

Each child feature is independent. It handles its own actions, manages its own state slice, and can be developed and tested in complete isolation. Feature composition is mechanical — the parent simply routes and lifts.

---

## Navigation

TCA's navigation is driven by state. The presence or absence of optional state determines whether a sheet, alert, or destination is shown:

```swift
// In HabitListFeature.State:
var isShowingAddHabit: Bool = false
var addHabitState: AddHabitFeature.State? = nil

// In the view:
.sheet(isPresented: Binding(
    get: { state.isShowingAddHabit },
    set: { if !$0 { store.send(.habitList(.addHabitDismissed)) } }
))
```

Navigation is a state transition, not an imperative call. This makes navigation fully testable without running the app.

---

## Testing Strategy

TCA's greatest testing advantage: **state transitions are pure functions, testable without async or mocks.**

```swift
var state = HabitListFeature.State()
let sut = HabitListFeature(dependencies: deps)

// Test synchronous state transitions:
_ = sut.reduce(into: &state, action: .onAppear)
#expect(state.isLoading == true)

_ = sut.reduce(into: &state, action: .habitsLoaded([TestFixtures.exercise]))
#expect(state.habits.count == 1)
#expect(state.isLoading == false)
```

For async effects, use the real `InMemoryHabitRepository` or mock the `Effect.run` closure directly.

**Three levels of testing:**
1. **Reducer tests** — synchronous, fast, no async needed
2. **Effect tests** — use `InMemoryHabitRepository` to verify async operations
3. **Integration tests** — run the full Store with live effects

---

## Advantages

- **Predictable state** — every mutation is visible and traceable
- **Exhaustive actions** — every event is handled; the compiler enforces it
- **Powerful testing** — pure state transitions are trivially testable
- **Time-travel debugging** — state can be replayed from any point
- **Feature isolation** — each feature is independently developed and tested
- **Explicit dependencies** — no hidden globals or singletons

## Disadvantages

- **High upfront cost** — every feature requires State, Action, Reducer, Effect
- **Steep learning curve** — the action-driven model is unfamiliar to most Swift developers
- **Verbose for simple features** — a toggle takes five lines of code (state, action, reducer case, effect, view binding)
- **Navigation complexity** — state-driven navigation requires careful state design
- **External dependency** — the full TCA library is large and evolves rapidly

## When to Use

- Large applications with complex state management needs
- Teams where testability and predictability are top priorities
- Applications where undo/redo or time-travel debugging are valuable
- Large teams where clear feature boundaries prevent merge conflicts
- When you need to scale individual features independently
