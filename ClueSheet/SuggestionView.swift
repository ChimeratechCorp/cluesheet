import ClueEngine
import SwiftUI

/// Log one turn: a suggestion and who showed a card, or a wrong accusation.
struct SuggestionView: View {
    let game: Game

    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    enum Kind: String, CaseIterable {
        case suggestion = "Suggestion"
        case accusation = "Wrong accusation"
    }

    @State private var kind = Kind.suggestion
    @State private var suggester = 0
    @State private var suspect = ""
    @State private var weapon = ""
    @State private var room = ""
    /// -1 means nobody showed a card.
    @State private var shower = -1
    @State private var shownCard = ""

    private var picked: [String] { [suspect, weapon, room] }
    private var isComplete: Bool { picked.allSatisfy { !$0.isEmpty } }
    private var iSuggested: Bool { suggester == game.me }

    var body: some View {
        Form {
            Picker("Type", selection: $kind) {
                ForEach(Kind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            Section {
                Picker(kind == .suggestion ? "Suggested by" : "Accused by", selection: $suggester) {
                    ForEach(game.players.indices, id: \.self) { Text(game.players[$0].name).tag($0) }
                }
                cardPicker("Suspect", category: .suspect, selection: $suspect)
                cardPicker("Weapon", category: .weapon, selection: $weapon)
                cardPicker("Room", category: .room, selection: $room)
            }

            if kind == .suggestion {
                Section {
                    Picker("Card shown by", selection: $shower) {
                        Text("Nobody").tag(-1)
                        ForEach(responders, id: \.self) { Text(game.players[$0].name).tag($0) }
                    }
                    if iSuggested && shower >= 0 {
                        Picker("Card I was shown", selection: $shownCard) {
                            Text("Choose…").tag("")
                            ForEach(picked.filter { !$0.isEmpty }, id: \.self) { Text($0).tag($0) }
                        }
                    }
                } footer: {
                    Text("Players asked before the one who showed a card are recorded as having none of the three.")
                }
            } else {
                Section {
                    Text("A wrong accusation means the envelope doesn't hold all three of these cards.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .paperBackground()
        .navigationTitle("Log turn")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(!canSave)
            }
        }
        .onChange(of: suggester) { shower = -1 }
        .onAppear { suggester = game.me }
    }

    /// Everyone but the suggester, in the order they're asked.
    private var responders: [Int] {
        let n = game.players.count
        return (1..<n).map { (suggester + $0) % n }
    }

    private var canSave: Bool {
        guard isComplete else { return false }
        if kind == .suggestion && iSuggested && shower >= 0 && shower != game.me {
            return !shownCard.isEmpty
        }
        return true
    }

    private func cardPicker(_ title: String, category: ClueEngine.Category, selection: Binding<String>) -> some View {
        Picker(title, selection: selection) {
            Text("Choose…").tag("")
            ForEach(game.edition.cards(in: category)) { Text($0.name).tag($0.name) }
        }
    }

    private func save() {
        switch kind {
        case .suggestion:
            let showed = shower >= 0 ? shower : nil
            let card = iSuggested && showed != nil && picked.contains(shownCard) ? shownCard : nil
            store.add(.suggestion(Suggestion(suggester: suggester, cards: picked, shower: showed, shownCard: card)))
        case .accusation:
            store.add(.wrongAccusation(player: suggester, cards: picked))
        }
        dismiss()
    }
}
