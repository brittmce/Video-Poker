import Foundation

/// Represents a poker hand with 5 cards
struct Hand {
    /// The cards in the hand
    let cards: [Card]
    
    /// The name of the hand (e.g., "Royal Flush", "Two Pair")
    let name: String
    
    /// The payout multiplier for the hand based on the 9/5 Jacks or Better pay table
    let payout: Int
    
    /// Creates a hand with the specified cards
    /// - Parameter cards: An array of 5 cards
    init(cards: [Card]) {
        guard cards.count == 5 else {
            fatalError("A poker hand must contain exactly 5 cards")
        }
        
        self.cards = cards
        (self.name, self.payout) = Hand.evaluateHand(cards)
    }
    
    /// Evaluates a hand and returns its name and payout
    /// - Parameter cards: An array of 5 cards to evaluate
    /// - Returns: A tuple containing the hand name and payout
    private static func evaluateHand(_ cards: [Card]) -> (String, Int) {
        let ranks = cards.map { $0.rank }.sorted { $0.value < $1.value }
        let suits = cards.map { $0.suit }
        
        let isFlush = suits.allSatisfy { $0 == suits[0] }
        
        // Check for straight
        let isStraight = Hand.isStraight(ranks)
        
        // Count occurrences of each rank
        var rankCounts: [Rank: Int] = [:]
        for rank in ranks {
            rankCounts[rank, default: 0] += 1
        }
        
        let counts = Array(rankCounts.values).sorted(by: >)
        
        // Royal flush
        if isFlush && isStraight && ranks.last == .ace && ranks.first == .ten {
            return ("Royal Flush", 800)
        }
        
        // Straight flush
        if isFlush && isStraight {
            return ("Straight Flush", 50)
        }
        
        // Four of a kind
        if counts.first == 4 {
            return ("Four of a Kind", 25)
        }
        
        // Full house
        if counts == [3, 2] {
            return ("Full House", 9)
        }
        
        // Flush
        if isFlush {
            return ("Flush", 5)
        }
        
        // Straight
        if isStraight {
            return ("Straight", 4)
        }
        
        // Three of a kind
        if counts.first == 3 {
            return ("Three of a Kind", 3)
        }
        
        // Two pair
        if counts.prefix(2) == [2, 2] {
            return ("Two Pair", 2)
        }
        
        // Jacks or better
        let jacksOrBetter = rankCounts.filter { $0.key.value >= 11 && $0.value == 2 } // J, Q, K, A
        if !jacksOrBetter.isEmpty {
            return ("Jacks or Better", 1)
        }
        
        // No paying hand
        return ("No Pay", 0)
    }
    
    /// Optimized hand evaluation for use in EV calculations
    /// This version avoids string creation and sorting when possible
    static func evaluateHandForEV(_ cards: [Card]) -> Int {
        // Pre-allocated arrays for better performance
        let ranks = cards.map { $0.rank }
        let suits = cards.map { $0.suit }
        
        let isFlush = suits.allSatisfy { $0 == suits[0] }
        
        // For performance, we'll use a more direct approach for counting
        // Using a fixed-size array for better cache performance
        var counts = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0] // Index 0 unused, 1-14 for card ranks
        for rank in ranks {
            counts[rank.value] += 1
        }
        
        // Find the highest count and if there's a pair
        var maxCount = 0
        var pairCount = 0
        var hasHighPair = false
        
        // More efficient loop unrolling with early exit conditions
        // Process in order of likelihood to short-circuit faster
        
        // Check for four of a kind first (highest payout)
        if counts[1] == 4 { return 25 }
        if counts[2] == 4 { return 25 }
        if counts[3] == 4 { return 25 }
        if counts[4] == 4 { return 25 }
        if counts[5] == 4 { return 25 }
        if counts[6] == 4 { return 25 }
        if counts[7] == 4 { return 25 }
        if counts[8] == 4 { return 25 }
        if counts[9] == 4 { return 25 }
        if counts[10] == 4 { return 25 }
        if counts[11] == 4 { return 25 }
        if counts[12] == 4 { return 25 }
        if counts[13] == 4 { return 25 }
        if counts[14] == 4 { return 25 }
        
        // Update maxCount as we go
        if counts[1] > maxCount { maxCount = counts[1] }
        if counts[2] > maxCount { maxCount = counts[2] }
        if counts[3] > maxCount { maxCount = counts[3] }
        if counts[4] > maxCount { maxCount = counts[4] }
        if counts[5] > maxCount { maxCount = counts[5] }
        if counts[6] > maxCount { maxCount = counts[6] }
        if counts[7] > maxCount { maxCount = counts[7] }
        if counts[8] > maxCount { maxCount = counts[8] }
        if counts[9] > maxCount { maxCount = counts[9] }
        if counts[10] > maxCount { maxCount = counts[10] }
        if counts[11] > maxCount { maxCount = counts[11] }
        if counts[11] == 2 { pairCount += 1; hasHighPair = true }
        if counts[12] > maxCount { maxCount = counts[12] }
        if counts[12] == 2 { pairCount += 1; hasHighPair = true }
        if counts[13] > maxCount { maxCount = counts[13] }
        if counts[13] == 2 { pairCount += 1; hasHighPair = true }
        if counts[14] > maxCount { maxCount = counts[14] }
        if counts[14] == 2 { pairCount += 1; hasHighPair = true }
        
        // Handle low pairs (2-10)
        if counts[2] == 2 { pairCount += 1 }
        if counts[3] == 2 { pairCount += 1 }
        if counts[4] == 2 { pairCount += 1 }
        if counts[5] == 2 { pairCount += 1 }
        if counts[6] == 2 { pairCount += 1 }
        if counts[7] == 2 { pairCount += 1 }
        if counts[8] == 2 { pairCount += 1 }
        if counts[9] == 2 { pairCount += 1 }
        if counts[10] == 2 { pairCount += 1 }
        
