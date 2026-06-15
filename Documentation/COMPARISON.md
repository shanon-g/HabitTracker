# SwiftUI Architecture Comparison

This document compares three modern SwiftUI architectures implemented for the same Habit Tracker application. Every observation is grounded in the implementations in this repository — not in theory.

---

## The Application

A Habit Tracker with:
- Create, complete, and delete habits
- Daily and weekly frequency tracking
- Streak calculation and completion rates
- Statistics summary screen
- Navigation from list → detail
- Add habit sheet

This scope is intentionally constrained. The goal is not feature richness — it is architectural clarity.

---

## Domain Layer (Shared Across All Architectures)

All three architectures share an identical domain layer:

```
Domain/
  Models/       Habit, HabitCompletion, HabitFrequency, HabitStatistics
  Errors/       HabitError
  Repositories/ HabitRepository (protocol)
  UseCases/     CreateHabit, CompleteHabit, DeleteHabit,
                CalculateStreak, CalculateCompletionRate, GenerateStatistics
```

**Key principle**: the domain layer has zero imports of SwiftUI, SwiftData, Observation, or TCA. It is pure Swift. Any architecture can consume it. Any target (iOS, macOS, server) can import it.

Use Cases are structs. They receive a `HabitRepository` at initialization and expose a single `execute(...)` method. They contain the application's business rules.

---

## Architecture Comparison Matrix

| Dimension                  | MV + Use Cases           | MVVM + Use Cases               | TCA + Use Cases                  |
|----------------------------|--------------------------|-------------------------------|----------------------------------|
| **State type**             | Reference (`@Observable` class) | Reference (`@Observable` class) | Value (`struct`)           |
| **State location**         | Single shared Store      | Per-screen ViewModel          | Single value tree (AppFeature.State) |
| **State sharing**          | Automatic (environment)  | Manual (callbacks/re-load)    | Automatic (parent state)         |
| **Mutation mechanism**     | Methods on Store         | Methods on ViewModel          | `store.send(.action)`            |
| **Business logic location**| Use Cases                | Use Cases                     | Use Cases (inside Effects)       |
| **Presentation logic**     | Store or View            | ViewModel                     | Reducer                          |
| **Async model**            | `async/await` in methods | `async/await` in methods      | `Effect.run` in reducers         |
| **Navigation model**       | Value-based NavigationStack | NavigationLink with destination | State-driven bindings         |
| **DI mechanism**           | `@Environment` injection | Constructor injection         | Reducer dependencies + `@Environment` |
| **Testability**            | Test Store methods       | Test ViewModel methods        | Test reducer (synchronous!)      |
| **Boilerplate**            | Low                      | Medium                        | High                             |
| **Learning curve**         | Low                      | Low-Medium                    | High                             |

---

## State Management

### MV

```swift
// State lives in one place:
@Observable final class HabitStore {
    private(set) var habits: [Habit] = []
    private(set) var statistics: [UUID: HabitStatistics] = [:]
}

// Any view can read it:
@Environment(HabitStore.self) private var store
Text(store.habits.count.description)
```

**Consequence**: a habit completed in the detail view instantly appears updated in the list view — they share the same store reference. Zero synchronization code.

### MVVM

```swift
// State lives per-screen:
@Observable final class HabitListViewModel {
    private(set) var habits: [Habit] = []
}

// Updating the list after a detail action requires a callback:
MVVMHabitListView(..., onSave: handleHabitAdded)

private func handleHabitAdded() {
    Task { await viewModel.loadHabits() }  // reload from scratch
}
```

**Consequence**: cross-screen state updates require explicit coordination. For a small app this is manageable. For a large app, callback pyramids emerge.

### TCA

```swift
// State is a value tree:
struct AppFeature: Reducer {
    struct State: Equatable, Sendable {
        var habitList = HabitListFeature.State()
        var statistics = StatisticsFeature.State()
    }
}

// All state changes flow through actions:
store.send(.habitList(.completeHabitButtonTapped(habit)))
```

**Consequence**: every state change is an explicit action. You can see, test, and replay every transition. The trade-off is verbosity — a button press requires an action case, a reducer case, and an effect.

---

## Business Logic Organization

All three architectures use the same Use Cases. The difference is **how they call them**:

### MV
```swift
// Store calls use cases directly:
func completeHabit(_ habit: Habit) async {
    do {
        _ = try await completeHabitUseCase.execute(habit: habit)
    } catch { ... }
}
```

### MVVM
```swift
// ViewModel calls use cases directly:
func completeHabit() async {
    do {
        _ = try await completeHabitUseCase.execute(habit: habit)
    } catch { ... }
}
```

