//
//  PerformanceTests.swift
//  Video PokerTests
//
//  Created by Britt McEachern on 1/20/26.
//

import XCTest
@testable import Video_Poker

class PerformanceTests: XCTestCase {
    
    var gameManager: GameManager!
    var calculator: ExpectedValueCalculator!
    
    override func setUp() {
        super.setUp()
        gameManager = GameManager()
        calculator = ExpectedValueCalculator()
    }
    
    override func tearDown() {
        gameManager = nil
        calculator = nil
        super.tearDown()
    }
    
    // MARK: - Performance Tests
    
    func testStartNewHandPerformance() {
        // Measure the time it takes to start a new hand (deal cards and calculate optimal strategy)
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Execute the operation we want to measure
        gameManager.startNewHand()
        
        // Wait for any asynchronous operations to complete
        let expectation = XCTestExpectation(description: "New hand dealt")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // Log the time for debugging
        print("Time to start new hand: \(timeElapsed) seconds")
        
        // Assert that it's under our performance requirement (1 second for now, to be optimized)
        XCTAssertLessThan(timeElapsed, 1.0, "Starting new hand should take less than 1 second")
    }
    
    func testProcessDrawPerformance() {
        // First start a new hand
        gameManager.startNewHand()
        
        // Wait for initial hand to be dealt
        let initialExpectation = XCTestExpectation(description: "Initial hand dealt")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            initialExpectation.fulfill()
        }
        wait(for: [initialExpectation], timeout: 2.0)
        
        // Make some hold decisions
        gameManager.toggleHold(for: 0)
        gameManager.toggleHold(for: 1)
        
        // Move to draw stage
        gameManager.handleActionButtonPress()
        
        // Measure the time it takes to process the draw
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Execute the operation we want to measure
        gameManager.processDraw()
        
        // Wait for draw processing to complete
        let expectation = XCTestExpectation(description: "Draw processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // Log the time for debugging
        print("Time to process draw: \(timeElapsed) seconds")
        
        // Assert that it's under our performance requirement (1 second for now, to be optimized)
        XCTAssertLessThan(timeElapsed, 1.0, "Processing draw should take less than 1 second")
    }
    
    func testExpectedValueCalculationPerformance() {
        // Create a test hand
        let hand = [
            Card(suit: .hearts, rank: .jack),
            Card(suit: .diamonds, rank: .jack),
            Card(suit: .clubs, rank: .three),
            Card(suit: .spades, rank: .five),
            Card(suit: .hearts, rank: .seven)
        ]
        let heldCards = [true, true, false, false, false] // Hold the pair of jacks
        
        // Measure the time it takes to calculate expected value
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Execute the operation we want to measure
        do {
            let _ = try calculator.calculateExpectedValue(for: hand, heldCards: heldCards)
        } catch {
            XCTFail("Failed to calculate expected value: \(error)")
        }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // Log the time for debugging
        print("Time to calculate expected value: \(timeElapsed) seconds")
        
        // Assert that it's under our performance requirement (0.5 seconds for now, to be optimized)
        XCTAssertLessThan(timeElapsed, 0.5, "Expected value calculation should take less than 0.5 seconds")
    }
    
    func testFindOptimalHoldPerformance() {
        // Create a test hand
        let hand = [
            Card(suit: .hearts, rank: .ace),
            Card(suit: .hearts, rank: .king),
            Card(suit: .hearts, rank: .queen),
            Card(suit: .hearts, rank: .jack),
            Card(suit: .spades, rank: .ten)
        ]
        
        // Measure the time it takes to find optimal hold
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Execute the operation we want to measure
        do {
            let _ = try calculator.findOptimalHold(for: hand)
        } catch {
            XCTFail("Failed to find optimal hold: \(error)")
        }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // Log the time for debugging
        print("Time to find optimal hold: \(timeElapsed) seconds")
        
        // Assert that it's under our performance requirement (1 second for now, to be optimized)
        XCTAssertLessThan(timeElapsed, 1.0, "Finding optimal hold should take less than 1 second")
    }
    
    func testMultipleConsecutiveHandsPerformance() {
        // Measure performance over multiple consecutive hands
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let numberOfHands = 3
        
        for i in 0..<numberOfHands {
            // Start new hand
            gameManager.startNewHand()
            
            // Wait for hand to be dealt
            let expectation = XCTestExpectation(description: "Hand \(i) dealt")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 1.0)
            
            // Make some hold decisions
            gameManager.toggleHold(for: 0)
            
            // Move to draw stage
            gameManager.handleActionButtonPress()
            
            // Process draw
            gameManager.processDraw()
            
            // Wait for draw processing
            let drawExpectation = XCTestExpectation(description: "Hand \(i) draw processed")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                drawExpectation.fulfill()
            }
            wait(for: [drawExpectation], timeout: 1.0)
            
            // Start new hand for next iteration
            if i < numberOfHands - 1 {
                gameManager.handleActionButtonPress()
                
                // Wait for new hand
                let newHandExpectation = XCTestExpectation(description: "New hand started")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    newHandExpectation.fulfill()
                }
                wait(for: [newHandExpectation], timeout: 1.0)
            }
        }
        
        let totalTimeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        let averageTimePerHand = totalTimeElapsed / Double(numberOfHands)
        
        // Log the times for debugging
        print("Total time for \(numberOfHands) hands: \(totalTimeElapsed) seconds")
        print("Average time per hand: \(averageTimePerHand) seconds")
        
        // Assert that average time per hand is under our performance requirement (1 second for now, to be optimized)
        XCTAssertLessThan(averageTimePerHand, 1.0, "Average time per hand should be less than 1 second")
    }
}