        // Early exit for royal flush (highest payout)
        if isFlush {
            // Check for royal flush without sorting
            if counts[10] == 1 && counts[11] == 1 && counts[12] == 1 && counts[13] == 1 && counts[14] == 1 {
                return 800
            }
        }
        
        // Check for straight (more efficient for 5 cards)
        let sortedRanks = ranks.map { $0.value }.sorted()
        let isStraight = Hand.isStraightPreSorted(sortedRanks)
        
        // Royal flush
        if isFlush && isStraight && sortedRanks.last == 14 && sortedRanks.first == 10 {
            return 800
        }
        
        // Straight flush
        if isFlush && isStraight {
            return 50
        }
        
        // Four of a kind (already checked above, but keeping for completeness)
        if maxCount == 4 {
            return 25
        }
        
        // Full house
        if maxCount == 3 && pairCount >= 1 {
            return 9
        }
        
        // Flush
        if isFlush {
            return 5
        }
        
        // Straight
        if isStraight {
            return 4
        }
        
        // Three of a kind
        if maxCount == 3 {
            return 3
        }
        
        // Two pair
        if pairCount >= 2 {
            return 2
        }
        
        // Jacks or better
        if hasHighPair {
            return 1
        }
        
        // No paying hand
        return 0
    }
    
    // Cache for hand evaluations to avoid recomputing the same hands
    private static var evEvaluationCache: [UInt64: Int] = [:]
    private static let evCacheLimit = 10000
    
    /// Cached version of evaluateHandForEV
    static func evaluateHandForEVCached(_ cards: [Card]) -> Int {
        // Deterministic bit packing for an exact cache key:
        // each card uses 6 bits -> 4 bits rank (2...14) + 2 bits suit code.
        var cacheKey: UInt64 = 0
        for card in cards {
            let suitBits: UInt64
            switch card.suit {
            case .hearts: suitBits = 0
            case .diamonds: suitBits = 1
            case .clubs: suitBits = 2
            case .spades: suitBits = 3
            }
            let packed = (UInt64(card.rank.value) << 2) | suitBits
            cacheKey = (cacheKey << 6) | packed
        }

        if let cached = evEvaluationCache[cacheKey] {
            return cached
        }
        
        let result = evaluateHandForEV(cards)
        
        // Limit cache size to prevent memory issues
        if evEvaluationCache.count < evCacheLimit {
            evEvaluationCache[cacheKey] = result
        }
        
        return result
    }
    
    /// Helper method for checking straight on pre-sorted ranks
    private static func isStraightPreSorted(_ ranks: [Int]) -> Bool {
        // Special case for Ace-low straight (A, 2, 3, 4, 5)
        if ranks == [2, 3, 4, 5, 14] {
            return true
        }
        
        // Check if consecutive
        for i in 1..<ranks.count {
            if ranks[i] != ranks[i-1] + 1 {
                return false
            }
        }
        
        return true
    }
    
    /// Checks if the ranks form a straight
    /// - Parameter ranks: An array of sorted ranks
    /// - Returns: True if the ranks form a straight
    ///
    /// This method is accessible for expected value calculations to determine
    /// if a set of cards forms a straight.
    static func isStraight(_ ranks: [Rank]) -> Bool {
        // Special case for Ace-low straight (A, 2, 3, 4, 5)
        if ranks.map({ $0.value }) == [2, 3, 4, 5, 14] {
            return true
        }
        
        // Check if consecutive
        for i in 1..<ranks.count {
            if ranks[i].value != ranks[i-1].value + 1 {
                return false
            }
        }
        
        return true
    }
    
    /// Returns the count of each rank in the hand
    /// - Parameter cards: An array of cards to evaluate
    /// - Returns: A dictionary mapping each rank to its count
    ///
    /// This method is useful for expected value calculations when analyzing partial hands.
    static func rankCounts(_ cards: [Card]) -> [Rank: Int] {
        var counts: [Rank: Int] = [:]
        for card in cards {
            counts[card.rank, default: 0] += 1
        }
        return counts
    }
    
    /// Checks if all cards in the hand have the same suit
    /// - Parameter cards: An array of cards to evaluate
    /// - Returns: True if all cards have the same suit
    ///
    /// This method is useful for expected value calculations when analyzing partial hands.
    static func isFlush(_ cards: [Card]) -> Bool {
        guard let firstSuit = cards.first?.suit else { return true }
        return cards.allSatisfy { $0.suit == firstSuit }
    }
    
    /// Evaluates a partial hand (less than 5 cards) and returns basic characteristics
    /// - Parameter cards: An array of cards to evaluate (0-5 cards)
    /// - Returns: A tuple containing information about the partial hand
    ///
    /// This method is specifically designed for expected value calculations when analyzing
    /// potential outcomes of drawing cards. It provides basic information about a partial
    /// hand that can be used to calculate probabilities of making specific hands.
    static func evaluatePartialHand(_ cards: [Card]) -> (isFlush: Bool, isStraight: Bool, rankCounts: [Rank: Int], maxOfAKind: Int) {
        guard !cards.isEmpty else {
            return (false, false, [:], 0)
        }
        
        let isFlush = Hand.isFlush(cards)
        let ranks = cards.map { $0.rank }
        let rankCounts = Hand.rankCounts(cards)
        let maxOfAKind = rankCounts.values.max() ?? 0
        
        // For straight checking with partial hands, we need a different approach
        let isStraight = cards.count == 5 ? Hand.isStraight(ranks.sorted { $0.value < $1.value }) : false
        
        return (isFlush, isStraight, rankCounts, maxOfAKind)
    }
}
