import XCTest
@testable import ClueEngine

final class SolverTests: XCTestCase {
    let edition = Edition.classic

    func makeGame(handSizes: [Int] = [6, 6, 6], me: Int = 0, myCards: [String]) -> Game {
        let players = handSizes.enumerated().map { Player(name: "P\($0.offset)", handSize: $0.element) }
        return Game(edition: edition, players: players, me: me, myCards: myCards)
    }

    let myHand = ["Miss Scarlet", "Knife", "Kitchen", "Ballroom", "Hall", "Rope"]

    func testDefaultHandSizes() {
        XCTAssertEqual(Game.defaultHandSizes(playerCount: 3), [6, 6, 6])
        XCTAssertEqual(Game.defaultHandSizes(playerCount: 4), [5, 5, 4, 4])
        XCTAssertEqual(Game.defaultHandSizes(playerCount: 5), [4, 4, 4, 3, 3])
        XCTAssertEqual(Game.defaultHandSizes(playerCount: 6), [3, 3, 3, 3, 3, 3])
    }

    func testSetupProblems() {
        let players = [Player(name: "A", handSize: 6), Player(name: "B", handSize: 6), Player(name: "C", handSize: 5)]
        XCTAssertFalse(Game.setupProblems(players: players, me: 0, myCards: myHand).isEmpty)
        var fixed = players
        fixed[2].handSize = 6
        XCTAssertEqual(Game.setupProblems(players: fixed, me: 0, myCards: myHand), [])
    }

    func testMyHandIsMarked() {
        let sheet = Solver.solve(makeGame(myCards: myHand))
        XCTAssertNil(sheet.contradiction)
        XCTAssertEqual(sheet.mark(card: "Knife", owner: 0), .has)
        XCTAssertEqual(sheet.mark(card: "Knife", owner: 1), .lacks)
        XCTAssertEqual(sheet.mark(card: "Knife", owner: sheet.envelope), .lacks)
        // My hand is full, so everything else is not mine.
        XCTAssertEqual(sheet.mark(card: "Wrench", owner: 0), .lacks)
    }

    func testPassersLackAllThreeCards() {
        var game = makeGame(handSizes: [5, 5, 4, 4], myCards: Array(myHand.prefix(5)))
        // P1 suggests; P2 passes, P3 shows.
        game.events.append(.suggestion(Suggestion(suggester: 1, cards: ["Prof. Plum", "Wrench", "Study"], shower: 3)))
        let sheet = Solver.solve(game)
        for card in ["Prof. Plum", "Wrench", "Study"] {
            XCTAssertEqual(sheet.mark(card: card, owner: 2), .lacks, card)
        }
        XCTAssertEqual(sheet.mark(card: "Prof. Plum", owner: 3), .unknown)
    }

    func testShowerWithOnlyOnePossibleCard() {
        var game = makeGame(myCards: myHand)
        game.events.append(.lacksCard(player: 2, card: "Prof. Plum"))
        game.events.append(.lacksCard(player: 2, card: "Wrench"))
        // P1 suggests, P2 shows something: it has to be the Study.
        game.events.append(.suggestion(Suggestion(suggester: 1, cards: ["Prof. Plum", "Wrench", "Study"], shower: 2)))
        let sheet = Solver.solve(game)
        XCTAssertEqual(sheet.mark(card: "Study", owner: 2), .has)
        XCTAssertEqual(sheet.holder(of: "Study"), 2)
    }

    func testNobodyShowsAndISuggestedMyOwnCards() {
        var game = makeGame(myCards: myHand)
        // I suggest with my own room; nobody can show, so the suspect and weapon are the answer.
        game.events.append(.suggestion(Suggestion(suggester: 0, cards: ["Prof. Plum", "Wrench", "Kitchen"], shower: nil)))
        let sheet = Solver.solve(game)
        XCTAssertEqual(sheet.solution(for: .suspect)?.name, "Prof. Plum")
        XCTAssertEqual(sheet.solution(for: .weapon)?.name, "Wrench")
        XCTAssertNil(sheet.solution(for: .room))
    }

    func testWrongAccusation() {
        var game = makeGame(myCards: myHand)
        game.events.append(.hasCard(player: 1, card: "Mr. Green"))
        // Pin suspect and weapon down by eliminating everything else.
        for s in ["Col. Mustard", "Mrs. White", "Mrs. Peacock"] { game.events.append(.hasCard(player: 2, card: s)) }
        for w in ["Candlestick", "Lead Pipe", "Revolver"] { game.events.append(.hasCard(player: 1, card: w)) }
        var sheet = Solver.solve(game)
        XCTAssertEqual(sheet.solution(for: .suspect)?.name, "Prof. Plum")
        XCTAssertEqual(sheet.solution(for: .weapon)?.name, "Wrench")
        game.events.append(.wrongAccusation(player: 1, cards: ["Prof. Plum", "Wrench", "Study"]))
        sheet = Solver.solve(game)
        XCTAssertEqual(sheet.mark(card: "Study", owner: sheet.envelope), .lacks)
    }

    func testWithoutDeductionOnlyEntriesAreMarked() {
        var game = makeGame(myCards: myHand)
        game.events.append(.suggestion(Suggestion(suggester: 1, cards: ["Prof. Plum", "Wrench", "Study"], shower: 0)))
        let sheet = Solver.solve(game, deduce: false)
        XCTAssertEqual(sheet.mark(card: "Knife", owner: 0), .has)
        XCTAssertEqual(sheet.mark(card: "Knife", owner: 1), .unknown, "no one-owner-per-card rule")
        XCTAssertEqual(sheet.mark(card: "Wrench", owner: 0), .unknown, "no full-hand rule")
        XCTAssertEqual(Solver.solve(game).mark(card: "Wrench", owner: 0), .lacks)
    }

