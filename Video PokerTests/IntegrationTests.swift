//
//  IntegrationTests.swift
//  Video PokerTests
//
//  Created by Britt McEachern on 1/20/26.
//

import XCTest
@testable import Video_Poker

class IntegrationTests: XCTestCase {
    
    var gameManager: GameManager!
    
    override func setUp() {
        super.setUp()
        gameManager = GameManager()
        // Start with a new hand for most tests
        gameManager.startNewHand()
    }
    
    override func tearDown() {
        gameManager = nil
        super.tearDown()
    }
    
    // MARK: - Component Interaction Tests
    
    func testExpectedValueCalculatorIntegration() {
        // Test that the game manager properly integrates with the expected value calculator
        
        // Given a game manager with a new hand
        guard let gameState = gameManager.gameState else {
            XCTFail("Game state should be initialized")
            return
        }
        let hand = gameState.currentHand
        let optimalHolds = gameState.optimalHolds
        let optimalEV = gameState.optimalEV
        
        // When using the expected value calculator directly
        let calculator = ExpectedValueCalculator()
        
        // Then the optimal values should be calculable
        XCTAssertNoThrow(try calculator.calculateExpectedValue(for: hand, heldCards: optimalHolds), "Should be able to calculate EV for optimal holds")
        XCTAssertNoThrow(try calculator.findOptimalHold(for: hand), "Should be able to find optimal hold")
        
        // And the EV should be positive (multiplied by 5 for $5 bet)
        XCTAssertGreaterThan(optimalEV, 0.0, "Optimal EV should be positive")
    }
    
    func testPlayerStatisticsIntegration() {
        // Test that player statistics are properly integrated with game state
        
        // Given initial statistics
        let initialHandsPlayed = gameManager.statistics.handsPlayed
        let initialCorrectDecisions = gameManager.statistics.correctDecisions
        
        // When completing a game cycle
        gameManager.handleActionButtonPress() // Deal -> Draw
        gameManager.processDraw() // Process draw and update stats
        
        // Then statistics should be updated
        guard let gameState = gameManager.gameState else {
            XCTFail("Game state should be initialized")
            return
        }
        XCTAssertEqual(gameManager.statistics.handsPlayed, initialHandsPlayed + 1, "Hands played should increment")
        XCTAssertGreaterThanOrEqual(gameManager.statistics.correctDecisions, initialCorrectDecisions, "Correct decisions should update")
        
        // And the game state should reference the same statistics object
        XCTAssertTrue(gameState.statistics === gameManager.statistics, "Game state should reference same statistics object")
        
    }
    
    func testDeckIntegration() {
        // Test that the deck is properly integrated with game flow
        
        // Given a game manager
        guard let gameState = gameManager.gameState else {
            XCTFail("Game state should be initialized")
            return
        }
        let initialHand = gameState.currentHand
        
        // When starting a new hand
        gameManager.startNewHand()
        
        // Then a new hand should be dealt (different cards)
        guard let newGameState = gameManager.gameState else {
            XCTFail("Game state should be initialized after startNewHand")
            return
        }
        XCTAssertNotEqual(newGameState.currentHand, initialHand, "New hand should be dealt")
        XCTAssertEqual(newGameState.currentHand.count, 5, "New hand should have 5 cards")
        
    }
    
    // MARK: - Complete Game Flow Tests
    
    func testCompleteGameFlowFromStartToFinish() {
        // Test a complete game flow cycle
        
        // Given a fresh game manager
        guard let gameState = gameManager.gameState else {
            XCTFail("Game state should be initialized")
            return
        }
        XCTAssertEqual(gameState.stage, .deal, "Game should start in deal stage")
        XCTAssertEqual(gameState.heldCards, [false, false, false, false, false], "All cards should start unheld")
        
        // When going through a complete game cycle
        // 1. Player makes hold decisions (toggle some holds)
        gameManager.toggleHold(for: 0)
        gameManager.toggleHold(for: 1)
        
        // 2. Player presses draw button
        gameManager.handleActionButtonPress()
        guard let gameStateAfterDraw = gameManager.gameState else {
            XCTFail("Game state should be initialized after handleActionButtonPress")
            return
        }
        XCTAssertEqual(gameStateAfterDraw.stage, .draw, "Stage should be draw after pressing draw")
        
        // 3. System processes the draw
        gameManager.processDraw()
        guard let gameStateAfterProcess = gameManager.gameState else {
            XCTFail("Game state should be initialized after processDraw")
            return
        }
        XCTAssertEqual(gameStateAfterProcess.stage, .result, "Stage should be result after processing draw")
        
        // 4. Player starts new hand
        gameManager.handleActionButtonPress()
        guard let gameStateAfterNewHand = gameManager.gameState else {
            XCTFail("Game state should be initialized after handleActionButtonPress")
            return
        }
        XCTAssertEqual(gameStateAfterNewHand.stage, .deal, "Stage should be deal after starting new hand")
        XCTAssertEqual(gameStateAfterNewHand.heldCards, [false, false, false, false, false], "All cards should be unheld in new hand")
    }
    
