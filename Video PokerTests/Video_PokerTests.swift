//
//  Video_PokerTests.swift
//  Video PokerTests
//
//  Created by Britt McEachern on 1/20/26.
//

import Testing
@testable import Video_Poker

struct Video_PokerTests {
    
    @Test func testRoyalFlushPayout() throws {
        // Create a royal flush hand (A, K, Q, J, 10 of same suit)
        let royalFlushCards = [
            Card(suit: .hearts, rank: .ace),
            Card(suit: .hearts, rank: .king),
            Card(suit: .hearts, rank: .queen),
            Card(suit: .hearts, rank: .jack),
            Card(suit: .hearts, rank: .ten)
        ]
        
        let royalFlushHand = Hand(cards: royalFlushCards)
        #expect(royalFlushHand.payout == 800) // Should be 800 according to 9/5 pay table
        #expect(royalFlushHand.name == "Royal Flush")
    }
    
    @Test func testStraightFlushPayout() throws {
        // Create a straight flush hand (9, 8, 7, 6, 5 of same suit)
        let straightFlushCards = [
            Card(suit: .hearts, rank: .nine),
            Card(suit: .hearts, rank: .eight),
            Card(suit: .hearts, rank: .seven),
            Card(suit: .hearts, rank: .six),
            Card(suit: .hearts, rank: .five)
        ]
        
        let straightFlushHand = Hand(cards: straightFlushCards)
        #expect(straightFlushHand.payout == 50) // Should be 50 according to 9/5 pay table
        #expect(straightFlushHand.name == "Straight Flush")
    }
    
    @Test func testFourOfAKindPayout() throws {
        // Create a four of a kind hand
        let fourOfAKindCards = [
            Card(suit: .hearts, rank: .ace),
            Card(suit: .diamonds, rank: .ace),
            Card(suit: .clubs, rank: .ace),
            Card(suit: .spades, rank: .ace),
            Card(suit: .hearts, rank: .king)
        ]
        
        let fourOfAKindHand = Hand(cards: fourOfAKindCards)
        #expect(fourOfAKindHand.payout == 25) // Should be 25 according to 9/5 pay table
        #expect(fourOfAKindHand.name == "Four of a Kind")
    }
    
    @Test func testFullHousePayout() throws {
        // Create a full house hand (three of a kind and a pair)
        let fullHouseCards = [
            Card(suit: .hearts, rank: .king),
            Card(suit: .diamonds, rank: .king),
            Card(suit: .clubs, rank: .king),
            Card(suit: .spades, rank: .jack),
            Card(suit: .hearts, rank: .jack)
        ]
        
        let fullHouseHand = Hand(cards: fullHouseCards)
        #expect(fullHouseHand.payout == 9) // Should be 9 according to 9/5 pay table
        #expect(fullHouseHand.name == "Full House")
    }
    
    @Test func testFlushPayout() throws {
        // Create a flush hand (5 cards of the same suit)
        let flushCards = [
            Card(suit: .hearts, rank: .ace),
            Card(suit: .hearts, rank: .king),
            Card(suit: .hearts, rank: .queen),
            Card(suit: .hearts, rank: .jack),
            Card(suit: .hearts, rank: .ten)
        ]
        
        let flushHand = Hand(cards: flushCards)
        #expect(flushHand.payout == 5) // Should be 5 according to 9/5 pay table
        #expect(flushHand.name == "Flush")
    }
    
    @Test func testStraightPayout() throws {
        // Create a straight hand (5 consecutive ranks)
        let straightCards = [
            Card(suit: .hearts, rank: .ace),
            Card(suit: .diamonds, rank: .king),
            Card(suit: .clubs, rank: .queen),
            Card(suit: .spades, rank: .jack),
            Card(suit: .hearts, rank: .ten)
        ]
        
        let straightHand = Hand(cards: straightCards)
        #expect(straightHand.payout == 4)
        #expect(straightHand.name == "Straight")
    }
    
    @Test func testThreeOfAKindPayout() throws {
        // Create a three of a kind hand
        let threeOfAKindCards = [
            Card(suit: .hearts, rank: .queen),
            Card(suit: .diamonds, rank: .queen),
            Card(suit: .clubs, rank: .queen),
            Card(suit: .spades, rank: .jack),
            Card(suit: .hearts, rank: .ten)
        ]
        
        let threeOfAKindHand = Hand(cards: threeOfAKindCards)
        #expect(threeOfAKindHand.payout == 3) // Should be 3 according to 9/5 pay table
        #expect(threeOfAKindHand.name == "Three of a Kind")
    }
    
    @Test func testTwoPairPayout() throws {
        // Create a two pair hand
        let twoPairCards = [
            Card(suit: .hearts, rank: .jack),
            Card(suit: .diamonds, rank: .jack),
            Card(suit: .clubs, rank: .four),
            Card(suit: .spades, rank: .four),
            Card(suit: .hearts, rank: .ace)
        ]
        
        let twoPairHand = Hand(cards: twoPairCards)
        #expect(twoPairHand.payout == 2) // Should be 2 according to 9/5 pay table
        #expect(twoPairHand.name == "Two Pair")
    }
    