    func testPencilMarksNumberTheTurns() {
        var game = makeGame(myCards: myHand)
        game.events.append(.suggestion(Suggestion(suggester: 1, cards: ["Prof. Plum", "Wrench", "Study"], shower: 2)))
        game.events.append(.hasCard(player: 1, card: "Lounge"))
        game.events.append(.suggestion(Suggestion(suggester: 0, cards: ["Prof. Plum", "Lead Pipe", "Lounge"], shower: 2, shownCard: "Lead Pipe")))
        game.events.append(.suggestion(Suggestion(suggester: 2, cards: ["Prof. Plum", "Wrench", "Library"], shower: 0)))
        let marks = game.pencilMarks()
        XCTAssertEqual(marks[CellKey(card: "Prof. Plum", owner: 2)], [1])
        XCTAssertEqual(marks[CellKey(card: "Wrench", owner: 2)], [1])
        XCTAssertEqual(marks[CellKey(card: "Lead Pipe", owner: 2)], [2])
        XCTAssertNil(marks[CellKey(card: "Lounge", owner: 2)], "only the card I saw is marked")
        XCTAssertEqual(marks[CellKey(card: "Wrench", owner: 0)], [3])
    }

    func testContradictionIsReported() {
        var game = makeGame(myCards: myHand)
        game.events.append(.hasCard(player: 1, card: "Wrench"))
        game.events.append(.hasCard(player: 2, card: "Wrench"))
        let sheet = Solver.solve(game)
        XCTAssertNotNil(sheet.contradiction)
        XCTAssertFalse(sheet.isSolved)
    }

    func testCodableRoundTrip() throws {
        var game = makeGame(myCards: myHand)
        game.events.append(.suggestion(Suggestion(suggester: 0, cards: ["Prof. Plum", "Wrench", "Study"], shower: 1, shownCard: "Study")))
        game.events.append(.wrongAccusation(player: 2, cards: ["Mr. Green", "Rope", "Lounge"]))
        let data = try JSONEncoder().encode(game)
        XCTAssertEqual(try JSONDecoder().decode(Game.self, from: data), game)
    }

    /// Play many random games with truthful answers and check the solver
    /// never contradicts itself or marks anything that isn't true.
    func testRandomGamesAreSoundAndUsuallySolve() {
        var rng = SeededGenerator(seed: 42)
        var solvedCount = 0
        let games = 20
        for _ in 0..<games {
            let playerCount = Int.random(in: 3...6, using: &rng)
            let truth = Deal.random(edition: edition, playerCount: playerCount, using: &rng)
            let sizes = Game.defaultHandSizes(playerCount: playerCount)
            let players = sizes.enumerated().map { Player(name: "P\($0.offset)", handSize: $0.element) }
            var game = Game(edition: edition, players: players, me: 0, myCards: truth.hands[0])
            var sheet = Solver.solve(game)
            for turn in 0..<60 where !sheet.isSolved {
                let suggester = turn % playerCount
                let picks = Category.allCases.map { edition.cards(in: $0).randomElement(using: &rng)!.name }
                var shower: Int?
                var shown: String?
                var p = (suggester + 1) % playerCount
                while p != suggester {
                    let matching = picks.filter { truth.hands[p].contains($0) }
                    if let card = matching.randomElement(using: &rng) {
                        shower = p
                        if suggester == 0 { shown = card }
                        break
                    }
                    p = (p + 1) % playerCount
                }
                game.events.append(.suggestion(Suggestion(suggester: suggester, cards: picks, shower: shower, shownCard: shown)))
                sheet = Solver.solve(game)
                XCTAssertNil(sheet.contradiction, sheet.contradiction ?? "")
                assertSound(sheet, truth: truth)
            }
            if sheet.isSolved {
                solvedCount += 1
                for category in Category.allCases {
                    XCTAssertTrue(truth.envelope.contains(sheet.solution(for: category)!.name))
                }
            }
        }
        XCTAssertGreaterThan(solvedCount, games / 4)
    }

    func assertSound(_ sheet: Sheet, truth: Deal, file: StaticString = #filePath, line: UInt = #line) {
        for card in sheet.cards {
            for owner in 0..<sheet.ownerCount {
                let holds = owner == sheet.envelope ? truth.envelope.contains(card.name) : truth.hands[owner].contains(card.name)
                switch sheet.mark(card: card.name, owner: owner) {
                case .has: XCTAssertTrue(holds, "\(card.name) wrongly marked for \(owner)", file: file, line: line)
                case .lacks: XCTAssertFalse(holds, "\(card.name) wrongly crossed off for \(owner)", file: file, line: line)
                case .unknown: break
                }
            }
        }
    }
}

struct Deal {
    var hands: [[String]]
    var envelope: [String]

    static func random<G: RandomNumberGenerator>(edition: Edition, playerCount: Int, using rng: inout G) -> Deal {
        let envelope = Category.allCases.map { edition.cards(in: $0).randomElement(using: &rng)!.name }
        let rest = edition.cards.map(\.name).filter { !envelope.contains($0) }.shuffled(using: &rng)
        var hands = Array(repeating: [String](), count: playerCount)
        for (i, card) in rest.enumerated() { hands[i % playerCount].append(card) }
        return Deal(hands: hands, envelope: envelope)
    }
}

/// Deterministic generator so the random-game test is repeatable.
struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