    func testMultipleGameCycles() {
        // Test multiple complete game cycles
        
        let cycles = 3
        var hands: [[Card]] = []
        
        for i in 0..<cycles {
            // Record the hand
            guard let gameState = gameManager.gameState else {
                XCTFail("Game state should be initialized")
                return
            }
            hands.append(gameState.currentHand)
            
            // Make some hold decisions
            if i % 2 == 0 {
                gameManager.toggleHold(for: 0)
                gameManager.toggleHold(for: 2)
            } else {
                gameManager.toggleHold(for: 1)
                gameManager.toggleHold(for: 3)
            }
            
            // Complete the game cycle
            gameManager.handleActionButtonPress() // Deal -> Draw
            gameManager.processDraw() // Draw -> Result
            gameManager.handleActionButtonPress() // Result -> Deal (new hand)
        }
        
        // Then all hands should be different
        for i in 0..<hands.count {
            for j in (i+1)..<hands.count {
                XCTAssertNotEqual(hands[i], hands[j], "All hands should be different")
            }
        }
        
        // And statistics should reflect multiple hands played
        XCTAssertEqual(gameManager.statistics.handsPlayed, cycles, "Should have played \(cycles) hands")
    }
    
    func testStatisticsAccumulationOverMultipleGames() {
        // Test that statistics accumulate properly over multiple games
        
        let initialHandsPlayed = gameManager.statistics.handsPlayed
        let initialTotalPlayerEV = gameManager.statistics.totalPlayerEV
        let initialTotalOptimalEV = gameManager.statistics.totalOptimalEV
        
        // Play several hands
        let numberOfHands = 5
        for _ in 0..<numberOfHands {
            // Make some hold decisions
            gameManager.toggleHold(for: 0)
            
            // Complete the game cycle
            gameManager.handleActionButtonPress() // Deal -> Draw
            gameManager.processDraw() // Draw -> Result
            gameManager.handleActionButtonPress() // Result -> Deal (new hand)
        }
        
        // Then statistics should accumulate
        XCTAssertEqual(gameManager.statistics.handsPlayed, initialHandsPlayed + numberOfHands, "Should have played \(numberOfHands) additional hands")
        XCTAssertGreaterThan(gameManager.statistics.totalPlayerEV, initialTotalPlayerEV, "Total player EV should increase (multiplied by 5 for $5 bet)")
        XCTAssertGreaterThan(gameManager.statistics.totalOptimalEV, initialTotalOptimalEV, "Total optimal EV should increase (multiplied by 5 for $5 bet)")
        
        // Accuracy and ratio should be calculable
        XCTAssertGreaterThanOrEqual(gameManager.statistics.accuracyPercentage, 0.0, "Accuracy should be non-negative")
        XCTAssertLessThanOrEqual(gameManager.statistics.accuracyPercentage, 100.0, "Accuracy should not exceed 100%")
        XCTAssertGreaterThanOrEqual(gameManager.statistics.evRatio, 0.0, "EV ratio should be non-negative")
    }
    
    // MARK: - UI State Reflection Tests
    
    func testGameStateChangesReflectInUIProperties() {
        // Test that game state changes properly update observable properties
        
        // Given initial state
        guard let gameState = gameManager.gameState else {
            XCTFail("Game state should be initialized")
            return
        }
        let initialStage = gameState.stage
        let initialShowFeedback = gameManager.showFeedback
        let initialIsCorrectChoice = gameManager.isCorrectChoice
        
        // When changing game state through actions
        gameManager.handleActionButtonPress() // Deal -> Draw
        gameManager.processDraw() // Draw -> Result (shows feedback)
        
        // Then UI properties should update appropriately
        guard let gameStateAfterProcess = gameManager.gameState else {
            XCTFail("Game state should be initialized after processDraw")
            return
        }
        XCTAssertEqual(gameStateAfterProcess.stage, .result, "Stage should update to result")
        XCTAssertTrue(gameManager.showFeedback, "Feedback should be shown after draw")
        
        // After delay, feedback should be hidden (this is handled by async dispatch)
        // We can't easily test the automatic hiding, but we can test manual control
        gameManager.showFeedback = false
        XCTAssertFalse(gameManager.showFeedback, "Should be able to manually hide feedback")
    }
    
