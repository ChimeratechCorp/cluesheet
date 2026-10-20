import SwiftUI

/// A blank notepad for anything the sheet doesn't capture: who seems to be
/// chasing which room, hunches, reminders.
struct NotesView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// True when shown on the left half of a wide screen rather than as a pop-up.
    var embedded = false

    var body: some View {
        if embedded {
            editor
        } else {
            editor
                .navigationTitle("Notes")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }

    private var editor: some View {
        @Bindable var store = store
        return TextEditor(text: $store.notes)
            .padding(.horizontal, 12)
            .overlay(alignment: .topLeading) {
                if store.notes.isEmpty {
                    Text("Notes")
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 17)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
            }
    }
}

/// Left half of the unfolded screen: notes, with the history a tap away.
struct SidePanel: View {
    enum Tab: String, CaseIterable {
        case notes = "Notes"
        case history = "History"
    }

    @State private var tab = Tab.notes

    var body: some View {
        VStack(spacing: 0) {
            Picker("Show", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(12)
            switch tab {
            case .notes: NotesView(embedded: true)
            case .history: HistoryView(embedded: true)
            }
        }
    }
}
