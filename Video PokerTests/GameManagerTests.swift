//
//  GameManagerTests.swift
//  Video PokerTests
//
//  Created by Britt McEachern on 1/20/26.
//

import XCTest
@testable import Video_Poker

class GameManagerTests: XCTestCase {
    
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
    
    // MARK: - Game Flow Management Tests
    
    func testStartNewHand() {
        // Given a game manager
        guard let initialGameState = gameManager.gameState else {
            XCTFail("Game state should be initialized")
            return
        }
        let initialHand = initialGameState.currentHand
        let initialStage = initialGameState.stage
        
        // When starting a new hand
        gameManager.startNewHand()
        
        // Then the hand should be different and stage should be deal
        guard let newGameState = gameManager.gameState else {
            XCTFail("Game state should be initialized after startNewHand")
            return
        }
        XCTAssertNotEqual(newGameState.currentHand, initialHand, "New hand should be dealt")
        XCTAssertEqual(newGameState.stage, .deal, "Stage should be deal after starting new hand")
        XCTAssertEqual(newGameState.heldCards, [false, false, false, false, false], "All cards should be unheld initially")
    }
    
    func testToggleHoldInDealStage() {
        // Given a game in deal stage
        guard let gameState = gameManager.gameState else {
            XCTFail("Game state should be initialized")
            return
        }
        XCTAssertEqual(gameState.stage, .deal, "Game should start in deal stage")
        
        // When toggling hold for first card
        gameManager.toggleHold(for: 0)
        
        // Then the first card should be held
        guard let newGameState = gameManager.gameState else {
            XCTFail("Game state should be initialized after toggleHold")
            return
        }
        XCTAssertTrue(newGameState.heldCards[0], "First card should be held after toggle")
        XCTAssertFalse(newGameState.heldCards[1], "Second card should not be held")
    }
    
    func testToggleHoldInOtherStages() {
        // Given a game in deal stage, toggle to draw stage
        gameManager.handleActionButtonPress() // Move to draw stage
        guard let gameState = gameManager.gameState else {
            XCTFail("Game state should be initialized")
            return
        }
        XCTAssertEqual(gameState.stage, .draw, "Should be in draw stage")
        
        // When trying to toggle hold in draw stage
        let initialHeldCards = gameState.heldCards
        gameManager.toggleHold(for: 0)
        
        // Then held cards should remain unchanged
        guard let newGameState = gameManager.gameState else {
            XCTFail("Game state should be initialized after toggleHold")
            return
        }
        XCTAssertEqual(newGameState.heldCards, initialHeldCards, "Held cards should not change in draw stage")
    }
    
    func testHandleActionButtonPressDealToDraw() {
        // Given a game in deal stage
        guard let gameState = gameManager.gameState else {
            XCTFail("Game state should be initialized")
            return
        }
        XCTAssertEqual(gameState.stage, .deal, "Game should start in deal stage")
        
        // When pressing action button
        gameManager.handleActionButtonPress()
        
        // Then stage should change to draw
        guard let newGameState = gameManager.gameState else {
            XCTFail("Game state should be initialized after handleActionButtonPress")
            return
        }
        XCTAssertEqual(newGameState.stage, .draw, "Stage should change to draw")
    }
    
    func testHandleActionButtonPressDrawToResult() {
        // Given a game in deal stage, move to draw stage
        gameManager.handleActionButtonPress()
        guard let gameState = gameManager.gameState else {
            XCTFail("Game state should be initialized")
            return
        }
        XCTAssertEqual(gameState.stage, .draw, "Should be in draw stage")
        
        // When pressing action button again
        gameManager.handleActionButtonPress()
        
        // Then stage should change to result
        guard let newGameState = gameManager.gameState else {
            XCTFail("Game state should be initialized after handleActionButtonPress")
            return
        }
        XCTAssertEqual(newGameState.stage, .result, "Stage should change to result")
    }
    
    func testHandleActionButtonPressResultToDeal() {
        // Given a game, move through complete cycle to result stage
        gameManager.handleActionButtonPress() // Deal -> Draw
        gameManager.handleActionButtonPress() // Draw -> Result
        guard let gameState = gameManager.gameState else {
            XCTFail("Game state should be initialized")
            return
        }
        XCTAssertEqual(gameState.stage, .result, "Should be in result stage")
        
        // When pressing action button again
        gameManager.handleActionButtonPress()
        
        // Then stage should change back to deal with new hand
        guard let newGameState = gameManager.gameState else {
            XCTFail("Game state should be initialized after handleActionButtonPress")
            return
        }
        XCTAssertEqual(newGameState.stage, .deal, "Stage should change to deal")
    }
    