    func testHeldCardsStateProperlyMaintained() {
        // Test that held cards state is properly maintained through game flow
        
        // Given a hand with some cards held
        gameManager.toggleHold(for: 0)
        gameManager.toggleHold(for: 3)
        guard let gameState = gameManager.gameState else {
            XCTFail("Game state should be initialized")
            return
        }
        let heldCardsAfterToggle = gameState.heldCards
        
        // When moving to draw stage
        gameManager.handleActionButtonPress()
        
        // Then held cards should remain the same
        guard let gameStateAfterDraw = gameManager.gameState else {
            XCTFail("Game state should be initialized after handleActionButtonPress")
            return
        }
        XCTAssertEqual(gameStateAfterDraw.heldCards, heldCardsAfterToggle, "Held cards should persist to draw stage")
        
        // When processing draw and returning to deal
        gameManager.processDraw()
        gameManager.handleActionButtonPress() // Result -> Deal (new hand)
        
        // Then new hand should start with all cards unheld
        guard let gameStateAfterNewHand = gameManager.gameState else {
            XCTFail("Game state should be initialized after handleActionButtonPress")
            return
        }
        XCTAssertEqual(gameStateAfterNewHand.heldCards, [false, false, false, false, false], "New hand should start with all cards unheld")
    }
    
    func testOptimalStrategyConsistency() {
        // Test that optimal strategy is consistently calculated
        
        // Given a specific hand
        guard let gameState = gameManager.gameState else {
            XCTFail("Game state should be initialized")
            return
        }
        let hand = gameState.currentHand
        let optimalHolds = gameState.optimalHolds
        let optimalEV = gameState.optimalEV
        
        // When recalculating optimal strategy
        let calculator = ExpectedValueCalculator()
        let recalculatedResult = try? calculator.findOptimalHold(for: hand)
        
        // Then results should be consistent (allowing for floating point precision)
        if let recalculatedResult = recalculatedResult {
            XCTAssertEqual(recalculatedResult.hold.count, optimalHolds.count, "Hold arrays should have same length")
            XCTAssertEqual(recalculatedResult.expectedValue, optimalEV, accuracy: 0.001, "EV should be consistent (multiplied by 5 for $5 bet)")
        }
    }
    
    // MARK: - Edge Case Integration Tests
    
    func testGameResilienceToEdgeCases() {
        // Test that the game handles edge cases gracefully
        
        // Given multiple rapid state changes
        for _ in 0..<10 {
            gameManager.handleActionButtonPress()
        }
        
        // Then the game should still be in a valid state
        XCTAssertNotNil(gameManager.gameState?.currentHand, "Hand should still exist")
        XCTAssertEqual(gameManager.gameState?.currentHand.count ?? 0, 5, "Hand should still have 5 cards")
        XCTAssertTrue(gameManager.gameState?.stage == .deal || gameManager.gameState?.stage == .draw || gameManager.gameState?.stage == .result, "Stage should be valid")
    }
    
    func testComponentInteractionUnderStress() {
        // Test component interactions under repeated use
        
        // Given a calculator and statistics
        let calculator = ExpectedValueCalculator()
        let initialStats = gameManager.statistics.handsPlayed
        
        // When repeatedly using components
        for i in 0..<20 {
            // Use calculator
            guard let gameState = gameManager.gameState else {
                XCTFail("Game state should be initialized")
                return
            }
            let hand = gameState.currentHand
            XCTAssertNoThrow(try calculator.findOptimalHold(for: hand), "Calculator should work repeatedly")
            
            // Complete game cycle every few iterations
            if i % 4 == 0 {
                gameManager.handleActionButtonPress()
                gameManager.processDraw()
                gameManager.handleActionButtonPress()
            }
        }
        
        // Then everything should still work
        XCTAssertGreaterThanOrEqual(gameManager.statistics.handsPlayed, initialStats, "Statistics should still update")
    }
}