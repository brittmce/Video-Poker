//
//  ExpectedValueCalculatorTests.swift
//  Video PokerTests
//
//  Created by Britt McEachern on 1/20/26.
//

import XCTest
@testable import Video_Poker

class ExpectedValueCalculatorTests: XCTestCase {
    
    var calculator: ExpectedValueCalculator!
    
    override func setUp() {
        super.setUp()
        calculator = ExpectedValueCalculator()
    }
    
    override func tearDown() {
        calculator = nil
        super.tearDown()
    }
    
    // MARK: - Expected Value Calculation Tests
    
    func testCalculateExpectedValueWithRoyalFlushHeld() throws {
        // Given a royal flush hand, holding all cards should give EV equal to payout
        let hand = [
            Card(suit: .hearts, rank: .ace),
            Card(suit: .hearts, rank: .king),
            Card(suit: .hearts, rank: .queen),
            Card(suit: .hearts, rank: .jack),
            Card(suit: .hearts, rank: .ten)
        ]
        let heldCards = [true, true, true, true, true] // Hold all cards
        
        // When calculating expected value
        let ev = try calculator.calculateExpectedValue(for: hand, heldCards: heldCards)
        
        // Then the EV should equal the royal flush payout (800 * 5 = 4000)
        XCTAssertEqual(ev, 4000.0, accuracy: 0.001, "Holding a royal flush should give EV of 4000 for $5 bet")
    }
    
    func testCalculateExpectedValueWithHighPair() throws {
        // Given a hand with a high pair (jacks), test holding just the pair
        let hand = [
            Card(suit: .hearts, rank: .jack),
            Card(suit: .diamonds, rank: .jack),
            Card(suit: .clubs, rank: .three),
            Card(suit: .spades, rank: .five),
            Card(suit: .hearts, rank: .seven)
        ]
        let heldCards = [true, true, false, false, false] // Hold the pair of jacks
        
        // Measure performance
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // When calculating expected value
        let ev = try calculator.calculateExpectedValue(for: hand, heldCards: heldCards)
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        print("Time to calculate EV for high pair: \(timeElapsed) seconds")
        
        // Then the EV should be positive (around 13-14 for high pair with $5 bet)
        XCTAssertGreaterThan(ev, 10.0, "Holding a high pair should give positive EV")
        XCTAssertLessThan(ev, 20.0, "EV for high pair should be reasonable")
        
        // Performance check - should be under 100ms
        XCTAssertLessThan(timeElapsed, 0.1, "EV calculation should take less than 100ms")
    }
    
    func testCalculateExpectedValueWithLowPair() throws {
        // Given a hand with a low pair (fives), test holding just the pair
        let hand = [
            Card(suit: .hearts, rank: .five),
            Card(suit: .diamonds, rank: .five),
            Card(suit: .clubs, rank: .three),
            Card(suit: .spades, rank: .seven),
            Card(suit: .hearts, rank: .nine)
        ]
        let heldCards = [true, true, false, false, false] // Hold the pair of fives
        
        // When calculating expected value
        let ev = try calculator.calculateExpectedValue(for: hand, heldCards: heldCards)
        
        // Then the EV should be positive but less than high pair (around 7.5-15 for low pair with $5 bet)
        XCTAssertGreaterThan(ev, 7.5, "Holding a low pair should give positive EV")
        XCTAssertLessThan(ev, 15.0, "EV for low pair should be reasonable")
    }
    
    func testCalculateExpectedValueWithNothingHeld() throws {
        // Given a hand with nothing special, holding nothing
        let hand = [
            Card(suit: .hearts, rank: .two),
            Card(suit: .diamonds, rank: .five),
            Card(suit: .clubs, rank: .seven),
            Card(suit: .spades, rank: .nine),
            Card(suit: .hearts, rank: .jack)
        ]
        let heldCards = [false, false, false, false, false] // Hold nothing
        
        // When calculating expected value
        let ev = try calculator.calculateExpectedValue(for: hand, heldCards: heldCards)
        
        // Then the EV should be very low (close to 0, but multiplied by 5 for $5 bet)
        XCTAssertLessThan(ev, 5.0, "Holding nothing should give very low EV")
    }
    
    func testCalculateExpectedValueWithFourToFlush() throws {
        // Given a hand with four cards to a flush
        let hand = [
            Card(suit: .hearts, rank: .ace),
            Card(suit: .hearts, rank: .king),
            Card(suit: .hearts, rank: .queen),
            Card(suit: .hearts, rank: .jack),
            Card(suit: .spades, rank: .ten) // Different suit
        ]
        let heldCards = [true, true, true, true, false] // Hold four to flush
        
        // When calculating expected value
        let ev = try calculator.calculateExpectedValue(for: hand, heldCards: heldCards)
        
        // Then the EV should be relatively high (around 20-30 with $5 bet)
        XCTAssertGreaterThan(ev, 15.0, "Four to a flush should give good EV")
        XCTAssertLessThan(ev, 40.0, "EV for four to flush should be reasonable")
    }
    
