import Foundation
import Combine

/// Manages the game state and logic for the video poker strategy trainer
///
/// This class handles the core game flow including dealing cards, managing
/// card holds, drawing replacement cards, calculating expected values,
/// determining optimal strategy, and updating player statistics.
///
/// This class has been optimized to perform heavy calculations on background
/// threads to prevent UI blocking, with proper thread safety and error handling.
class GameManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// The current state of the game
    @Published var gameState: GameState?
    
    /// Player statistics tracking performance
    @Published var statistics: PlayerStatistics

    /// Active paytable used for EV and strategy calculations.
    @Published var selectedPaytable: Paytable
    
    /// Whether the player's choice was correct (for feedback display)
    @Published var isCorrectChoice: Bool = false
    
    /// Whether to show the feedback overlay
    @Published var showFeedback: Bool = false
    
    /// Whether to show the optimal strategy (when player is incorrect)
    @Published var showOptimalStrategy: Bool = false
    
    /// Whether calculations are in progress
    @Published var isCalculating: Bool = false

    var handsStatValue: String {
        guard case .training = mode, !trainingHands.isEmpty else {
            return "\(statistics.handsPlayed)"
        }
        guard gameState != nil else { return "0/\(trainingHands.count)" }
        let count = trainingHands.count
        let current = ((trainingCursor - 1 + count) % count) + 1
        return "\(current)/\(count)"
    }
    
    // MARK: - Private Properties
    
    /// The deck of cards used in the game
    private var deck: Deck
    
    /// Calculator for determining expected values and optimal strategy
    private let evCalculator: ExpectedValueCalculator
    private let mode: PlayMode
    private let trainingDifficulty: TrainingDifficulty?
    private var trainingHands: [[Card]] = []
    private var trainingOrder: [Int] = []
    private var trainingCursor: Int = 0
    private let allCards: [Card]
    
    // MARK: - Initialization
    
    /// Creates a new game manager with default values
    private struct PersistedTrainingState: Codable {
        let order: [Int]
        let cursor: Int
    }

    init(mode: PlayMode = .justPlay) {
        let savedPaytableID = UserDefaults.standard.string(forKey: Paytable.selectionStorageKey)
        let startingPaytable = Paytable.byID(savedPaytableID)
        self.mode = mode
        if case .training(let level) = mode {
            self.trainingDifficulty = level
        } else {
            self.trainingDifficulty = nil
        }
        self.allCards = {
            var cards: [Card] = []
            for suit in Suit.allCases {
                for rank in Rank.allCases {
                    cards.append(Card(suit: suit, rank: rank))
                }
            }
            return cards
        }()

        // Initialize all stored properties first
        self.deck = Deck()
        self.selectedPaytable = startingPaytable
        self.evCalculator = ExpectedValueCalculator(paytable: startingPaytable)
        self.statistics = PlayerStatistics()
        if case .training(let level) = mode {
            self.trainingHands = TrainingHandLibrary.hands(for: level)
            self.loadOrCreateTrainingOrder(for: level)
        }
        
        // Initialize gameState to nil initially - no cards dealt automatically
        self.gameState = nil
    }

    func setPaytable(_ paytable: Paytable) {
        guard selectedPaytable != paytable else { return }
        selectedPaytable = paytable
        UserDefaults.standard.set(paytable.id, forKey: Paytable.selectionStorageKey)
        evCalculator.setPaytable(paytable)
        if gameState != nil {
            startNewHand()
        }
    }
    
    /// Ensures the deck is properly shuffled before dealing
    private func prepareDeck() {
        deck.reset()
        deck.shuffle()
    }
    
    // MARK: - Game Flow Management
    
    /// Starts a new hand by dealing 5 cards and calculating optimal strategy
    ///
    /// This method performs the heavy calculation of optimal strategy on a
    /// background thread to prevent UI blocking. It updates the UI on the
    /// main thread and includes proper error handling.
    func startNewHand() {
        let hand: [Card]
        if case .training = mode {
            hand = nextTrainingHand()
        } else {
            // Reset and shuffle the deck
            prepareDeck()
            // Deal initial hand
            hand = dealHand()
        }
        // Immediately show the dealt hand without waiting for calculations
        DispatchQueue.main.async {
            self.isCalculating = false
            self.showOptimalStrategy = false
            self.gameState = GameState(
                currentHand: hand,
                originalHand: hand,
                heldCards: Array(repeating: false, count: 5),
                stage: .deal,
                optimalHolds: Array(repeating: false, count: 5),
                optimalEV: 0.0,
                playerEV: 0.0,
                statistics: self.statistics
            )
        }
        
        // Perform calculations asynchronously
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Calculate optimal strategy and cache EVs
                let optimalResult = try self.evCalculator.analyzeHand(for: hand)
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    self.gameState?.optimalHolds = optimalResult.hold
                    self.gameState?.optimalEV = optimalResult.expectedValue
                    self.gameState?.holdEVs = optimalResult.evByMask
                    self.gameState?.optimalReady = true
                }
            } catch {
                print("Error calculating optimal strategy: \(error)")
                DispatchQueue.main.async {
                    self.gameState?.optimalHolds = Array(repeating: false, count: 5)
                    self.gameState?.optimalEV = 0.0
                    self.gameState?.holdEVs = [:]
                    self.gameState?.optimalReady = false
                }
            }
        }
    }
    
    /// Processes the draw phase by replacing unheld cards and evaluating the result
    ///
    /// This method performs the heavy calculation of player's expected value on a
    /// background thread to prevent UI blocking. It updates the UI on the main
    /// thread and includes proper error handling.
    func processDraw() {
        // Validate we're in the correct stage
        guard let gameState = self.gameState else {
            print("Error: Game state not initialized")
            return
        }
        
        guard gameState.stage == .draw else {
            print("Error: Cannot process draw when not in draw stage")
            return
        }
        
        // Set calculating state
        self.isCalculating = true
        
        // Perform calculations asynchronously
        // Capture the initial hand and holds for distribution calculations
        let initialHand = gameState.currentHand
        let held = gameState.heldCards
        let optimalReady = gameState.optimalReady
        let cachedHoldEVs = gameState.holdEVs

        DispatchQueue.global(qos: .userInitiated).async {
            var optimalHolds = gameState.optimalHolds
            var optimalEV = gameState.optimalEV
            var holdEVs = cachedHoldEVs

            // If optimal strategy wasn't ready yet, compute it now before scoring.
            if !optimalReady {
                do {
                    let optimalResult = try self.evCalculator.analyzeHand(for: initialHand)
                    optimalHolds = optimalResult.hold
                    optimalEV = optimalResult.expectedValue
                    holdEVs = optimalResult.evByMask
                } catch {
                    print("Error calculating optimal strategy on draw: \(error)")
                }
            }

            // Draw replacement cards for unheld positions
            let newHand = self.drawReplacementCards(for: initialHand, holding: held)

            // Calculate player's expected value based on their hold choices
            let playerEV = self.calculatePlayerEV(for: initialHand, heldCards: held, cachedEVs: holdEVs)
            
            // Treat equal-EV selections as correct (multiple optimal holds can tie).
            let evTolerance = 0.0001
            let isCorrect = playerEV + evTolerance >= optimalEV

            // Update UI on main thread
            DispatchQueue.main.async {
                self.isCalculating = false

                // Update the hand with the newly drawn cards
                self.gameState?.currentHand = newHand
                self.gameState?.playerEV = playerEV
                if !optimalReady {
                    self.gameState?.optimalHolds = optimalHolds
                    self.gameState?.optimalEV = optimalEV
                    self.gameState?.holdEVs = holdEVs
                    self.gameState?.optimalReady = true
                }

                // Determine if player's choice was correct
                self.isCorrectChoice = isCorrect
                self.showOptimalStrategy = !isCorrect  // Show optimal strategy when player is wrong
                self.showFeedback = true

                // Update statistics
                self.statistics.recordHand(
                    playerEV: playerEV,
                    optimalEV: optimalEV,
                    isCorrect: isCorrect
                )

                // Update game state to result stage
                self.gameState?.stage = .result

                // Hide feedback after appropriate time (longer when showing optimal strategy)
                let feedbackDuration: TimeInterval = self.showOptimalStrategy ? 4 : 2
                DispatchQueue.main.asyncAfter(deadline: .now() + feedbackDuration) {
                    self.showFeedback = false
                    if self.showOptimalStrategy {
                        self.showOptimalStrategy = false
                    }
                }
            }

            // Compute breakdowns after the UI is updated to keep the flow snappy.
            DispatchQueue.global(qos: .userInitiated).async {
                var userBreakdown: [OutcomeBreak] = []
                do {
                    let dist = try self.evCalculator.distributionFor(hand: initialHand, heldCards: held, betMultiplier: 5)
                    userBreakdown = dist.map { OutcomeBreak(name: $0.name, probability: $0.probability, contribution: $0.contribution) }
                } catch {
                    print("Error computing distribution: \(error)")
                }
                
                var optimalBreakdown: [OutcomeBreak] = []
                if !isCorrect {
                    do {
                        let dist = try self.evCalculator.distributionFor(hand: initialHand, heldCards: optimalHolds, betMultiplier: 5)
                        optimalBreakdown = dist.map { OutcomeBreak(name: $0.name, probability: $0.probability, contribution: $0.contribution) }
                    } catch {
                        print("Error computing optimal distribution: \(error)")
                    }
                }
                
                DispatchQueue.main.async {
                    self.gameState?.outcomeBreakdown = userBreakdown
                    if !isCorrect {
                        self.gameState?.optimalOutcomeBreakdown = optimalBreakdown
                    } else {
                        self.gameState?.optimalOutcomeBreakdown = []
                    }
                }
            }
        }
    }
    
    /// Resets the current hand to allow for a new round
    func resetHand() {
        startNewHand()
    }
    
    // MARK: - User Interaction Handling
    
    /// Toggles the held state of a card at the specified index
    /// - Parameter index: The index of the card to toggle hold status
    func toggleHold(for index: Int) {
        // Can only toggle holds during the deal stage
        guard let gameState = self.gameState else {
            print("Error: Game state not initialized")
            return
        }
        
        guard gameState.stage == .deal else { return }
        
        // Toggle the held state for the specified card
        self.gameState?.toggleHold(for: index)
    }
    
    /// Handles the action button press (Deal/Draw)
    func handleActionButtonPress() {
        guard let gameState = self.gameState else {
            print("Error: Game state not initialized")
            return
        }
        
        switch gameState.stage {
        case .deal:
            // Immediately perform the draw when the action button is pressed
            // during the deal stage. Set stage to .draw and process the draw.
            self.gameState?.stage = .draw
            self.processDraw()
            
        case .draw:
            // Process the draw and show results
            processDraw()
            
        case .result:
            // Start a new hand
            startNewHand()
        }
    }
    
    // MARK: - Core Game Logic
    
    /// Deals a 5-card hand from the deck
    /// - Returns: An array of 5 cards
    /// - Throws: DeckError if the deck is empty
    private func dealHand() -> [Card] {
        var hand: [Card] = []
        
        do {
            // Ensure we have enough cards in the deck
            if deck.count < 5 {
                print("Warning: Deck has less than 5 cards (\(deck.count)), reshuffling")
                prepareDeck()
            }
            
            for _ in 0..<5 {
                let card = try deck.deal()
                hand.append(card)
            }
        } catch {
            print("Error dealing hand: \(error)")
            // Fallback to a sample hand if deck is empty
            hand = [
                Card(suit: .hearts, rank: .ace),
                Card(suit: .diamonds, rank: .king),
                Card(suit: .clubs, rank: .queen),
                Card(suit: .spades, rank: .jack),
                Card(suit: .hearts, rank: .ten)
            ]
        }
        
        return hand
    }
    
    /// Draws replacement cards for unheld positions
    /// - Parameter currentHand: The current hand with some cards held
    /// - Parameter heldCards: Boolean array indicating which cards are held
    /// - Returns: A new hand with unheld cards replaced
    private func drawReplacementCards(for currentHand: [Card], holding heldCards: [Bool]) -> [Card] {
        if case .training = mode {
            var newHand = currentHand
            let pool = allCards.filter { !currentHand.contains($0) }.shuffled()
            var poolIndex = 0
            for i in 0..<5 where !heldCards[i] {
                if poolIndex < pool.count {
                    newHand[i] = pool[poolIndex]
                    poolIndex += 1
                }
            }
            return newHand
        }

        var newHand = currentHand
        
        do {
            // Check if we have enough cards for replacement
            let cardsNeeded = heldCards.filter { !$0 }.count
            if deck.count < cardsNeeded {
                print("Warning: Not enough cards in deck for replacement (\(deck.count) < \(cardsNeeded)), reshuffling")
                prepareDeck()
            }
            
            for i in 0..<5 {
                // If card is not held, replace it with a new card
                if !heldCards[i] {
                    let newCard = try deck.deal()
                    newHand[i] = newCard
                }
            }
        } catch {
            print("Error drawing replacement cards: \(error)")
        }
        
        return newHand
    }

    private func nextTrainingHand() -> [Card] {
        guard !trainingHands.isEmpty else {
            prepareDeck()
            return dealHand()
        }

        if trainingCursor >= trainingOrder.count {
            reshuffleTrainingOrder()
        }

        let idx = trainingOrder[trainingCursor]
        let hand = trainingHands[idx]
        trainingCursor += 1
        persistTrainingState()
        return hand
    }

    private func trainingStateKey(for level: TrainingDifficulty) -> String {
        "training_state_\(level.rawValue)"
    }

    private func loadOrCreateTrainingOrder(for level: TrainingDifficulty) {
        let key = trainingStateKey(for: level)
        let count = trainingHands.count
        guard count > 0 else {
            trainingOrder = []
            trainingCursor = 0
            return
        }

        if let data = UserDefaults.standard.data(forKey: key),
           let saved = try? JSONDecoder().decode(PersistedTrainingState.self, from: data),
           saved.order.count == count,
           Set(saved.order) == Set(0..<count),
           saved.cursor >= 0,
           saved.cursor <= count {
            trainingOrder = saved.order
            trainingCursor = saved.cursor
            if trainingCursor >= count {
                reshuffleTrainingOrder()
            }
            return
        }

        trainingOrder = Array(0..<count).shuffled()
        trainingCursor = 0
        persistTrainingState()
    }

    private func reshuffleTrainingOrder() {
        let count = trainingHands.count
        trainingOrder = Array(0..<count).shuffled()
        trainingCursor = 0
        persistTrainingState()
    }

    private func persistTrainingState() {
        guard let level = trainingDifficulty else { return }
        let key = trainingStateKey(for: level)
        let state = PersistedTrainingState(order: trainingOrder, cursor: trainingCursor)
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    /// Clears persisted progress so the current training difficulty restarts at 0/50.
    func resetTrainingProgress() {
        guard let level = trainingDifficulty else { return }
        trainingCursor = 0
        trainingOrder = Array(0..<trainingHands.count).shuffled()
        let key = trainingStateKey(for: level)
        UserDefaults.standard.removeObject(forKey: key)
    }
    
    /// Calculates the expected value for the player's chosen hold combination
    /// - Returns: The expected value of the player's choice
    private func calculatePlayerEV(for hand: [Card], heldCards: [Bool], cachedEVs: [Int: Double]) -> Double {
        let holdMask = Self.holdMask(from: heldCards)
        if let cached = cachedEVs[holdMask] {
            return cached
        }
        
        do {
            let ev = try self.evCalculator.calculateExpectedValueForUserChoice(
                for: hand,
                userHold: heldCards
            )
            return ev
        } catch {
            print("Error calculating player EV: \(error)")
            return 0.0
        }
    }

    /// Converts a held-cards boolean array into a 5-bit mask.
    private static func holdMask(from held: [Bool]) -> Int {
        var mask = 0
        for i in 0..<held.count {
            if held[held.count - 1 - i] {
                mask |= (1 << i)
            }
        }
        return mask
    }
    
    /// Calculates the optimal hold strategy for a given hand
    /// - Parameter hand: The hand to analyze
    /// - Returns: A tuple containing the optimal hold combination and its expected value
    private func calculateOptimalStrategy(for hand: [Card]) -> (hold: [Bool], expectedValue: Double) {
        do {
            return try evCalculator.findOptimalHold(for: hand)
        } catch {
            print("Error calculating optimal strategy: \(error)")
            // Return default values if calculation fails
            return (hold: Array(repeating: false, count: 5), expectedValue: 0.0)
        }
    }
    
    /// Creates a new game state with a fresh hand
    /// - Returns: A new GameState instance
    private func createNewGameState() -> GameState {
        // Reset and shuffle the deck
        prepareDeck()
        
        // Deal initial hand
        let hand = dealHand()
        
        // Calculate optimal strategy
        let optimalResult = calculateOptimalStrategy(for: hand)
        
        // Create and return new game state
        return GameState(
            currentHand: hand,
            originalHand: hand,
            heldCards: Array(repeating: false, count: 5),
            stage: .deal,
            optimalHolds: optimalResult.hold,
            optimalEV: optimalResult.expectedValue,
            playerEV: 0.0,
            statistics: statistics
        )
    }
}