### TCA
```swift
// Reducer wraps use case in an Effect:
case .completeButtonTapped:
    return .run { [deps = dependencies, habit = state.habit] send in
        do {
            _ = try await CompleteHabitUseCase(repository: deps.repository).execute(habit: habit)
            await send(.completionRecorded(...))
        } catch {
            await send(.failedWithError(error.localizedDescription))
        }
    }
```

**Observation**: MV and MVVM code reads like straightforward Swift. TCA code is more explicit but more verbose. The TCA version makes the async result visible as an enum case — a failure is handled explicitly in the reducer, not buried in a catch block.

---

## Dependency Injection

### MV

The repository flows through the environment:
```swift
// Root creates store with repository:
MVRootView(repository: SwiftDataHabitRepository(modelContext: modelContext))

// Store holds all use cases:
init(repository: any HabitRepository) {
    createHabitUseCase = CreateHabitUseCase(repository: repository)
    ...
}
```

Dependencies are visible at the Store level. Views never see the repository directly.

### MVVM

The repository is passed to each ViewModel constructor:
```swift
// Parent creates child VM with repository:
MVVMHabitDetailView(
    viewModel: HabitDetailViewModel(habit: habit, repository: repository)
)
```

The repository flows explicitly through the view hierarchy. Parent views know about the dependencies of child views — creating a visible dependency graph.

### TCA

Dependencies are declared in `Reducer` types and passed via environment:
```swift
struct HabitListFeature: Reducer {
    let dependencies: HabitListDependencies  // ← explicit
}

// Screen-level: via @Environment:
@Environment(\.habitRepository) private var repository
```

TCA's dependencies are the most explicit. Every reducer declares exactly what it needs. The full dependency graph is inspectable from the type system.

---

## Navigation

### MV
```swift
NavigationStack {
    MVHabitListView()
        .navigationDestination(for: Habit.self) { habit in
            MVHabitDetailView(habit: habit)
        }
}
```
Value-based navigation. Clean. The store handles state; navigation is purely structural.

### MVVM
```swift
NavigationLink {
    MVVMHabitDetailView(
        viewModel: HabitDetailViewModel(habit: habit, repository: repository)
    )
} label: { ... }
```
Destination-based navigation. The parent constructs the destination's ViewModel — coupling parent to child's dependency shape.

### TCA
```swift
.sheet(isPresented: Binding(
    get: { state.isShowingAddHabit },
    set: { if !$0 { store.send(.habitList(.addHabitDismissed)) } }
))
```
State-driven navigation. Showing a sheet is a state change; dismissing it sends an action. This makes navigation fully testable — check `state.isShowingAddHabit == true` without running the UI.

---

## Testability

### Domain Layer (identical across all architectures)

```swift
// Pure use case test — no architecture dependency:
let repository = InMemoryHabitRepository()
let useCase = CalculateStreakUseCase(calendar: .fixedUTC)
let result = useCase.execute(habit: habit, completions: completions)
#expect(result.current == 5)
```

Domain tests are the same regardless of which architecture is used. This is the domain layer's primary value.

### MV
```swift
// Test the Store:
let store = HabitStore(repository: InMemoryHabitRepository())
await store.createHabit(name: "Run", description: "", frequency: .daily)
#expect(store.habits.count == 1)
```
Async, but straightforward. You test observable state changes.

### MVVM
```swift
// Test the ViewModel:
let vm = AddHabitViewModel(repository: InMemoryHabitRepository())
vm.name = "Yoga"
#expect(vm.isValid == true)
await vm.saveHabit()
#expect(vm.didSave == true)
```
Each ViewModel is independently testable. Validation logic is directly verifiable.

### TCA
```swift
// Test the Reducer (synchronous!):
var state = HabitListFeature.State()
let reducer = HabitListFeature(dependencies: ...)
_ = reducer.reduce(into: &state, action: .onAppear)
#expect(state.isLoading == true)

_ = reducer.reduce(into: &state, action: .habitsLoaded([habit]))
#expect(state.habits.count == 1)
#expect(state.isLoading == false)
```
No async. No waiting. State transitions are functions. This is TCA's defining testing advantage — you can test a complex sequence of actions in milliseconds.

---

## Feature Composition

### MV
Features share the same `HabitStore`. Composition is implicit — all views access the same state. Adding a new screen means reading from the existing store. No composition mechanism is required.

**Trade-off**: everything grows into the store as the app scales.

### MVVM
Each feature has its own ViewModel. Composition is achieved by creating ViewModels in parent views and passing them to child views. There is no formal composition mechanism — each screen is independent.

**Trade-off**: cross-feature communication requires callbacks, notifications, or shared singletons.

