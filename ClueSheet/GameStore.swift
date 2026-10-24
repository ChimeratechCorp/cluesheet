import ClueEngine
import Foundation
import Observation

/// Holds the current game, keeps the deduced sheet in step with it, and
/// saves it so a game survives the app being closed.
@Observable
final class GameStore {
    var game: Game? {
        didSet {
            recompute()
            save()
        }
    }
    private(set) var sheet: Sheet?

    /// Free-form notes for this game. Kept apart from `game` so typing
    /// doesn't re-run the solver on every keystroke.
    var notes: String = "" {
        didSet { try? notes.write(to: notesURL, atomically: true, encoding: .utf8) }
    }

    /// Card names the player has crossed out or circled by hand. Kept apart
    /// from `game` because they're the player's own notes, not evidence.
    var nameMarks: [String: NameMark] = [:] {
        didSet {
            if let data = try? JSONEncoder().encode(nameMarks) {
                try? data.write(to: nameMarksURL, options: .atomic)
            }
        }
    }

    /// When on, the sheet fills in everything that follows from your
    /// entries. When off, it shows only what you entered, like paper.
    var helperOn: Bool = UserDefaults.standard.object(forKey: "helperOn") == nil
        || UserDefaults.standard.bool(forKey: "helperOn") {
        didSet {
            UserDefaults.standard.set(helperOn, forKey: "helperOn")
            recompute()
        }
    }

    private let saveURL = URL.documentsDirectory.appending(path: "game.json")
    private let notesURL = URL.documentsDirectory.appending(path: "notes.txt")
    private let nameMarksURL = URL.documentsDirectory.appending(path: "nameMarks.json")

    init() {
        if ProcessInfo.processInfo.arguments.contains(DemoGame.launchArgument) {
            game = DemoGame.game
            notes = DemoGame.notes
            nameMarks = DemoGame.nameMarks
            recompute()
            return
        }
        if let data = try? Data(contentsOf: saveURL) {
            game = try? JSONDecoder().decode(Game.self, from: data)
        }
        notes = (try? String(contentsOf: notesURL, encoding: .utf8)) ?? ""
        if let data = try? Data(contentsOf: nameMarksURL) {
            nameMarks = (try? JSONDecoder().decode([String: NameMark].self, from: data)) ?? [:]
        }
        recompute()
    }

    func add(_ event: Event) {
        game?.events.append(event)
    }

    func remove(_ event: Event) {
        game?.events.removeAll { $0.id == event.id }
    }

    func newGame() {
        game = nil
        notes = ""
        nameMarks = [:]
    }

    /// Cross out, then circle, then clear a card name.
    func cycleMark(for card: String) {
        nameMarks[card] = NameMark.next(after: nameMarks[card])
    }

    private func recompute() {
        sheet = game.map { Solver.solve($0, deduce: helperOn) }
    }

    private func save() {
        if let game, let data = try? JSONEncoder().encode(game) {
            try? data.write(to: saveURL, options: .atomic)
        } else if game == nil {
            try? FileManager.default.removeItem(at: saveURL)
        }
    }
}
