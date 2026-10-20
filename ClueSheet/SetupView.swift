import ClueEngine
import SwiftUI

struct SetupView: View {
    @Environment(GameStore.self) private var store

    @State private var players: [Player] = Self.defaultPlayers(count: 4)
    @State private var me = 0
    @State private var myCards: Set<String> = []
    private let edition = Edition.classic

    var body: some View {
        Form {
            Section {
                Stepper("\(players.count) players", value: playerCount, in: 3...6)
            } footer: {
                Text("List players in turn order, going clockwise.")
            }

            Section("Players and hand sizes") {
                ForEach($players) { $player in
                    HStack {
                        TextField("Name", text: $player.name)
                        Stepper("\(player.handSize) cards", value: $player.handSize, in: 0...edition.dealtCount)
                            .fixedSize()
                    }
                }
                Picker("I am", selection: $me) {
                    ForEach(players.indices, id: \.self) { i in
                        Text(players[i].name).tag(i)
                    }
                }
            }

            ForEach(Category.allCases, id: \.self) { category in
                Section("My \(category.title.lowercased())") {
                    ForEach(edition.cards(in: category)) { card in
                        Toggle(card.name, isOn: binding(for: card.name))
                    }
                }
            }

            Section {
                ForEach(problems, id: \.self) { problem in
                    Label(problem, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
                Button("Start game") {
                    store.game = Game(edition: edition, players: players, me: me, myCards: Array(myCards))
                }
                .disabled(!problems.isEmpty)
            }
        }
        .navigationTitle("New game")
    }

    private var problems: [String] {
        Game.setupProblems(edition: edition, players: players, me: me, myCards: Array(myCards))
    }

    private var playerCount: Binding<Int> {
        Binding(
            get: { players.count },
            set: { count in
                var updated = Self.defaultPlayers(count: count)
                for i in updated.indices where i < players.count {
                    updated[i].name = players[i].name
                }
                players = updated
                me = min(me, count - 1)
            }
        )
    }

    private func binding(for card: String) -> Binding<Bool> {
        Binding(
            get: { myCards.contains(card) },
            set: { on in
                if on { myCards.insert(card) } else { myCards.remove(card) }
            }
        )
    }

    private static func defaultPlayers(count: Int) -> [Player] {
        Game.defaultHandSizes(playerCount: count).enumerated().map { i, size in
            Player(name: i == 0 ? "Me" : "Player \(i + 1)", handSize: size)
        }
    }
}
