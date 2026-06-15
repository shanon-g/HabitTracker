import SwiftUI

/// TCA Architecture — add habit sheet.
///
/// Reads from `store.state.habitList.addHabitState`.
/// All mutations go through `store.send(.habitList(.addHabit(.someAction)))`.
/// No local @State — all state lives in the store's value tree.
struct TCAAddHabitView: View {
    let store: Store<AppFeature>
    @Environment(\.dismiss) private var dismiss

    private var state: AddHabitFeature.State {
        store.state.habitList.addHabitState ?? AddHabitFeature.State()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Habit") {
                    TextField("Name", text: Binding(
                        get: { state.name },
                        set: { store.send(.habitList(.addHabit(.nameChanged($0)))) }
                    ))
                    TextField(
                        "Description (optional)",
                        text: Binding(
                            get: { state.habitDescription },
                            set: { store.send(.habitList(.addHabit(.descriptionChanged($0)))) }
                        ),
                        axis: .vertical
                    )
                    .lineLimit(3...)
                }
                Section("Frequency") {
                    Toggle(
                        "Weekly (specific days)",
                        isOn: Binding(
                            get: { state.isWeekly },
                            set: { store.send(.habitList(.addHabit(.isWeeklyToggled($0)))) }
                        )
                    )
                    if state.isWeekly {
                        TCAWeekdaySelectorView(
                            selectedDays: state.selectedDays,
                            onToggle: { store.send(.habitList(.addHabit(.dayToggled($0)))) }
                        )
                    }
                }
            }
            .navigationTitle("New Habit")
#if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        store.send(.habitList(.addHabit(.cancelButtonTapped)))
                        store.send(.habitList(.addHabitDismissed))
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        store.send(.habitList(.addHabit(.saveButtonTapped)))
                    }
                    .disabled(!state.isValid || state.isSaving)
                }
            }
            .alert(
                "Error",
                isPresented: Binding(
                    get: { state.errorMessage != nil },
                    set: { _ in }
                )
            ) {
            } message: {
                Text(state.errorMessage ?? "")
            }
        }
    }
}

struct TCAWeekdaySelectorView: View {
    let selectedDays: Set<Weekday>
    let onToggle: (Weekday) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            ForEach(Weekday.allCases) { day in
                TCAWeekdayCell(day: day, isSelected: selectedDays.contains(day))
                    .onTapGesture { onToggle(day) }
            }
        }
    }
}

struct TCAWeekdayCell: View {
    let day: Weekday
    let isSelected: Bool

    var body: some View {
        Text(day.shortName.prefix(1))
            .font(.caption.bold())
            .frame(width: 32, height: 32)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.15))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Circle())
    }
}
