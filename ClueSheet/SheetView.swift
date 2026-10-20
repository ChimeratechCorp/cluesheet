import ClueEngine
import SwiftUI

/// The clue sheet: a row per card, a column per player plus the envelope.
struct SheetView: View {
    @Environment(GameStore.self) private var store

    @State private var showingSuggestion = false
    @State private var showingHistory = false
    @State private var confirmingNewGame = false
    @State private var editing: Cell?

    private let cellWidth: CGFloat = 34

    struct Cell: Identifiable {
        let card: String
        let owner: Int
        var id: String { "\(card)#\(owner)" }
    }

    var body: some View {
        if let game = store.game, let sheet = store.sheet {
            List {
                Section {
                    SolutionBanner(sheet: sheet)
                }
                if let problem = sheet.contradiction {
                    Section {
                        Label("Something doesn't add up: \(problem) Check the history for a mistyped entry.",
                              systemImage: "exclamationmark.octagon")
                            .foregroundStyle(.red)
                    }
                }
                ForEach(Category.allCases, id: \.self) { category in
                    Section {
                        ForEach(game.edition.cards(in: category)) { card in
                            row(card: card, game: game, sheet: sheet)
                        }
                    } header: {
                        header(title: category.title, game: game)
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Clue Sheet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("History", systemImage: "clock") { showingHistory = true }
                        Button("New game", systemImage: "arrow.counterclockwise", role: .destructive) {
                            confirmingNewGame = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Log turn", systemImage: "plus") { showingSuggestion = true }
                }
            }
            .sheet(isPresented: $showingSuggestion) {
                NavigationStack { SuggestionView(game: game) }
            }
            .sheet(isPresented: $showingHistory) {
                NavigationStack { HistoryView() }
            }
            .confirmationDialog("Start a new game? This game will be cleared.",
                                isPresented: $confirmingNewGame, titleVisibility: .visible) {
                Button("New game", role: .destructive) { store.newGame() }
            }
            .confirmationDialog(editTitle(game: game), isPresented: isEditing, titleVisibility: .visible,
                                presenting: editing) { cell in
                Button("Has it") {
                    store.add(.hasCard(player: cell.owner, card: cell.card))
                }
                Button("Doesn't have it") {
                    store.add(.lacksCard(player: cell.owner, card: cell.card))
                }
                if let entry = manualEntry(for: cell, game: game) {
                    Button("Clear my entry", role: .destructive) { store.remove(entry) }
                }
            }
        }
    }

    private func header(title: String, game: Game) -> some View {
        HStack(spacing: 0) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(game.players.indices, id: \.self) { i in
                Text(initials(game.players[i].name))
                    .fontWeight(i == game.me ? .bold : .regular)
                    .frame(width: cellWidth)
            }
            Image(systemName: "envelope.fill")
                .frame(width: cellWidth)
        }
        .font(.caption)
    }

    private func row(card: Card, game: Game, sheet: Sheet) -> some View {
        let solved = sheet.mark(card: card.name, owner: sheet.envelope) == .has
        let ruledOut = sheet.mark(card: card.name, owner: sheet.envelope) == .lacks
        return HStack(spacing: 0) {
            Text(card.name)
                .strikethrough(ruledOut)
                .foregroundStyle(ruledOut ? Color.secondary : Color.primary)
                .fontWeight(solved ? .bold : .regular)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(0..<sheet.ownerCount, id: \.self) { owner in
                MarkView(mark: sheet.mark(card: card.name, owner: owner))
                    .frame(width: cellWidth, height: 28)
                    .contentShape(Rectangle())
                    .onTapGesture { editing = Cell(card: card.name, owner: owner) }
            }
        }
    }

    private var isEditing: Binding<Bool> {
        Binding(get: { editing != nil }, set: { if !$0 { editing = nil } })
    }

    private func editTitle(game: Game) -> String {
        guard let editing else { return "" }
        let owner = editing.owner < game.players.count ? game.players[editing.owner].name : "The envelope"
        return "\(owner) and \(editing.card)"
    }

    /// The entry the player typed for this cell, if any, so it can be cleared.
    private func manualEntry(for cell: Cell, game: Game) -> Event? {
        game.events.last { event in
            switch event {
            case .hasCard(_, let p, let c), .lacksCard(_, let p, let c):
                return p == cell.owner && c == cell.card
            default:
                return false
            }
        }
    }

    private func initials(_ name: String) -> String {
        let words = name.split(separator: " ")
        if words.count > 1 { return words.prefix(2).compactMap(\.first).map(String.init).joined() }
        return String(name.prefix(2))
    }
}

struct MarkView: View {
    let mark: Mark

    var body: some View {
        switch mark {
        case .has:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .lacks:
            Image(systemName: "xmark").foregroundStyle(.secondary)
        case .unknown:
            Color.clear
        }
    }
}

struct SolutionBanner: View {
    let sheet: Sheet

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(sheet.isSolved ? "Solved! Make your accusation." : "Solution")
                .font(.headline)
                .foregroundStyle(sheet.isSolved ? Color.green : Color.primary)
            HStack(alignment: .top) {
                ForEach(Category.allCases, id: \.self) { category in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let card = sheet.solution(for: category) {
                            Text(card.name).bold()
                        } else {
                            Text("\(sheet.candidates(for: category).count) possible")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