    // MARK: - Optimal Hold Identification Tests
    
    func testFindOptimalHoldWithRoyalFlush() throws {
        // Given a royal flush hand
        let hand = [
            Card(suit: .hearts, rank: .ace),
            Card(suit: .hearts, rank: .king),
            Card(suit: .hearts, rank: .queen),
            Card(suit: .hearts, rank: .jack),
            Card(suit: .hearts, rank: .ten)
        ]
        
        // When finding optimal hold
        let result = try calculator.findOptimalHold(for: hand)
        
        // Then it should recommend holding all cards
        XCTAssertEqual(result.hold, [true, true, true, true, true], "Should hold all cards for royal flush")
        XCTAssertEqual(result.expectedValue, 4000.0, accuracy: 0.001, "EV should be 4000 for royal flush with $5 bet")
    }
    
    func testFindOptimalHoldWithHighPair() throws {
        // Given a hand with a high pair
        let hand = [
            Card(suit: .hearts, rank: .queen),
            Card(suit: .diamonds, rank: .queen),
            Card(suit: .clubs, rank: .three),
            Card(suit: .spades, rank: .five),
            Card(suit: .hearts, rank: .seven)
        ]
        
        // Measure performance
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // When finding optimal hold
        let result = try calculator.findOptimalHold(for: hand)
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        print("Time to find optimal hold for high pair: \(timeElapsed) seconds")
        
        // Then it should recommend holding the pair
        XCTAssertEqual(result.hold, [true, true, false, false, false], "Should hold the high pair")
        
        // Performance check - should be under 100ms
        XCTAssertLessThan(timeElapsed, 0.1, "Optimal hold calculation should take less than 100ms")
    }
    
    func testFindOptimalHoldWithFourToFlush() throws {
        // Given a hand with four to a flush
        let hand = [
            Card(suit: .hearts, rank: .ace),
            Card(suit: .hearts, rank: .king),
            Card(suit: .hearts, rank: .queen),
            Card(suit: .hearts, rank: .jack),
            Card(suit: .spades, rank: .ten)
        ]
        
        // When finding optimal hold
        let result = try calculator.findOptimalHold(for: hand)
        
        // Then it should recommend holding the four flush cards
        XCTAssertEqual(result.hold, [true, true, true, true, false], "Should hold four to flush")
    }
    
    func testFindOptimalHoldWithFourToOutsideStraight() throws {
        // Given a hand with four to an outside straight
        let hand = [
            Card(suit: .hearts, rank: .ten),
            Card(suit: .diamonds, rank: .jack),
            Card(suit: .clubs, rank: .queen),
            Card(suit: .spades, rank: .king),
            Card(suit: .hearts, rank: .three)
        ]
        
        // When finding optimal hold
        let result = try calculator.findOptimalHold(for: hand)
        
        // Then it should recommend holding the four straight cards
        XCTAssertEqual(result.hold, [true, true, true, true, false], "Should hold four to outside straight")
    }

    func testFindOptimalHoldWithAceAndThreeToFlushChoosesAceOnly() throws {
        // Regression case from UI:
        // 10D, AH, 2H, 3S, 9H should prefer holding only the Ace.
        let hand = [
            Card(suit: .diamonds, rank: .ten),
            Card(suit: .hearts, rank: .ace),
            Card(suit: .hearts, rank: .two),
            Card(suit: .spades, rank: .three),
            Card(suit: .hearts, rank: .nine)
        ]

        let result = try calculator.findOptimalHold(for: hand)

        XCTAssertEqual(
            result.hold,
            [false, true, false, false, false],
            "Optimal hold should be Ace-only for this hand"
        )
    }

    func testFindOptimalHoldWithGarbageHandPrefersDiscardAll() throws {
        // Regression case from UI:
        // 8H, 2C, 7D, 5S, 9H should prefer drawing 5 (discard all).
        let hand = [
            Card(suit: .hearts, rank: .eight),
            Card(suit: .clubs, rank: .two),
            Card(suit: .diamonds, rank: .seven),
            Card(suit: .spades, rank: .five),
            Card(suit: .hearts, rank: .nine)
        ]

        let result = try calculator.findOptimalHold(for: hand)
        let discardAllEV = 0.3563 * 5.0

        XCTAssertEqual(
            result.hold,
            [false, false, false, false, false],
            "Optimal hold should be discard-all for this hand"
        )
        XCTAssertGreaterThanOrEqual(
            result.expectedValue,
            discardAllEV,
            "Optimal EV should never be below the discard-all baseline"
        )
    }

