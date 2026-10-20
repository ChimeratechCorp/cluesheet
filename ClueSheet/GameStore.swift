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

    private let saveURL = URL.documentsDirectory.appending(path: "game.json")

    init() {
        if let data = try? Data(contentsOf: saveURL) {
            game = try? JSONDecoder().decode(Game.self, from: data)
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
    }

    private func recompute() {
        sheet = game.map { Solver.solve($0) }
    }

    private func save() {
        if let game, let data = try? JSONEncoder().encode(game) {
            try? data.write(to: saveURL, options: .atomic)
        } else if game == nil {
            try? FileManager.default.removeItem(at: saveURL)
        }
    }
}
