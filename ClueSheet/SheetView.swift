import ClueEngine
import SwiftUI

/// The clue sheet: a row per card, a column per player plus the envelope.
struct SheetView: View {
    @Environment(GameStore.self) private var store

    @State private var showingSuggestion = false
    @State private var showingHistory = false
    @State private var showingNotes = false
    @State private var confirmingNewGame = false
    @State private var editing: Cell?

    /// Screens at least this wide split in two at the middle: notes on the
    /// left half, the sheet on the right. The iPhone Duo's inner screen is
    /// 1878 px (626 pt) wide unfolded; its outer screen is 466 pt, so folded
    /// it shows the sheet alone.
    private static let wideLayoutWidth: CGFloat = 600

    /// Tall enough for a mark plus a line of pencil-mark turn numbers.
    private static let rowHeight: CGFloat = 44

    struct Cell: Identifiable {
        let card: String
        let owner: Int
        var id: String { "\(card)#\(owner)" }
    }

    var body: some View {
        if let game = store.game, let sheet = store.sheet {
            GeometryReader { geo in
                let wide = geo.size.width >= Self.wideLayoutWidth
                let sheetWidth = wide ? geo.size.width / 2 : geo.size.width
                HStack(spacing: 0) {
                    if wide {
                        SidePanel()
                            .frame(width: geo.size.width / 2 - 1)
                        Divider()
                    }
                    sheetList(game: game, sheet: sheet,
                              cellWidth: Self.cellWidth(for: sheetWidth, owners: sheet.ownerCount))
                }
            }
            .navigationTitle("Clue Sheet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Toggle(isOn: helperOn) {
                            Label("Helper", systemImage: "wand.and.stars")
                        }
                        Button("Notes", systemImage: "note.text") { showingNotes = true }
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
            .sheet(isPresented: $showingNotes) {
                NavigationStack { NotesView() }
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

    private func sheetList(game: Game, sheet: Sheet, cellWidth: CGFloat) -> some View {
        let pencilMarks = game.pencilMarks()
        return List {
            Section {
                SolutionBanner(sheet: sheet, helperOn: store.helperOn)
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
                        row(card: card, game: game, sheet: sheet, pencilMarks: pencilMarks, cellWidth: cellWidth)
                    }
                } header: {
                    header(title: category.title, game: game, cellWidth: cellWidth)
                }
            }
        }
        .listStyle(.plain)
    }

    /// Squares grow with the screen, within reason, so an unfolded screen
    /// gets bigger tap targets rather than just a wider name column.
    private static func cellWidth(for width: CGFloat, owners: Int) -> CGFloat {
        // Half of an unfolded iPhone Duo is about 313 pt, so the name column
        // shrinks before the squares do.
        let nameColumn: CGFloat = width >= 500 ? 180 : width < 360 ? 92 : 120
        return min(64, max(30, (width - nameColumn - 32) / CGFloat(owners)))
    }

    private func header(title: String, game: Game, cellWidth: CGFloat) -> some View {
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

    private func row(card: Card, game: Game, sheet: Sheet, pencilMarks: [CellKey: [Int]],
                     cellWidth: CGFloat) -> some View {
        let solved = sheet.mark(card: card.name, owner: sheet.envelope) == .has
        let ruledOut = sheet.mark(card: card.name, owner: sheet.envelope) == .lacks
        return HStack(spacing: 0) {
            Text(card.name)
                .strikethrough(ruledOut)
                .foregroundStyle(ruledOut ? Color.secondary : Color.primary)
                .fontWeight(solved ? .bold : .regular)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(0..<sheet.ownerCount, id: \.self) { owner in
                SquareView(mark: sheet.mark(card: card.name, owner: owner),
                           turns: pencilMarks[CellKey(card: card.name, owner: owner)] ?? [])
                    .frame(width: cellWidth, height: Self.rowHeight)
                    .contentShape(Rectangle())
                    .onTapGesture { editing = Cell(card: card.name, owner: owner) }
            }
        }
    }

    private var helperOn: Binding<Bool> {
        Binding(get: { store.helperOn }, set: { store.helperOn = $0 })
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

/// One square: the deduced mark in the middle, and in the top corner the
/// turns when this player showed a card that might have been this one.
struct SquareView: View {
    let mark: Mark
    let turns: [Int]

    private var showsTurns: Bool { !turns.isEmpty && mark != .lacks }

    var body: some View {
        ZStack(alignment: .topLeading) {
            MarkView(mark: mark)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, showsTurns ? 12 : 0)
            if showsTurns {
                Text(turns.map(String.init).joined(separator: " "))
                    .font(.system(size: 10, weight: .medium).monospacedDigit())
                    .foregroundStyle(mark == .has ? Color.secondary : Color.accentColor)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 2)
                    .padding(.top, 1)
            }
        }
        .overlay(Rectangle().stroke(Color.secondary.opacity(0.25), lineWidth: 0.5))
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
    let helperOn: Bool

    var body: some View {
        if helperOn {
            solution
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Label("Helper is off", systemImage: "pencil")
                    .font(.headline)
                Text("The sheet shows only what you've entered. Turn the Helper on in the ⋯ menu to fill in X's and find the solution automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }

    private var solution: some View {
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
