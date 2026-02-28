import Foundation

/// Represents a standard deck of 52 playing cards
struct Deck {
    /// The cards currently in the deck
    private var cards: [Card]
    
    /// The original full deck of cards for resetting
    private let fullDeck: [Card]
    
    /// The number of cards remaining in the deck
    var count: Int {
        return cards.count
    }
    
    /// Creates a new deck with all 52 standard playing cards
    init() {
        var newCards: [Card] = []
        
        // Create all 52 unique cards (one of each suit/rank combination)
        for suit in Suit.allCases {
            for rank in Rank.allCases {
                newCards.append(Card(suit: suit, rank: rank))
            }
        }
        
        self.cards = newCards
        self.fullDeck = newCards
    }
    
    /// Shuffles the cards in the deck using Swift's built-in randomization
    mutating func shuffle() {
        cards.shuffle()
    }
    
    /// Removes and returns the top card from the deck
    /// - Returns: The top card from the deck
    /// - Throws: An error if the deck is empty
    mutating func deal() throws -> Card {
        guard !cards.isEmpty else {
            throw DeckError.emptyDeck
        }
        
        return cards.removeFirst()
    }
    
    /// Restores the deck to its original 52 cards
    mutating func reset() {
        cards = fullDeck
    }
}

/// Errors that can occur when using the Deck
enum DeckError: Error, LocalizedError {
    case emptyDeck
    
    var errorDescription: String? {
        switch self {
        case .emptyDeck:
            return "Cannot deal from an empty deck"
        }
    }
}