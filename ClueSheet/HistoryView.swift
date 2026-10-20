import ClueEngine
import SwiftUI

/// Everything entered so far. Swipe to delete a mistake; the sheet is
/// recalculated from what's left.
struct HistoryView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if let game = store.game {
                ForEach(game.events.reversed()) { event in
                    Text(describe(event, game: game))
                        .swipeActions {
                            Button("Delete", role: .destructive) { store.remove(event) }
                        }
                }
            }
        }
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
            guard let shower = s.shower else {
                return "\(name(s.suggester)) suggested \(cards). Nobody showed a card."
            }
            let shown = s.shownCard.map { " (\($0))" } ?? ""
            return "\(name(s.suggester)) suggested \(cards). \(name(shower)) showed a card\(shown)."
        case .wrongAccusation(_, let p, let cards):
            return "\(name(p)) wrongly accused \(cards.joined(separator: ", "))."
        }
    }
}