    @Test func testJacksOrBetterPayout() throws {
        // Create a jacks or better hand
        let jacksOrBetterCards = [
            Card(suit: .hearts, rank: .jack),
            Card(suit: .diamonds, rank: .jack),
            Card(suit: .clubs, rank: .seven),
            Card(suit: .spades, rank: .four),
            Card(suit: .hearts, rank: .three)
        ]
        
        let jacksOrBetterHand = Hand(cards: jacksOrBetterCards)
        #expect(jacksOrBetterHand.payout == 1) // Should be 1 according to 9/5 pay table
        #expect(jacksOrBetterHand.name == "Jacks or Better")
    }
    
    @Test func testLowPairNoPayout() throws {
        // Create a hand with a low pair (doesn't qualify for payout)
        let lowPairCards = [
            Card(suit: .hearts, rank: .nine),
            Card(suit: .diamonds, rank: .nine),
            Card(suit: .clubs, rank: .seven),
            Card(suit: .spades, rank: .four),
            Card(suit: .hearts, rank: .three)
        ]
        
        let lowPairHand = Hand(cards: lowPairCards)
        #expect(lowPairHand.payout == 0) // Low pairs don't qualify
        #expect(lowPairHand.name == "No Pay")
    }
    
    @Test func testNoPayHand() throws {
        // Create a hand with no paying combination
        let noPayCards = [
            Card(suit: .hearts, rank: .nine),
            Card(suit: .diamonds, rank: .seven),
            Card(suit: .clubs, rank: .five),
            Card(suit: .spades, rank: .three),
            Card(suit: .hearts, rank: .two)
        ]
        
        let noPayHand = Hand(cards: noPayCards)
        #expect(noPayHand.payout == 0) // Should be 0 for no paying hand
        #expect(noPayHand.name == "No Pay")
    }
    
    @Test func testIsStraightFunction() throws {
        // Test straight with Ace low (A, 2, 3, 4, 5)
        let aceLowRanks: [Rank] = [.ace, .two, .three, .four, .five]
        let sortedAceLowRanks = aceLowRanks.sorted { $0.value < $1.value }
        #expect(Hand.isStraight(sortedAceLowRanks) == true)
        
        // Test regular straight (10, J, Q, K, A)
        let royalRanks: [Rank] = [.ten, .jack, .queen, .king, .ace]
        let sortedRoyalRanks = royalRanks.sorted { $0.value < $1.value }
        #expect(Hand.isStraight(sortedRoyalRanks) == true)
        
        // Test non-straight
        let nonStraightRanks: [Rank] = [.ace, .two, .four, .six, .eight]
        let sortedNonStraightRanks = nonStraightRanks.sorted { $0.value < $1.value }
        #expect(Hand.isStraight(sortedNonStraightRanks) == false)
        
        // Test another straight (7, 8, 9, 10, J)
        let middleStraightRanks: [Rank] = [.seven, .eight, .nine, .ten, .jack]
        let sortedMiddleStraightRanks = middleStraightRanks.sorted { $0.value < $1.value }
        #expect(Hand.isStraight(sortedMiddleStraightRanks) == true)
    }
    
    @Test func testRankCountsFunction() throws {
        // Test a hand with a pair
        let pairCards = [
            Card(suit: .hearts, rank: .ace),
            Card(suit: .diamonds, rank: .ace),
            Card(suit: .clubs, rank: .king),
            Card(suit: .spades, rank: .queen),
            Card(suit: .hearts, rank: .jack)
        ]
        
        let rankCounts = Hand.rankCounts(pairCards)
        #expect(rankCounts[.ace] == 2)
        #expect(rankCounts[.king] == 1)
        #expect(rankCounts[.queen] == 1)
        #expect(rankCounts[.jack] == 1)
        
        // Test a hand with three of a kind
        let threeOfAKindCards = [
            Card(suit: .hearts, rank: .king),
            Card(suit: .diamonds, rank: .king),
            Card(suit: .clubs, rank: .king),
            Card(suit: .spades, rank: .queen),
            Card(suit: .hearts, rank: .jack)
        ]
        
        let threeOfAKindRankCounts = Hand.rankCounts(threeOfAKindCards)
        #expect(threeOfAKindRankCounts[.king] == 3)
        #expect(threeOfAKindRankCounts[.queen] == 1)
        #expect(threeOfAKindRankCounts[.jack] == 1)
        
        // Test a hand with two pair
        let twoPairCards = [
            Card(suit: .hearts, rank: .queen),
            Card(suit: .diamonds, rank: .queen),
            Card(suit: .clubs, rank: .jack),
            Card(suit: .spades, rank: .jack),
            Card(suit: .hearts, rank: .ten)
        ]
        
        let twoPairRankCounts = Hand.rankCounts(twoPairCards)
        #expect(twoPairRankCounts[.queen] == 2)
        #expect(twoPairRankCounts[.jack] == 2)
        #expect(twoPairRankCounts[.ten] == 1)
    }
    