### TCA
Features are composed via the `AppFeature` reducer:

```swift
case .habitList(let childAction):
    let effect = childReducer.reduce(into: &state.habitList, action: childAction)
    return effect.map(Action.habitList)
```

Adding a new feature means adding a `State` property to `AppFeature.State` and a routing case in `AppFeature.Action`. The composition is explicit and mechanical.

**Trade-off**: every new feature adds ceremony to the root reducer.

---

## SwiftUI Integration

| Aspect              | MV                         | MVVM                       | TCA                          |
|---------------------|----------------------------|----------------------------|------------------------------|
| Data binding        | `@Environment` (best fit)  | `@State var vm` (good)     | Manual `Binding` wrappers    |
| View reactivity     | Automatic via `@Observable`| Automatic via `@Observable`| Automatic via `@Observable Store` |
| Local UI state      | `@State` in views          | ViewModel or `@State`      | Reducer state or `@State`    |
| Animations          | Standard SwiftUI           | Standard SwiftUI           | Triggered by state changes   |
| Previews            | Simple (inject store)      | Simple (inject ViewModel)  | Simple (inject Store)        |

MV and MVVM align most naturally with SwiftUI's idioms. TCA works well but requires manually constructing `Binding` wrappers for every text field and toggle, which adds friction.

---

## Scalability

### MV
Scales well up to medium complexity. As the app grows, the store accumulates properties and methods. At some point the store becomes difficult to navigate. The absence of a ViewModel layer means you either grow the store or start adding ViewModels — at which point you've converged toward MVVM.

### MVVM
Scales predictably. Adding a new screen means adding a new ViewModel. The pattern remains consistent regardless of app size. The challenge is coordinating shared state between screens as the app grows.

### TCA
Designed to scale to large applications. Each feature is isolated. Adding a new feature is mechanical. The root App reducer grows, but each child feature remains small and independent. The ceremony per feature is the cost — but it pays off in large, team-built applications.

---

## Team Scalability

| Aspect               | MV           | MVVM          | TCA              |
|----------------------|--------------|---------------|------------------|
| Onboarding           | Easy         | Easy-Medium   | Hard             |
| Parallel development | Difficult    | Good          | Excellent        |
| Code review          | Simple       | Simple        | Reviewable (actions are explicit) |
| Merge conflicts      | Common (shared store) | Rare (isolated VMs) | Rare (isolated features) |
| Consistency          | Developer-dependent | Pattern guides | Pattern enforces |

---

## Final Observations

### MV: Best for simplicity and speed

MV is the right choice when you want to move fast and the app is not too large. SwiftUI's native observation model is genuinely powerful. The absence of boilerplate is a real productivity win. The cost emerges when the app grows and the shared store becomes a coordination problem.

**The question MV asks**: "Do you really need a ViewModel, or is that extra layer solving a problem you don't have yet?"

### MVVM: Best for screen-level isolation

MVVM is the right choice when you want predictable, isolated screens. The pattern is familiar across platforms. Each screen is easy to reason about in isolation. The cost is the shared-state coordination problem — a problem you feel more as the app grows.

**The question MVVM asks**: "What does this specific screen need to know, and who owns that knowledge?"

### TCA: Best for complex, team-built applications

TCA is the right choice when testability, predictability, and team scalability are paramount. The ceremony is real but it pays for itself. The ability to test state transitions synchronously, to replay actions, and to isolate features completely is genuinely valuable at scale.

**The question TCA asks**: "What are all the possible events in this feature, and what does each one mean for the state?"

---

## Architectural Selection Guide

```
Is this a small app or prototype?
    └── Yes → MV

Are most screens independent (CRUD-style features)?
    └── Yes → MVVM

Is shared state a primary concern?
    ├── Yes, and simplicity matters → MV
    └── Yes, and testability matters → TCA

Does your team need strict feature isolation?
    └── Yes → TCA

Do you want maximum SwiftUI alignment?
    └── MV or MVVM

Is time-travel debugging or state replay valuable?
    └── TCA
```

---

## Shared Infrastructure

All three architectures share:

- **Domain models** — `Habit`, `HabitCompletion`, `HabitFrequency`, `HabitStatistics`
- **Use Cases** — identical business rules across all implementations
- **Repository protocol** — `HabitRepository` abstracts persistence
- **SwiftData implementation** — `SwiftDataHabitRepository` is shared
- **Testing infrastructure** — `InMemoryHabitRepository` and `TestFixtures` are shared

The domain layer is the repository's most important contribution. Use Cases tested once are valid everywhere. The architecture affects how you call the Use Cases — it does not affect what the Use Cases do.
