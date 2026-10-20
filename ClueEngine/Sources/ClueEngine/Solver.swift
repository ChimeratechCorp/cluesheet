import Foundation

public enum Mark: Hashable {
    case unknown, has, lacks
}

/// The deduced clue sheet: for every card and every owner (each player, then
/// the envelope), whether that owner has it, lacks it, or is still unknown.
public struct Sheet: Hashable {
    public let cards: [Card]
    public let playerCount: Int
    fileprivate var marks: [Mark]
    /// Set when the entries can't all be true, e.g. a typo in a suggestion.
    public fileprivate(set) var contradiction: String?

    /// Owner index of the envelope (after all players).
    public var envelope: Int { playerCount }
    public var ownerCount: Int { playerCount + 1 }

    public func mark(card: String, owner: Int) -> Mark {
        guard let c = cards.firstIndex(where: { $0.name == card }) else { return .unknown }
        return marks[c * ownerCount + owner]
    }

    /// The envelope card for a category, once it is certain.
    public func solution(for category: Category) -> Card? {
        cards.first { $0.category == category && mark(card: $0.name, owner: envelope) == .has }
    }

    /// Cards in a category that could still be in the envelope.
    public func candidates(for category: Category) -> [Card] {
        cards.filter { $0.category == category && mark(card: $0.name, owner: envelope) != .lacks }
    }

    public var isSolved: Bool {
        contradiction == nil && Category.allCases.allSatisfy { solution(for: $0) != nil }
    }

    /// Who holds a card, once known (nil for unknown; `envelope` for the answer).
    public func holder(of card: String) -> Int? {
        (0..<ownerCount).first { mark(card: card, owner: $0) == .has }
    }
}

public enum Solver {
    struct Contradiction: Error {
        let reason: String
    }

    /// Deduce everything that follows from the game's entries.
    ///
    /// Rules are applied until nothing changes. With `lookahead`, each unknown
    /// cell is then tried both ways; a guess that leads to a contradiction
    /// proves the opposite.
    ///
    /// With `deduce` off, only facts entered directly are marked: cards
    /// known to be held, players who passed, and cards you were shown.
    public static func solve(_ game: Game, deduce: Bool = true, lookahead: Bool = true) -> Sheet {
        let cards = game.edition.cards
        var sheet = Sheet(cards: cards, playerCount: game.players.count,
                          marks: Array(repeating: .unknown, count: cards.count * (game.players.count + 1)))
        var engine = Engine(sheet: sheet, game: game)
        do {
            try engine.applyEvents()
            if deduce {
                try engine.propagate()
                if lookahead { try engine.lookahead() }
            }
            sheet = engine.sheet
        } catch let error as Contradiction {
            sheet = engine.sheet
            sheet.contradiction = error.reason
        } catch {
            sheet.contradiction = "\(error)"
        }
        return sheet
    }
}

/// "Owner holds at least one of these cards."
private struct AtLeastOne {
    let owner: Int
    let cards: [Int]
    let reason: String
}

/// "The envelope does not hold all of these cards."
private struct NotAll {
    let cards: [Int]
    let reason: String
}

private struct Engine {
    var sheet: Sheet
    let game: Game
    var atLeastOne: [AtLeastOne] = []
    var notAll: [NotAll] = []

    init(sheet: Sheet, game: Game) {
        self.sheet = sheet
        self.game = game
    }

    var cardCount: Int { sheet.cards.count }
    var owners: Int { sheet.ownerCount }

    func index(of name: String) throws -> Int {
        guard let i = sheet.cards.firstIndex(where: { $0.name == name }) else {
            throw Solver.Contradiction(reason: "Unknown card \(name).")
        }
        return i
    }

    func get(_ card: Int, _ owner: Int) -> Mark {
        sheet.marks[card * owners + owner]
    }

    /// Returns true when the cell changed.
    @discardableResult
    mutating func set(_ card: Int, _ owner: Int, _ mark: Mark, _ reason: String) throws -> Bool {
        let current = get(card, owner)
        if current == mark { return false }
        if current != .unknown {
            throw Solver.Contradiction(reason: reason)
        }
        sheet.marks[card * owners + owner] = mark
        return true
    }

    func ownerName(_ owner: Int) -> String {
        owner == sheet.envelope ? "The envelope" : game.players[owner].name
    }

    mutating func applyEvents() throws {
        let crossed = game.crossedOutCards()
        for event in game.events {
            switch event {
            case .hasCard(_, let player, let card):
                let c = try index(of: card)
                try set(c, player, .has, "\(ownerName(player)) can't both have and lack \(card).")
            case .lacksCard(_, let player, let card):
                let c = try index(of: card)
                try set(c, player, .lacks, "\(ownerName(player)) can't both have and lack \(card).")
            case .suggestion(let s):
                let cs = try s.cards.map { try index(of: $0) }
                for p in s.passers(playerCount: game.players.count) {
                    for c in cs {
                        try set(c, p, .lacks, "\(ownerName(p)) passed on \(sheet.cards[c].name) but is marked as having it.")
                    }
                }
                if let shower = s.shower {
                    if let shown = s.shownCard {
                        let c = try index(of: shown)
                        try set(c, shower, .has, "\(ownerName(shower)) showed \(shown) but is marked as lacking it.")
                    } else {
                        let remaining = try s.cards.filter { !(crossed[s.id]?.contains($0) ?? false) }
                            .map { try index(of: $0) }
                        atLeastOne.append(AtLeastOne(owner: shower, cards: remaining,
                            reason: "\(ownerName(shower)) showed a card for \(s.cards.joined(separator: ", ")) but can't hold any of them."))
                    }
                }
            case .wrongAccusation(_, _, let cards):
                let cs = try cards.map { try index(of: $0) }
                notAll.append(NotAll(cards: cs,
                    reason: "A wrong accusation of \(cards.joined(separator: ", ")) conflicts with the solution."))
            case .crossedOut:
                break // Applied to the suggestion's clause above.
            }
        }
    }

