import Foundation
import SwiftUI

// MARK: - TCA Core
//
// This is a faithful micro-implementation of The Composable Architecture (TCA) by Point-Free.
// It demonstrates TCA's core patterns: Reducer, Effect, Store, and feature composition.
//
// In a production project, replace this file with Point-Free's library:
//   https://github.com/pointfreeco/swift-composable-architecture
//
// This implementation intentionally mirrors the real TCA API so that migration
// to the full library requires minimal code changes.


// MARK: - Effect

/// Describes an async side effect that may emit zero or more actions back to the store.
///
/// Effects are the TCA mechanism for performing I/O, timers, notifications,
/// and any other work that lives outside pure state mutation.
public struct Effect<Action: Sendable>: Sendable {
    let operation: @Sendable (@escaping @MainActor (Action) -> Void) async -> Void

    init(operation: @Sendable @escaping (@escaping @MainActor (Action) -> Void) async -> Void) {
        self.operation = operation
    }

    /// No-op effect. Use when a reducer has nothing async to do.
    public static var none: Self {
        Effect { _ in }
    }

    /// Immediately sends a single action back to the store.
    public static func send(_ action: Action) -> Self {
        Effect { dispatch in
            await MainActor.run { dispatch(action) }
        }
    }

    /// The primary way to perform async work in TCA.
    /// The `send` closure lets you dispatch actions from inside async code.
    public static func run(
        _ operation: @Sendable @escaping (_ send: Send<Action>) async throws -> Void,
        catch handler: (@Sendable (Error, _ send: Send<Action>) async -> Void)? = nil
    ) -> Self {
        Effect { dispatch in
            let send = Send<Action>(dispatch)
            do {
                try await operation(send)
            } catch {
                if let handler {
                    await handler(error, send)
                }
            }
        }
    }

    /// Merges multiple effects, running them concurrently.
    public static func merge(_ effects: Self...) -> Self {
        Effect { dispatch in
            await withDiscardingTaskGroup { group in
                for effect in effects {
                    group.addTask { await effect.operation(dispatch) }
                }
            }
        }
    }

    /// Runs effects sequentially.
    public static func concatenate(_ effects: Self...) -> Self {
        Effect { dispatch in
            for effect in effects {
                await effect.operation(dispatch)
            }
        }
    }
}

// MARK: - Send

/// A callable wrapper that dispatches actions back to the store from within an effect.
public struct Send<Action: Sendable>: Sendable {
    private let _dispatch: @MainActor @Sendable (Action) -> Void

    init(_ dispatch: @escaping @MainActor @Sendable (Action) -> Void) {
        self._dispatch = dispatch
    }

    @MainActor
    public func callAsFunction(_ action: Action) {
        _dispatch(action)
    }
}

// MARK: - Reducer

/// The core protocol every feature implements.
///
/// A reducer is a pure function (plus effects):
///   (inout State, Action) -> Effect<Action>
///
/// The reducer must mutate state synchronously and return an Effect
/// for any work that is async or causes side effects.
public protocol Reducer<State, Action>: Sendable {
    /// State must be `Sendable` so it can cross actor boundaries safely.
    /// `Equatable` is intentionally not required here: under `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`
    /// the compiler synthesises `==` as `@MainActor`-isolated, which cannot satisfy a `Sendable`
    /// type-parameter constraint. Concrete feature `State` types still conform to `Equatable`
    /// individually, giving full equality support for tests and comparisons.
    associatedtype State: Sendable
    associatedtype Action: Sendable

    func reduce(into state: inout State, action: Action) -> Effect<Action>
}

// MARK: - Store

/// Manages a feature's state, processes actions, and executes effects.
///
/// Key TCA guarantee: **all state mutations happen synchronously on the main actor**.
/// Effects run asynchronously but dispatch new actions back through `send(_:)`.
///
/// The Store is the single object views hold a reference to.
/// Views read `store.state` and call `store.send(.someAction)`.
@Observable
public final class Store<R: Reducer> {
    public private(set) var state: R.State
    private let reducer: R
    private var activeTasks: [Task<Void, Never>] = []

    public init(initialState: R.State, reducer: R) {
        self.state = initialState
        self.reducer = reducer
    }

    /// Sends an action to the store, triggering a synchronous state mutation
    /// and scheduling any returned effects.
    public func send(_ action: R.Action) {
        let effect = reducer.reduce(into: &state, action: action)
        let dispatch: @MainActor @Sendable (R.Action) -> Void = { [weak self] nextAction in
            self?.send(nextAction)
        }
        let task = Task { @MainActor [weak self] in
            guard self != nil else { return }
            await effect.operation(dispatch)
        }
        activeTasks.append(task)
        activeTasks.removeAll { $0.isCancelled }
    }

    deinit {
        activeTasks.forEach { $0.cancel() }
    }
}

// MARK: - Scope

/// Produces a child store focused on a sub-state of a parent state.
/// This is how TCA composes features — each child feature only sees its own slice.
extension Store {
    func scope<ChildState: Equatable & Sendable, ChildAction: Sendable>(
        state keyPath: KeyPath<R.State, ChildState>,
        action transform: @escaping @Sendable (ChildAction) -> R.Action,
        reducer childReducer: some Reducer<ChildState, ChildAction>
    ) -> Store<ScopedReducer<R, ChildState, ChildAction>> {
        Store<ScopedReducer<R, ChildState, ChildAction>>(
            initialState: state[keyPath: keyPath],
            reducer: ScopedReducer(
                parent: self,
                stateKeyPath: keyPath,
                actionTransform: transform,
                childReducer: childReducer
            )
        )
    }
}

/// A reducer adapter that synchronises a child store with its parent.
public struct ScopedReducer<
    Parent: Reducer,
    ChildState: Equatable & Sendable,
    ChildAction: Sendable
>: Reducer {
    public typealias State = ChildState
    public typealias Action = ChildAction

    private let parent: Store<Parent>
    private let stateKeyPath: KeyPath<Parent.State, ChildState>
    private let actionTransform: @Sendable (ChildAction) -> Parent.Action
    private let childReducer: any Reducer<ChildState, ChildAction>

    init(
        parent: Store<Parent>,
        stateKeyPath: KeyPath<Parent.State, ChildState>,
        actionTransform: @escaping @Sendable (ChildAction) -> Parent.Action,
        childReducer: some Reducer<ChildState, ChildAction>
    ) {
        self.parent = parent
        self.stateKeyPath = stateKeyPath
        self.actionTransform = actionTransform
        self.childReducer = childReducer
    }

    public func reduce(into state: inout ChildState, action: ChildAction) -> Effect<ChildAction> {
        parent.send(actionTransform(action))
        return .none
    }
}