    @Test func testIsFlushFunction() throws {
        // Test flush
        let flushCards = [
            Card(suit: .hearts, rank: .ace),
            Card(suit: .hearts, rank: .king),
            Card(suit: .hearts, rank: .queen)
        ]
        #expect(Hand.isFlush(flushCards) == true)
        
        // Test non-flush
        let nonFlushCards = [
            Card(suit: .hearts, rank: .ace),
            Card(suit: .diamonds, rank: .king),
            Card(suit: .hearts, rank: .queen)
        ]
        #expect(Hand.isFlush(nonFlushCards) == false)
        
        // Test flush with 5 cards
        let fiveFlushCards = [
            Card(suit: .spades, rank: .ace),
            Card(suit: .spades, rank: .king),
            Card(suit: .spades, rank: .queen),
            Card(suit: .spades, rank: .jack),
            Card(suit: .spades, rank: .ten)
        ]
        #expect(Hand.isFlush(fiveFlushCards) == true)
    }
    
    @Test func testEvaluatePartialHand() throws {
        // Test a partial hand (3 cards)
        let partialCards = [
            Card(suit: .hearts, rank: .ace),
            Card(suit: .hearts, rank: .king),
            Card(suit: .hearts, rank: .queen)
        ]
        
        let evaluation = Hand.evaluatePartialHand(partialCards)
        #expect(evaluation.isFlush == true)
        #expect(evaluation.isStraight == false) // Not enough cards for straight check
        #expect(evaluation.rankCounts[.ace] == 1)
        #expect(evaluation.rankCounts[.king] == 1)
        #expect(evaluation.rankCounts[.queen] == 1)
        #expect(evaluation.maxOfAKind == 1)
        
        // Test empty hand
        let emptyEvaluation = Hand.evaluatePartialHand([])
        #expect(emptyEvaluation.isFlush == false)
        #expect(emptyEvaluation.isStraight == false)
        #expect(emptyEvaluation.rankCounts.isEmpty == true)
        #expect(emptyEvaluation.maxOfAKind == 0)
        
        // Test single card
        let singleCard = [Card(suit: .clubs, rank: .seven)]
        let singleEvaluation = Hand.evaluatePartialHand(singleCard)
        #expect(singleEvaluation.isFlush == true) // Single card is considered flush
        #expect(singleEvaluation.isStraight == false)
        #expect(singleEvaluation.rankCounts[.seven] == 1)
        #expect(singleEvaluation.maxOfAKind == 1)
    }
    
    @Test func testHandWithEdgeCaseStraights() throws {
        // Test Ace-low straight (A, 2, 3, 4, 5)
        let aceLowStraightCards = [
            Card(suit: .hearts, rank: .ace),
            Card(suit: .diamonds, rank: .two),
            Card(suit: .clubs, rank: .three),
            Card(suit: .spades, rank: .four),
            Card(suit: .hearts, rank: .five)
        ]
        
        let aceLowStraightHand = Hand(cards: aceLowStraightCards)
        #expect(aceLowStraightHand.name == "Straight")
        #expect(aceLowStraightHand.payout == 4)
        
        // Test wheel straight (5, 4, 3, 2, A) - same as above but different order
        let wheelStraightCards = [
            Card(suit: .hearts, rank: .five),
            Card(suit: .diamonds, rank: .four),
            Card(suit: .clubs, rank: .three),
            Card(suit: .spades, rank: .two),
            Card(suit: .hearts, rank: .ace)
        ]
        
        let wheelStraightHand = Hand(cards: wheelStraightCards)
        #expect(wheelStraightHand.name == "Straight")
        #expect(wheelStraightHand.payout == 4)
    }
    
    @Test func testHandWithAllRanksAndSuits() throws {
        // Test that all card combinations are handled properly
        for suit in Suit.allCases {
            for rank in Rank.allCases {
                // Just verify we can create cards without crashing
                let card = Card(suit: suit, rank: rank)
                #expect(card.suit == suit)
                #expect(card.rank == rank)
            }
        }
    }
    
    @Test func testHandEvaluationEdgeCases() throws {
        // Test hand with all cards the same (impossible in real game but should handle gracefully)
        let sameCards = [
            Card(suit: .hearts, rank: .ace),
            Card(suit: .hearts, rank: .ace),
            Card(suit: .hearts, rank: .ace),
            Card(suit: .hearts, rank: .ace),
            Card(suit: .hearts, rank: .ace)
        ]
        
        let sameHand = Hand(cards: sameCards)
        #expect(sameHand.name == "Four of a Kind") // Actually five of a kind, but evaluates as four of a kind
        #expect(sameHand.payout == 25)
        
        // Test hand with all different ranks but same suit (flush)
        let flushDifferentRanks = [
            Card(suit: .diamonds, rank: .two),
            Card(suit: .diamonds, rank: .four),
            Card(suit: .diamonds, rank: .six),
            Card(suit: .diamonds, rank: .eight),
            Card(suit: .diamonds, rank: .ten)
        ]
        
        let flushHand = Hand(cards: flushDifferentRanks)
        #expect(flushHand.name == "Flush")
        #expect(flushHand.payout == 5)
    }
}
