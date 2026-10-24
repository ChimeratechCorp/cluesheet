import ClueEngine
import SwiftUI

/// The clue sheet: a row per card, a column per player.
struct SheetView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var showingSuggestion = false
    @State private var showingHistory = false
    @State private var showingNotes = false
    @State private var confirmingNewGame = false
    @State private var editing: Cell?

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
                // Regular width splits the screen in two at the middle, along
                // the fold: notes on the left half, the sheet on the right.
                // That's the iPhone Duo unfolded (either way up); folded, its
                // outer screen is compact like any iPhone and shows the sheet
                // alone. Apple's iOS 27.1 guidance is to go by size class, not
                // screen width or the hinge.
                let wide = sizeClass == .regular
                let sheetWidth = wide ? geo.size.width / 2 : geo.size.width
                HStack(spacing: 0) {
                    if wide {
                        SidePanel()
                            .frame(width: geo.size.width / 2 - 1)
                        Rectangle()
                            .fill(Theme.rule)
                            .frame(width: 1)
                            .ignoresSafeArea()
                    }
                    sheetList(game: game, sheet: sheet,
                              cellWidth: Self.cellWidth(for: sheetWidth, owners: game.players.count))
                }
            }
            .background(Theme.paper.ignoresSafeArea())
            .navigationTitle("Clue Sheet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Label("Clue Sheet", systemImage: "magnifyingglass")
                        .labelStyle(.titleAndIcon)
                        .font(.headline)
                        .fontDesign(.serif)
                        .foregroundStyle(Theme.ink)
                }
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
                ForEach(game.pencilMarks()[CellKey(card: cell.card, owner: cell.owner)] ?? [], id: \.self) { mark in
                    if mark.isCrossedOut, let entry = game.crossOut(suggestion: mark.suggestion, card: mark.card) {
                        Button("Put back turn \(mark.turn)") { store.remove(entry) }
                    } else if !mark.isSeen {
                        Button("Cross out turn \(mark.turn)") {
                            store.add(.crossedOut(suggestion: mark.suggestion, card: mark.card))
                        }
                    }
                }
            }
        }
    }

    private func sheetList(game: Game, sheet: Sheet, cellWidth: CGFloat) -> some View {
        let pencilMarks = game.pencilMarks()
        return ScrollView {
            LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                if let problem = sheet.contradiction {
                    Label("Something doesn't add up: \(problem) Check the history for a mistyped entry.",
                          systemImage: "exclamationmark.octagon.fill")
                        .font(.subheadline)
                        .foregroundStyle(Theme.accent)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                        .padding(.bottom, 12)
                }
                ForEach(Category.allCases, id: \.self) { category in
                    let cards = game.edition.cards(in: category)
                    Section {
                        ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                            row(card: card, game: game, sheet: sheet, pencilMarks: pencilMarks,
                                cellWidth: cellWidth, index: index, isLast: index == cards.count - 1)
                        }
                        Color.clear.frame(height: 12)
                    } header: {
                        header(category: category, game: game, cellWidth: cellWidth)
                    }
                }
            }
            .padding(.horizontal, Self.margin)
            .padding(.vertical, 8)
        }
        .fontDesign(.serif)
    }

    /// Space between the grid and the edge of the screen (or the fold).
    private static let margin: CGFloat = 12
    /// Space before each card name, inside the grid.
    private static let nameInset: CGFloat = 10

    /// Squares grow with the screen, within reason, so an unfolded screen
    /// gets bigger tap targets rather than just a wider name column.
    private static func cellWidth(for width: CGFloat, owners: Int) -> CGFloat {
        // Half of an unfolded iPhone Duo is about 334 pt held upright, so the
        // name column shrinks before the squares do.
        let nameColumn: CGFloat = width >= 500 ? 180 : width < 360 ? 92 : 120
        return min(64, max(30, (width - nameColumn - 2 * margin - nameInset) / CGFloat(owners)))
    }

    private func header(category: ClueEngine.Category, game: Game, cellWidth: CGFloat) -> some View {
        let tint = Theme.tint(for: category)
        return HStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: Theme.icon(for: category))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(tint, in: Circle())
                Text(category.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.leading, Self.nameInset - 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(game.players.indices, id: \.self) { i in
                let isMe = i == game.me
                Text(initials(game.players[i].name))
                    .font(.caption.weight(isMe ? .bold : .medium))
                    .fontDesign(.default)
                    .foregroundStyle(isMe ? Color.white : Theme.fadedInk)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isMe ? Theme.accent : Color.clear, in: Capsule())
                    .frame(width: cellWidth)
            }
        }
        .frame(height: 40)
        .background(Theme.card)
        .overlay(alignment: .bottom) {
            Rectangle().fill(tint).frame(height: 2)
        }
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 12, topTrailingRadius: 12))
    }

    private func row(card: Card, game: Game, sheet: Sheet, pencilMarks: [CellKey: [PencilMark]],
                     cellWidth: CGFloat, index: Int, isLast: Bool) -> some View {
        let corners = UnevenRoundedRectangle(bottomLeadingRadius: isLast ? 12 : 0,
                                             bottomTrailingRadius: isLast ? 12 : 0)
        return HStack(spacing: 0) {
            // Tap the name to cross it out or circle it, like on the paper
            // pad. It's the player's call; the sheet never does it for them.
            Text(card.name)
                .foregroundStyle(store.nameMarks[card.name] == .crossedOut ? Theme.fadedInk : Theme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .overlay {
                    if let mark = store.nameMarks[card.name] {
                        NameMarkView(mark: mark, seed: card.name)
                            .id(mark)
                    }
                }
                .padding(.leading, Self.nameInset + 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { store.cycleMark(for: card.name) }
                .accessibilityAddTraits(.isButton)
                .accessibilityValue(nameMarkDescription(store.nameMarks[card.name]))
            ForEach(game.players.indices, id: \.self) { owner in
                SquareView(mark: sheet.mark(card: card.name, owner: owner),
                           turns: (pencilMarks[CellKey(card: card.name, owner: owner)] ?? [])
                               .filter { !$0.isCrossedOut }.map(\.turn))
                    .frame(width: cellWidth, height: Self.rowHeight)
                    .contentShape(Rectangle())
                    .onTapGesture { editing = Cell(card: card.name, owner: owner) }
            }
        }
        .frame(height: Self.rowHeight)
        .background(index.isMultiple(of: 2) ? Theme.card : Theme.stripe)
        .clipShape(corners)
        .overlay(corners.stroke(Theme.rule, lineWidth: isLast ? 0.5 : 0))
    }

    private func nameMarkDescription(_ mark: NameMark?) -> String {
        switch mark {
        case .crossedOut: return "Crossed out"
        case .circled: return "Circled"
        case nil: return ""
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
                // Pencil marks: small, slanted, in red ink.
                Text(turns.map(String.init).joined(separator: " "))
                    .font(.system(size: 11, weight: .semibold, design: .serif).italic().monospacedDigit())
                    .foregroundStyle(mark == .has ? Theme.fadedInk : Theme.accent)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 3)
                    .padding(.top, 2)
            }
        }
        .background(background)
        .overlay(Rectangle().stroke(Theme.rule, lineWidth: 0.5))
    }

    private var background: Color {
        mark == .has ? Theme.has.opacity(0.14) : .clear
    }
}

struct MarkView: View {
    let mark: Mark

    var body: some View {
        switch mark {
        case .has:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Theme.has)
        case .lacks:
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.fadedInk)
        case .unknown:
            Color.clear
        }
    }
}