    func testEvaluateHandForEVCachedMatchesCanonicalPayout() {
        // Ensure cached evaluator returns the same payout as the canonical evaluator.
        var checked = 0
        outer: for s1 in Suit.allCases {
            for r1 in Rank.allCases {
                for s2 in Suit.allCases {
                    for r2 in Rank.allCases where !(s1 == s2 && r1 == r2) {
                        for s3 in Suit.allCases {
                            for r3 in Rank.allCases {
                                let c1 = Card(suit: s1, rank: r1)
                                let c2 = Card(suit: s2, rank: r2)
                                let c3 = Card(suit: s3, rank: r3)
                                // Build a valid 5-card hand with fixed tail cards
                                let c4 = Card(suit: .hearts, rank: .ace)
                                let c5 = Card(suit: .spades, rank: .king)
                                let cards = [c1, c2, c3, c4, c5]
                                let unique = Set(cards)
                                if unique.count != 5 { continue }

                                let expected = Hand(cards: cards).payout
                                let cached = Hand.evaluateHandForEVCached(cards)
                                XCTAssertEqual(
                                    cached,
                                    expected,
                                    "Cached EV evaluator diverged from canonical evaluator for \(cards)"
                                )

                                checked += 1
                                if checked >= 500 { break outer }
                            }
                        }
                    }
                }
            }
        }

        XCTAssertEqual(checked, 500, "Expected to validate 500 distinct hands")
    }
    
    // MARK: - Edge Cases and Error Conditions
    
    func testCalculateExpectedValueWithInvalidHandSize() {
        // Given a hand with wrong number of cards
        let hand = [Card(suit: .hearts, rank: .ace)]
        let heldCards = [true]
        
        // When calculating expected value, it should throw
        XCTAssertThrowsError(try calculator.calculateExpectedValue(for: hand, heldCards: heldCards)) { error in
            XCTAssertTrue(error is ExpectedValueError, "Should throw ExpectedValueError")
            if case ExpectedValueError.invalidHandSize = error {
                // Correct error type
            } else {
                XCTFail("Wrong error type thrown")
            }
        }
    }
    
    func testCalculateExpectedValueWithInvalidHoldCombination() {
        // Given a hand with correct size but wrong hold combination size
        let hand = [
            Card(suit: .hearts, rank: .ace),
            Card(suit: .diamonds, rank: .king),
            Card(suit: .clubs, rank: .queen),
            Card(suit: .spades, rank: .jack),
            Card(suit: .hearts, rank: .ten)
        ]
        let heldCards = [true, false, true] // Wrong size
        
        // When calculating expected value, it should throw
        XCTAssertThrowsError(try calculator.calculateExpectedValue(for: hand, heldCards: heldCards)) { error in
            XCTAssertTrue(error is ExpectedValueError, "Should throw ExpectedValueError")
            if case ExpectedValueError.invalidHoldCombination = error {
                // Correct error type
            } else {
                XCTFail("Wrong error type thrown")
            }
        }
    }
    
    func testFindOptimalHoldWithInvalidHandSize() {
        // Given a hand with wrong number of cards
        let hand = [Card(suit: .hearts, rank: .ace)]
        
        // When finding optimal hold, it should throw
        XCTAssertThrowsError(try calculator.findOptimalHold(for: hand)) { error in
            XCTAssertTrue(error is ExpectedValueError, "Should throw ExpectedValueError")
            if case ExpectedValueError.invalidHandSize = error {
                // Correct error type
            } else {
                XCTFail("Wrong error type thrown")
            }
        }
    }
    
    // MARK: - Cache Tests
    
    func testCacheFunctionality() throws {
        // Given a hand and hold combination
        let hand = [
            Card(suit: .hearts, rank: .jack),
            Card(suit: .diamonds, rank: .jack),
            Card(suit: .clubs, rank: .three),
            Card(suit: .spades, rank: .five),
            Card(suit: .hearts, rank: .seven)
        ]
        let heldCards = [true, true, false, false, false]
        
        // When calculating EV twice
        let ev1 = try calculator.calculateExpectedValue(for: hand, heldCards: heldCards)
        let ev2 = try calculator.calculateExpectedValue(for: hand, heldCards: heldCards)
        
        // Then results should be identical (cached)
        XCTAssertEqual(ev1, ev2, "Cached results should be identical")
    }
    
    func testClearCache() throws {
        // Given a hand and hold combination
        let hand = [
            Card(suit: .hearts, rank: .jack),
            Card(suit: .diamonds, rank: .jack),
            Card(suit: .clubs, rank: .three),
            Card(suit: .spades, rank: .five),
            Card(suit: .hearts, rank: .seven)
        ]
        let heldCards = [true, true, false, false, false]
        
        // When calculating EV and then clearing cache
        _ = try calculator.calculateExpectedValue(for: hand, heldCards: heldCards)
        calculator.clearCache()
        
        // Then calculate again (should recalculate, not use cache)
        let ev = try calculator.calculateExpectedValue(for: hand, heldCards: heldCards)
        
        // Just verify it still works after cache clear
        XCTAssertGreaterThan(ev, 0, "Should still calculate EV after cache clear")
    }
}
