import Foundation

enum TrainingHandLibrary {
    private static let targetCount = 50
    private static let deck: [Card] = {
        var cards: [Card] = []
        for suit in Suit.allCases {
            for rank in Rank.allCases {
                cards.append(Card(suit: suit, rank: rank))
            }
        }
        return cards
    }()

    private static let allSets: [TrainingDifficulty: [[Card]]] = buildAllSets()

    static func hands(for difficulty: TrainingDifficulty) -> [[Card]] {
        allSets[difficulty] ?? []
    }

    private static func buildAllSets() -> [TrainingDifficulty: [[Card]]] {
        var rng = LCG(seed: 0xC0FFEE1234ABCDEF)

        var beginner: [[Card]] = []
        var intermediate: [[Card]] = []
        var advanced: [[Card]] = []

        var seen = Set<String>()
        var guardCounter = 0

        while (beginner.count < targetCount || intermediate.count < targetCount || advanced.count < targetCount) && guardCounter < 600_000 {
            guardCounter += 1
            let hand = randomHand(using: &rng)
            let key = canonicalKey(for: hand)
            if seen.contains(key) { continue }

            if isBeginner(hand) {
                if beginner.count < targetCount {
                    beginner.append(hand)
                    seen.insert(key)
                }
                continue
            }

            if isIntermediate(hand) {
                if intermediate.count < targetCount {
                    intermediate.append(hand)
                    seen.insert(key)
                }
                continue
            }

            if advanced.count < targetCount {
                advanced.append(hand)
                seen.insert(key)
            }
        }

        if beginner.count < targetCount || intermediate.count < targetCount || advanced.count < targetCount {
            var idx = 0
            while (beginner.count < targetCount || intermediate.count < targetCount || advanced.count < targetCount) && idx < deck.count {
                let hand = fallbackHand(offset: idx)
                idx += 1
                let key = canonicalKey(for: hand)
                if seen.contains(key) { continue }
                if beginner.count < targetCount {
                    beginner.append(hand)
                    seen.insert(key)
                } else if intermediate.count < targetCount {
                    intermediate.append(hand)
                    seen.insert(key)
                } else if advanced.count < targetCount {
                    advanced.append(hand)
                    seen.insert(key)
                }
            }
        }

        return [
            .beginner: Array(beginner.prefix(targetCount)),
            .intermediate: Array(intermediate.prefix(targetCount)),
            .advanced: Array(advanced.prefix(targetCount))
        ]
    }

    private static func randomHand(using rng: inout LCG) -> [Card] {
        var indices = Set<Int>()
        while indices.count < 5 {
            indices.insert(Int(rng.next() % UInt64(deck.count)))
        }
        return indices.map { deck[$0] }
    }

    private static func fallbackHand(offset: Int) -> [Card] {
        var cards: [Card] = []
        var used = Set<Int>()
        var cursor = offset
        while cards.count < 5 {
            let idx = (cursor * 7 + cards.count * 13) % deck.count
            cursor += 1
            if used.insert(idx).inserted {
                cards.append(deck[idx])
            }
        }
        return cards
    }

    private static func canonicalKey(for hand: [Card]) -> String {
        hand
            .map { card in "\(card.rank.value)\(card.suit.symbol)" }
            .sorted()
            .joined(separator: "-")
    }

    private static func isBeginner(_ hand: [Card]) -> Bool {
        if hasPair(hand) { return true }
        if hasFourToRoyal(hand) { return true }
        if hasNToFlush(hand, n: 4) { return true }
        if hasOpenEndedFourToStraight(hand) { return true }
        return false
    }

    private static func isIntermediate(_ hand: [Card]) -> Bool {
        if hasThreeToRoyal(hand) { return true }
        if hasNToFlush(hand, n: 3) && highCardCount(hand) >= 1 { return true }
        if highCardCount(hand) >= 2 { return true }
        if hasInsideFourToStraight(hand) { return true }
        return false
    }

    private static func hasPair(_ hand: [Card]) -> Bool {
        var counts: [Int: Int] = [:]
        for card in hand {
            counts[card.rank.value, default: 0] += 1
        }
        return counts.values.contains { $0 >= 2 }
    }

    private static func highCardCount(_ hand: [Card]) -> Int {
        hand.filter { $0.rank.value >= 11 }.count
    }

    private static func hasNToFlush(_ hand: [Card], n: Int) -> Bool {
        var suitCounts: [Suit: Int] = [:]
        for card in hand {
            suitCounts[card.suit, default: 0] += 1
        }
        return suitCounts.values.contains { $0 >= n }
    }

    private static func hasFourToRoyal(_ hand: [Card]) -> Bool {
        for suit in Suit.allCases {
            let suitedRanks = Set(hand.filter { $0.suit == suit }.map { $0.rank.value })
            let royal = Set([10, 11, 12, 13, 14])
            if suitedRanks.intersection(royal).count >= 4 {
                return true
            }
        }
        return false
    }

    private static func hasThreeToRoyal(_ hand: [Card]) -> Bool {
        for suit in Suit.allCases {
            let suitedRanks = Set(hand.filter { $0.suit == suit }.map { $0.rank.value })
            let royal = Set([10, 11, 12, 13, 14])
            if suitedRanks.intersection(royal).count >= 3 {
                return true
            }
        }
        return false
    }

    private static func hasOpenEndedFourToStraight(_ hand: [Card]) -> Bool {
        let ranks = Array(Set(hand.map { $0.rank.value })).sorted()
        guard ranks.count >= 4 else { return false }

        for i in 0...(ranks.count - 4) {
            let window = Array(ranks[i..<(i + 4)])
            if window[3] - window[0] == 3 {
                return true
            }
        }

        return false
    }

    private static func hasInsideFourToStraight(_ hand: [Card]) -> Bool {
        let ranks = Array(Set(hand.map { $0.rank.value })).sorted()
        guard ranks.count >= 4 else { return false }

        for i in 0...(ranks.count - 4) {
            let window = Array(ranks[i..<(i + 4)])
            let span = window[3] - window[0]
            if span == 4 && !hasOpenEndedFourToStraight(hand) {
                return true
            }
        }
        return false
    }
}

private struct LCG {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state = 6364136223846793005 &* state &+ 1442695040888963407
        return state
    }
}
