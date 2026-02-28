import Foundation

/// Represents the suit of a playing card
enum Suit: CaseIterable {
    case hearts, diamonds, clubs, spades
    
    /// Single character representation of the suit
    var symbol: String {
        switch self {
        case .hearts: return "H"
        case .diamonds: return "D"
        case .clubs: return "C"
        case .spades: return "S"
        }
    }
}

/// Represents the rank of a playing card
enum Rank: CaseIterable {
    case two, three, four, five, six, seven, eight, nine, ten, jack, queen, king, ace
    
    /// Numeric value of the rank (2-14 where Ace is 14)
    var value: Int {
        switch self {
        case .two: return 2
        case .three: return 3
        case .four: return 4
        case .five: return 5
        case .six: return 6
        case .seven: return 7
        case .eight: return 8
        case .nine: return 9
        case .ten: return 10
        case .jack: return 11
        case .queen: return 12
        case .king: return 13
        case .ace: return 14
        }
    }
    
    /// Single character representation of the rank
    var symbol: String {
        switch self {
        case .ten: return "T"
        case .jack: return "J"
        case .queen: return "Q"
        case .king: return "K"
        case .ace: return "A"
        default: return String(self.value)
        }
    }
}

/// Represents a playing card with a suit and rank
struct Card: Equatable, Hashable {
    let suit: Suit
    let rank: Rank
    
    /// Creates a card with the specified suit and rank
    /// - Parameters:
    ///   - suit: The suit of the card
    ///   - rank: The rank of the card
    init(suit: Suit, rank: Rank) {
        self.suit = suit
        self.rank = rank
    }
    
    /// Returns the image name for the card (e.g., "AH" for Ace of Hearts)
    var imageName: String {
        // Special case for 10 - use "10" instead of "T" to match image asset names
        if rank == .ten {
            return "10\(suit.symbol)"
        }
        return "\(rank.symbol)\(suit.symbol)"
    }
    
    /// Checks if two cards are equal
    /// - Parameters:
    ///   - lhs: The left-hand side card
    ///   - rhs: The right-hand side card
    /// - Returns: True if the cards have the same suit and rank
    static func == (lhs: Card, rhs: Card) -> Bool {
        return lhs.suit == rhs.suit && lhs.rank == rhs.rank
    }
}