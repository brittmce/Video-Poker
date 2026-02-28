import Foundation

/// Represents the stage of the game
enum GameStage {
    case deal      // Initial cards dealt, player choosing holds
    case draw      // Player has chosen holds, drawing new cards
    case result    // Hand result displayed
}

/// Represents a final outcome type with probability and contribution
struct OutcomeBreak {
    let name: String
    let probability: Double
    let contribution: Double
}

/// Represents the state of the game
struct GameState {
    /// The current hand of 5 cards
    var currentHand: [Card]
    
    /// The original hand dealt to the player (before drawing)
    let originalHand: [Card]
    
    /// Boolean array indicating which cards are held (true) or not held (false)
    var heldCards: [Bool]
    
    /// The current stage of the game
    var stage: GameStage
    
    /// The optimal cards to hold for maximum expected value (based on original hand)
    var optimalHolds: [Bool]
    
    /// The expected value of the optimal play (based on original hand)
    var optimalEV: Double
    
    /// The expected value of the player's chosen play (based on original hand)
    var playerEV: Double

    /// Breakdown of possible final hands for the player's chosen hold
    var outcomeBreakdown: [OutcomeBreak]

    /// Breakdown of possible final hands for the optimal hold (only computed when needed)
    var optimalOutcomeBreakdown: [OutcomeBreak]

    /// Cached EVs for evaluated hold masks (0-31). Only includes holds that were computed.
    var holdEVs: [Int: Double]

    /// Whether optimal strategy has been computed for the current hand
    var optimalReady: Bool
    
    /// Reference to player statistics
    let statistics: PlayerStatistics
    
    /// Creates a new game state
    /// - Parameters:
    ///   - currentHand: The current hand of 5 cards
    ///   - originalHand: The original hand dealt to the player (defaults to currentHand)
    ///   - heldCards: Boolean array indicating which cards are held
    ///   - stage: The current stage of the game
    ///   - optimalHolds: The optimal cards to hold for maximum expected value
    ///   - optimalEV: The expected value of the optimal play
    ///   - playerEV: The expected value of the player's chosen play
    ///   - statistics: Reference to player statistics
    init(
        currentHand: [Card],
        originalHand: [Card]? = nil,
        heldCards: [Bool] = Array(repeating: false, count: 5),
        stage: GameStage = .deal,
        optimalHolds: [Bool],
        optimalEV: Double,
        playerEV: Double = 0.0,
        statistics: PlayerStatistics
    ) {
        guard currentHand.count == 5 else {
            fatalError("A poker hand must contain exactly 5 cards")
        }
        
        guard heldCards.count == 5 else {
            fatalError("Held cards array must contain exactly 5 boolean values")
        }
        
        guard optimalHolds.count == 5 else {
            fatalError("Optimal holds array must contain exactly 5 boolean values")
        }
        
        self.currentHand = currentHand
        self.originalHand = originalHand ?? currentHand
        self.heldCards = heldCards
        self.stage = stage
        self.optimalHolds = optimalHolds
        self.optimalEV = optimalEV
        self.playerEV = playerEV
        self.outcomeBreakdown = []
        self.optimalOutcomeBreakdown = []
        self.holdEVs = [:]
        self.optimalReady = false
        self.statistics = statistics
    }
    
    /// Toggles the held state of a card at the specified index
    /// - Parameter index: The index of the card to toggle
    mutating func toggleHold(for index: Int) {
        guard index >= 0 && index < heldCards.count else {
            fatalError("Index out of bounds")
        }
        
        // Can only toggle holds during the deal stage
        guard stage == .deal else {
            return
        }
        
        heldCards[index].toggle()
    }
}
