import ClueEngine

/// A game partway through, for screenshots and trying the app out.
/// Launch with the `-demoGame` argument to load it instead of the saved game.
///
/// The hidden deal: the envelope is Col. Mustard, Wrench, Library.
/// Ann: Miss Scarlet, Knife, Ballroom, Dining Room, Hall.
/// Bo: Mrs. White, Lead Pipe, Rope, Billiard Room.
/// Cy: Mrs. Peacock, Prof. Plum, Lounge, Study.
enum DemoGame {
    static let launchArgument = "-demoGame"

    static var game: Game {
        let players = [
            Player(name: "Me", handSize: 5),
            Player(name: "Ann", handSize: 5),
            Player(name: "Bo", handSize: 4),
            Player(name: "Cy", handSize: 4),
        ]
        var game = Game(players: players, me: 0,
                        myCards: ["Mr. Green", "Candlestick", "Revolver", "Kitchen", "Conservatory"])
        let turns = [
            Suggestion(suggester: 0, cards: ["Miss Scarlet", "Wrench", "Ballroom"], shower: 1, shownCard: "Ballroom"),
            Suggestion(suggester: 1, cards: ["Col. Mustard", "Rope", "Library"], shower: 2),
            Suggestion(suggester: 2, cards: ["Prof. Plum", "Knife", "Lounge"], shower: 3),
            Suggestion(suggester: 3, cards: ["Mrs. White", "Wrench", "Hall"], shower: 1),
            Suggestion(suggester: 0, cards: ["Col. Mustard", "Rope", "Study"], shower: 2, shownCard: "Rope"),
            Suggestion(suggester: 1, cards: ["Mrs. Peacock", "Lead Pipe", "Library"], shower: 2),
            Suggestion(suggester: 0, cards: ["Col. Mustard", "Lead Pipe", "Library"], shower: 2, shownCard: "Lead Pipe"),
            Suggestion(suggester: 2, cards: ["Col. Mustard", "Wrench", "Dining Room"], shower: 1),
        ]
        game.events += turns.map { .suggestion($0) }
        return game
    }

    static let notes = """
        Ann keeps asking about the Library. Does she need it too?

        Bo showed me Rope, then Lead Pipe.

        Nobody has shown Mustard yet.

        Next turn: Mustard, Wrench, Library?
        """
}