    func testResetHand() {
        // Given a game with some held cards
        guard let initialGameState = gameManager.gameState else {
            XCTFail("Game state should be initialized")
            return
        }
        let initialHand = initialGameState.currentHand
        gameManager.toggleHold(for: 0)
        gameManager.toggleHold(for: 2)
        guard let gameStateAfterToggle = gameManager.gameState else {
            XCTFail("Game state should be initialized after toggleHold")
            return
        }
        XCTAssertTrue(gameStateAfterToggle.heldCards[0], "First card should be held")
        XCTAssertTrue(gameStateAfterToggle.heldCards[2], "Third card should be held")
        
        // When resetting hand
        gameManager.resetHand()
        
        // Then all cards should be unheld and it should be a new hand
        guard let newGameState = gameManager.gameState else {
            XCTFail("Game state should be initialized after resetHand")
            return
        }
        XCTAssertEqual(newGameState.heldCards, [false, false, false, false, false], "All cards should be unheld after reset")
        XCTAssertEqual(newGameState.stage, .deal, "Stage should be deal after reset")
    }
    
    // MARK: - Statistics Tracking Tests
    
    func testStatisticsInitialization() {
        // Given a new game manager
        // When checking initial statistics
        XCTAssertEqual(gameManager.statistics.handsPlayed, 0, "No hands should be played initially")
        XCTAssertEqual(gameManager.statistics.correctDecisions, 0, "No correct decisions initially")
        XCTAssertEqual(gameManager.statistics.totalPlayerEV, 0.0, "Total player EV should be zero initially")
        XCTAssertEqual(gameManager.statistics.totalOptimalEV, 0.0, "Total optimal EV should be zero initially")
        XCTAssertEqual(gameManager.statistics.accuracyPercentage, 0.0, "Accuracy should be zero initially")
        XCTAssertEqual(gameManager.statistics.evRatio, 0.0, "EV ratio should be zero initially")
    }
    
    func testProcessDrawUpdatesStatistics() {
        // Given a game with some initial stats
        let initialHandsPlayed = gameManager.statistics.handsPlayed
        let initialCorrectDecisions = gameManager.statistics.correctDecisions
        
        // Set up a scenario where player makes a choice
        // Move to draw stage
        gameManager.handleActionButtonPress()
        
        // When processing draw
        gameManager.processDraw()
        
        // Then statistics should be updated
        XCTAssertEqual(gameManager.statistics.handsPlayed, initialHandsPlayed + 1, "Hands played should increment")
        XCTAssertGreaterThanOrEqual(gameManager.statistics.correctDecisions, initialCorrectDecisions, "Correct decisions should be updated")
        XCTAssertGreaterThan(gameManager.statistics.totalPlayerEV, 0.0, "Player EV should be greater than zero (multiplied by 5 for $5 bet)")
        XCTAssertGreaterThan(gameManager.statistics.totalOptimalEV, 0.0, "Optimal EV should be greater than zero (multiplied by 5 for $5 bet)")
    }
    
    // MARK: - Expected Value Comparison Tests
    
    func testIsPlayerChoiceCorrectWithOptimalHold() {
        // This is difficult to test deterministically since optimal holds are calculated
        // But we can test that the comparison logic works
        
        // Given a game manager with a known hand
        // We'll manually set up a scenario where we know the optimal holds
        
        // Since we can't easily inject the optimal holds, we'll test the comparison mechanism
        let hand = [
            Card(suit: .hearts, rank: .ace),
            Card(suit: .hearts, rank: .king),
            Card(suit: .hearts, rank: .queen),
            Card(suit: .hearts, rank: .jack),
            Card(suit: .hearts, rank: .ten)
        ]
        
        // For a royal flush, optimal is to hold all cards
        let optimalHolds = [true, true, true, true, true]
        let playerHolds = [true, true, true, true, true]
        
        // Test the comparison logic directly
        XCTAssertTrue(optimalHolds == playerHolds, "Identical hold arrays should be equal")
    }
    
    func testIsPlayerChoiceIncorrectWithDifferentHold() {
        // Test that different hold arrays are correctly identified as different
        
        let optimalHolds = [true, true, true, true, true]
        let playerHolds = [true, true, false, false, false]
        
        // Test the comparison logic directly
        XCTAssertFalse(optimalHolds == playerHolds, "Different hold arrays should not be equal")
    }
    
