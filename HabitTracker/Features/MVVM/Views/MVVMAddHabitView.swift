import SwiftUI

/// MVVM Architecture — add habit sheet.
///
/// Binds to an `AddHabitViewModel`. The ViewModel owns validation state
/// and orchestrates the create use case. The view owns only layout.
struct MVVMAddHabitView: View {
    @State var viewModel: AddHabitViewModel
    @Environment(\.dismiss) private var dismiss
    var onSave: () -> Void

    init(viewModel: AddHabitViewModel, onSave: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Habit") {
                    TextField("Name", text: $viewModel.name)
                    TextField("Description (optional)", text: $viewModel.habitDescription, axis: .vertical)
                        .lineLimit(3...)
                }
                Section("Frequency") {
                    Toggle("Weekly (specific days)", isOn: $viewModel.isWeekly)
                    if viewModel.isWeekly {
                        MVVMWeekdaySelectorView(
                            selectedDays: viewModel.selectedDays,
                            onToggle: viewModel.toggleDay
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
                    Button("Cancel", action: cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", action: save)
                        .disabled(!viewModel.isValid || viewModel.isSaving)
                }
            }
            .alert(
                "Error",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.clearError() } }
                )
            ) {
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .onChange(of: viewModel.didSave) { _, saved in
                if saved {
                    onSave()
                    dismiss()
                }
            }
        }
    }

    private func save() {
        Task { await viewModel.saveHabit() }
    }

    private func cancel() {
        dismiss()
    }
}

struct MVVMWeekdaySelectorView: View {
    let selectedDays: Set<Weekday>
    let onToggle: (Weekday) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            ForEach(Weekday.allCases) { day in
                MVVMWeekdayCell(day: day, isSelected: selectedDays.contains(day))
                    .onTapGesture { onToggle(day) }
            }
        }
    }
}

struct MVVMWeekdayCell: View {
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
