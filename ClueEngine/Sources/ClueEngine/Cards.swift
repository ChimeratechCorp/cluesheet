import Foundation

/// The three kinds of card in Clue. The envelope holds exactly one of each.
public enum Category: String, Codable, CaseIterable, Hashable {
    case suspect, weapon, room

    public var title: String {
        switch self {
        case .suspect: return "Suspects"
        case .weapon: return "Weapons"
        case .room: return "Rooms"
        }
    }
}

public struct Card: Hashable, Codable, Identifiable {
    public let name: String
    public let category: Category

    public var id: String { name }

    public init(_ name: String, _ category: Category) {
        self.name = name
        self.category = category
    }
}

/// The set of cards in play. Different printings of Clue rename cards,
/// so the list is data rather than hard-coded cases.
public struct Edition: Hashable, Codable {
    public var name: String
    public var suspects: [String]
    public var weapons: [String]
    public var rooms: [String]

    public init(name: String, suspects: [String], weapons: [String], rooms: [String]) {
        self.name = name
        self.suspects = suspects
        self.weapons = weapons
        self.rooms = rooms
    }

    /// The classic North American set: 6 suspects, 6 weapons, 9 rooms.
    public static let classic = Edition(
        name: "Classic",
        suspects: ["Miss Scarlet", "Col. Mustard", "Mrs. White", "Mr. Green", "Mrs. Peacock", "Prof. Plum"],
        weapons: ["Candlestick", "Knife", "Lead Pipe", "Revolver", "Rope", "Wrench"],
        rooms: ["Kitchen", "Ballroom", "Conservatory", "Dining Room", "Billiard Room",
                "Library", "Lounge", "Hall", "Study"]
    )

    public var cards: [Card] {
        suspects.map { Card($0, .suspect) } + weapons.map { Card($0, .weapon) } + rooms.map { Card($0, .room) }
    }

    public func cards(in category: Category) -> [Card] {
        cards.filter { $0.category == category }
    }

    /// Cards dealt to players: everything except the three in the envelope.
    public var dealtCount: Int { cards.count - Category.allCases.count }
}
