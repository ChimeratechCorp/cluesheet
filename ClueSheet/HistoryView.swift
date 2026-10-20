import ClueEngine
import SwiftUI

/// Everything entered so far. Swipe to delete a mistake; the sheet is
/// recalculated from what's left.
struct HistoryView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    /// True when shown beside the sheet on a wide screen rather than as a pop-up.
    var embedded = false

    var body: some View {
        if embedded {
            list
        } else {
            standalone
        }
    }

    private var list: some View {
        List {
            Section {
                if let game = store.game {
                    ForEach(game.events.reversed()) { event in
                        Text(describe(event, game: game))
                            .swipeActions {
                                Button("Delete", role: .destructive) { store.remove(event) }
                            }
                    }
                }
            } header: {
                if embedded { Text("History") }
            }
        }
    }

    private var standalone: some View {
        list
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
    }

    private func describe(_ event: Event, game: Game) -> String {
        func name(_ i: Int) -> String {
            i < game.players.count ? game.players[i].name : "The envelope"
        }
        switch event {
        case .hasCard(_, let p, let card):
            return "\(name(p)) has \(card)"
        case .lacksCard(_, let p, let card):
            return "\(name(p)) doesn't have \(card)"
        case .suggestion(let s):
            let cards = s.cards.joined(separator: ", ")
            let turn = game.turnNumbers()[s.id].map { "Turn \($0): " } ?? ""
            guard let shower = s.shower else {
                return "\(turn)\(name(s.suggester)) suggested \(cards). Nobody showed a card."
            }
            let shown = s.shownCard.map { " (\($0))" } ?? ""
            return "\(turn)\(name(s.suggester)) suggested \(cards). \(name(shower)) showed a card\(shown)."
        case .wrongAccusation(_, let p, let cards):
            return "\(name(p)) wrongly accused \(cards.joined(separator: ", "))."
        }
    }
}