    /// Apply the rules until nothing changes.
    mutating func propagate() throws {
        var changed = true
        while changed {
            changed = false
            changed = try cardRules() || changed
            changed = try handRules() || changed
            changed = try envelopeRules() || changed
            changed = try clauseRules() || changed
        }
    }

    /// Each card has exactly one owner.
    mutating func cardRules() throws -> Bool {
        var changed = false
        for c in 0..<cardCount {
            let name = sheet.cards[c].name
            let holders = (0..<owners).filter { get(c, $0) == .has }
            if holders.count > 1 {
                throw Solver.Contradiction(reason: "\(name) is marked as held by both \(ownerName(holders[0])) and \(ownerName(holders[1])).")
            }
            if let h = holders.first {
                for o in 0..<owners where o != h {
                    changed = try set(c, o, .lacks, "\(name) can only have one owner.") || changed
                }
                continue
            }
            let open = (0..<owners).filter { get(c, $0) != .lacks }
            if open.isEmpty {
                throw Solver.Contradiction(reason: "Nobody can hold \(name).")
            }
            if open.count == 1 {
                changed = try set(c, open[0], .has, "\(name) must be somewhere.") || changed
            }
        }
        return changed
    }

    /// Each player holds exactly their hand size.
    mutating func handRules() throws -> Bool {
        var changed = false
        for (p, player) in game.players.enumerated() {
            let has = (0..<cardCount).filter { get($0, p) == .has }.count
            let unknown = (0..<cardCount).filter { get($0, p) == .unknown }
            if has > player.handSize {
                throw Solver.Contradiction(reason: "\(player.name) is marked with more than \(player.handSize) cards.")
            }
            if has + unknown.count < player.handSize {
                throw Solver.Contradiction(reason: "\(player.name) can't hold \(player.handSize) cards.")
            }
            if unknown.isEmpty { continue }
            if has == player.handSize {
                for c in unknown { try set(c, p, .lacks, "\(player.name)'s hand is full.") }
                changed = true
            } else if has + unknown.count == player.handSize {
                for c in unknown { try set(c, p, .has, "\(player.name)'s hand is full.") }
                changed = true
            }
        }
        return changed
    }

    /// The envelope holds exactly one card of each category.
    mutating func envelopeRules() throws -> Bool {
        var changed = false
        let e = sheet.envelope
        for category in Category.allCases {
            let inCategory = (0..<cardCount).filter { sheet.cards[$0].category == category }
            let has = inCategory.filter { get($0, e) == .has }
            if has.count > 1 {
                throw Solver.Contradiction(reason: "The envelope can only hold one \(category.rawValue).")
            }
            if has.count == 1 {
                for c in inCategory where c != has[0] {
                    changed = try set(c, e, .lacks, "The envelope holds one \(category.rawValue).") || changed
                }
                continue
            }
            let open = inCategory.filter { get($0, e) != .lacks }
            if open.isEmpty {
                throw Solver.Contradiction(reason: "No \(category.rawValue) is left for the envelope.")
            }
            if open.count == 1 {
                changed = try set(open[0], e, .has, "Only one \(category.rawValue) is left.") || changed
            }
        }
        return changed
    }

    mutating func clauseRules() throws -> Bool {
        var changed = false
        for clause in atLeastOne {
            if clause.cards.contains(where: { get($0, clause.owner) == .has }) { continue }
            let open = clause.cards.filter { get($0, clause.owner) != .lacks }
            if open.isEmpty { throw Solver.Contradiction(reason: clause.reason) }
            if open.count == 1 {
                changed = try set(open[0], clause.owner, .has, clause.reason) || changed
            }
        }
        let e = sheet.envelope
        for clause in notAll {
            if clause.cards.contains(where: { get($0, e) == .lacks }) { continue }
            let open = clause.cards.filter { get($0, e) != .has }
            if open.isEmpty { throw Solver.Contradiction(reason: clause.reason) }
            if open.count == 1 {
                changed = try set(open[0], e, .lacks, clause.reason) || changed
            }
        }
        return changed
    }

    /// Try each unknown cell both ways; if one way contradicts, the other is true.
    mutating func lookahead() throws {
        var changed = true
        while changed {
            changed = false
            for c in 0..<cardCount {
                for o in 0..<owners where get(c, o) == .unknown {
                    for guess in [Mark.has, .lacks] {
                        var trial = self
                        let holds: Bool
                        do {
                            try trial.set(c, o, guess, "")
                            try trial.propagate()
                            holds = true
                        } catch {
                            holds = false
                        }
                        if !holds {
                            try set(c, o, guess == .has ? .lacks : .has,
                                    "\(ownerName(o)) and \(sheet.cards[c].name) can't be either way.")
                            try propagate()
                            changed = true
                            break
                        }
                    }
                }
            }
        }
    }
}