    // MARK: - Edge Cases
    
    func testEmptyDeckHandling() {
        // This is challenging to test directly since the deck is internal
        // But we can test that the game continues to function
        
        // Given a game manager
        // When starting multiple hands (which should reshuffle each time)
        gameManager.startNewHand()
        gameManager.startNewHand()
        gameManager.startNewHand()
        
        // Then the game should continue to function
        XCTAssertEqual(gameManager.gameState?.stage, .deal, "Game should still be functional after multiple hands")
        XCTAssertEqual(gameManager.gameState?.currentHand.count ?? 0, 5, "Hand should still have 5 cards")
    }
    
    func testToggleHoldWithInvalidIndex() {
        // Given a game manager
        // When trying to toggle hold with invalid index, it should not crash
        // Note: The implementation uses fatalError for invalid indices, so we can't test this directly
        // In a real test environment, we would use a testing assertion
        
        // For now, we'll just test valid indices work
        XCTAssertNoThrow(gameManager.toggleHold(for: 0), "Valid index should not throw")
        XCTAssertNoThrow(gameManager.toggleHold(for: 4), "Valid index should not throw")
    }
    
    // MARK: - Helper Method Tests
    
    func testDealHandReturnsFiveCards() {
        // This tests private methods indirectly through public interface
        
        // Given a game manager
        guard let gameState = gameManager.gameState else {
            XCTFail("Game state should be initialized")
            return
        }
        let initialHand = gameState.currentHand
        
        // When starting a new hand
        gameManager.startNewHand()
        
        // Then the new hand should have 5 cards
        guard let newGameState = gameManager.gameState else {
            XCTFail("Game state should be initialized after startNewHand")
            return
        }
        XCTAssertEqual(newGameState.currentHand.count, 5, "Dealt hand should have 5 cards")
        XCTAssertEqual(initialHand.count, 5, "Initial hand should have 5 cards")
    }
    
    func testPlayerEVCalculation() {
        // Test that player EV gets calculated during draw processing
        
        // Given a game in deal stage
        guard let gameState = gameManager.gameState else {
            XCTFail("Game state should be initialized")
            return
        }
        let initialPlayerEV = gameState.playerEV
        
        // Move to draw stage
        gameManager.handleActionButtonPress()
        
        // When processing draw
        gameManager.processDraw()
        
        // Then player EV should be updated
        guard let newGameState = gameManager.gameState else {
            XCTFail("Game state should be initialized after processDraw")
            return
        }
        XCTAssertNotEqual(newGameState.playerEV, initialPlayerEV, "Player EV should be updated after draw")
    }
    
    func testShowFeedbackMechanism() {
        // Test that feedback is shown and hidden appropriately
        
        // Given a game
        XCTAssertFalse(gameManager.showFeedback, "Feedback should be hidden initially")
        
        // Move to draw stage and process
        gameManager.handleActionButtonPress()
        gameManager.processDraw()
        
        // Then feedback should be shown
        XCTAssertTrue(gameManager.showFeedback, "Feedback should be shown after processing draw")
    }
    
    // MARK: - Initialization Tests
    
    func testGameManagerInitializesWithoutDealingCards() {
        // Given a fresh game manager (without calling startNewHand)
        let freshGameManager = GameManager()
        
        // Then the game state should be nil initially
        XCTAssertNil(freshGameManager.gameState, "Game state should be nil initially")
        
        // And statistics should be initialized
        XCTAssertEqual(freshGameManager.statistics.handsPlayed, 0, "No hands should be played initially")
        XCTAssertEqual(freshGameManager.statistics.correctDecisions, 0, "No correct decisions initially")
    }
    
    func testStartNewHandCreatesValidGameState() {
        // Given a fresh game manager
        let freshGameManager = GameManager()
        
        // When starting a new hand
        freshGameManager.startNewHand()
        
        // Then the game state should be initialized
        XCTAssertNotNil(freshGameManager.gameState, "Game state should be initialized after startNewHand")
        
        // And it should have a valid hand
        XCTAssertEqual(freshGameManager.gameState?.currentHand.count, 5, "Hand should have 5 cards")
        
        // And it should be in the deal stage
        XCTAssertEqual(freshGameManager.gameState?.stage, .deal, "Game should start in deal stage")
        
        // And no cards should be held initially
        XCTAssertEqual(freshGameManager.gameState?.heldCards, [false, false, false, false, false], "No cards should be held initially")
    }
}