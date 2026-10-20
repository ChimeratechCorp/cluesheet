import Foundation

public struct Player: Hashable, Codable, Identifiable {
    public var id: UUID
    public var name: String
    public var handSize: Int

    public init(id: UUID = UUID(), name: String, handSize: Int) {
        self.id = id
        self.name = name
        self.handSize = handSize
    }
}

/// One turn's suggestion and how the table answered it.
///
/// Players are asked in turn order, starting after the suggester, until one
/// of them shows a card. Everyone asked before that player had none of the
/// three cards, so only the shower needs to be entered.
public struct Suggestion: Hashable, Codable, Identifiable {
    public var id: UUID
    /// Index into `Game.players`.
    public var suggester: Int
    /// Card names: one suspect, one weapon, one room.
    public var cards: [String]
    /// Who showed a card, or nil when nobody could.
    public var shower: Int?
    /// The card shown, when the person tracking saw it (they made the suggestion).
    public var shownCard: String?

    public init(id: UUID = UUID(), suggester: Int, cards: [String], shower: Int?, shownCard: String? = nil) {
        self.id = id
        self.suggester = suggester
        self.cards = cards
        self.shower = shower
        self.shownCard = shownCard
    }

    /// Players asked who could not show any of the three cards.
    public func passers(playerCount: Int) -> [Int] {
        var result: [Int] = []
        var p = (suggester + 1) % playerCount
        while p != suggester && p != shower {
            result.append(p)
            p = (p + 1) % playerCount
        }
        return result
    }
}

/// Everything entered during a game. The sheet is always recomputed from
/// this log, so deleting an event is a full undo.
public enum Event: Hashable, Codable, Identifiable {
    /// A player is known to hold a card (dealt to you, or seen some other way).
    case hasCard(id: UUID = UUID(), player: Int, card: String)
    /// A player is known not to hold a card.
    case lacksCard(id: UUID = UUID(), player: Int, card: String)
    case suggestion(Suggestion)
    /// A player accused these three cards and was wrong, so the envelope
    /// does not hold all three of them.
    case wrongAccusation(id: UUID = UUID(), player: Int, cards: [String])
    /// A turn number crossed out of a square: on that turn, the player who
    /// showed a card didn't show this one.
    case crossedOut(id: UUID = UUID(), suggestion: UUID, card: String)

    public var id: UUID {
        switch self {
        case .hasCard(let id, _, _), .lacksCard(let id, _, _), .wrongAccusation(let id, _, _),
             .crossedOut(let id, _, _):
            return id
        case .suggestion(let s):
            return s.id
        }
    }
}

public struct Game: Hashable, Codable {
    public var edition: Edition
    public var players: [Player]
    /// Index of the person using the app.
    public var me: Int
    public var events: [Event]

    public init(edition: Edition = .classic, players: [Player], me: Int, myCards: [String]) {
        self.edition = edition
        self.players = players
        self.me = me
        self.events = myCards.map { .hasCard(player: me, card: $0) }
    }

    /// Hand sizes for `count` players: cards are dealt round-robin, so the
    /// first players dealt to get one extra when the deck doesn't split evenly.
    public static func defaultHandSizes(playerCount count: Int, edition: Edition = .classic) -> [Int] {
        guard count > 0 else { return [] }
        let base = edition.dealtCount / count
        let extra = edition.dealtCount % count
        return (0..<count).map { base + ($0 < extra ? 1 : 0) }
    }

    /// Problems that stop a game from being started, if any.
    public static func setupProblems(edition: Edition = .classic, players: [Player], me: Int, myCards: [String]) -> [String] {
        var problems: [String] = []
        if players.count < 2 { problems.append("Add at least two players.") }
        let total = players.reduce(0) { $0 + $1.handSize }
        if total != edition.dealtCount {
            problems.append("Hand sizes add up to \(total); they should add up to \(edition.dealtCount).")
        }
        if players.indices.contains(me), myCards.count != players[me].handSize {
            problems.append("Pick exactly \(players[me].handSize) cards for your hand (\(myCards.count) picked).")
        }
        if players.contains(where: { $0.name.trimmingCharacters(in: .whitespaces).isEmpty }) {
            problems.append("Every player needs a name.")
        }
        return problems
    }
}

/// One square on the sheet.
public struct CellKey: Hashable {
    public let card: String
    public let owner: Int

    public init(card: String, owner: Int) {
        self.card = card
        self.owner = owner
    }
}

extension Game {
    /// Turn numbers for the suggestions in the log, counting from 1.
    public func turnNumbers() -> [UUID: Int] {
        var numbers: [UUID: Int] = [:]
        for event in events {
            if case .suggestion(let s) = event { numbers[s.id] = numbers.count + 1 }
        }
        return numbers
    }

    /// Cards crossed out of each suggestion's pencil marks.
    public func crossedOutCards() -> [UUID: Set<String>] {
        var result: [UUID: Set<String>] = [:]
        for event in events {
            if case .crossedOut(_, let suggestion, let card) = event { result[suggestion, default: []].insert(card) }
        }
        return result
    }

    /// The crossed-out entry for a suggestion and card, if there is one.
    public func crossOut(suggestion: UUID, card: String) -> Event? {
        events.first {
            if case .crossedOut(_, suggestion, card) = $0 { return true }
            return false
        }
    }

    /// Pencil marks, like the small numbers written on a paper sheet: for
    /// each square, the turns in which that player showed a card that might
    /// have been this one (or, when you saw it, was this one).
    public func pencilMarks() -> [CellKey: [PencilMark]] {
        let turns = turnNumbers()
        let crossed = crossedOutCards()
        var marks: [CellKey: [PencilMark]] = [:]
        for event in events {
            guard case .suggestion(let s) = event, let shower = s.shower, let turn = turns[s.id] else { continue }
            for card in s.shownCard.map({ [$0] }) ?? s.cards {
                let mark = PencilMark(turn: turn, suggestion: s.id, card: card,
                                      isCrossedOut: crossed[s.id]?.contains(card) ?? false,
                                      isSeen: s.shownCard != nil)
                marks[CellKey(card: card, owner: shower), default: []].append(mark)
            }
        }
        return marks
    }
}

/// A turn number written in a square.
public struct PencilMark: Hashable {
    public let turn: Int
    public let suggestion: UUID
    public let card: String
    /// Crossed out by the player: this wasn't the card shown that turn.
    public let isCrossedOut: Bool
    /// You saw this card, so there's nothing to cross out.
    public let isSeen: Bool
}
