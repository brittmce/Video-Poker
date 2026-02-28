import Foundation

enum ExpectedValueError: Error, LocalizedError {
    case invalidHandSize
    case invalidHoldCombination
    var errorDescription: String? {
        switch self {
        case .invalidHandSize: return "Invalid hand size. Expected 5 cards."
        case .invalidHoldCombination: return "Invalid hold combination."
        }
    }
}

class ExpectedValueCalculator {
    private var evCache: [String: Double] = [:]
    private let allCards: [Card]
    private var templateCache: [TemplateKey: [String: Double]] = [:]
    private static let sharedPrecomputedLookup: PrecomputedLookupTable? = PrecomputedLookupTable()
    private static let sharedSubsetAggregateTable: SubsetAggregateTable? = SubsetAggregateTable()
    private static var didLogEngineStatus = false
    private static let engineLogLock = NSLock()
    private var lookupHitCount: Int = 0
    private var fallbackCount: Int = 0
    
    // Pre-computed combination counts for faster lookup
    private let combinationCounts: [Int: Double] = [1: 47, 2: 1081, 3: 16215, 4: 178365]
    private var paytable: Paytable
    private let outcomeOrder: [String: Int] = [
        "Royal Flush": 1,
        "Straight Flush": 2,
        "Four of a Kind": 3,
        "Full House": 4,
        "Flush": 5,
        "Straight": 6,
        "Three of a Kind": 7,
        "Two Pair": 8,
        "Jacks or Better": 9,
        "No Pay": 10
    ]
    private let winningOutcomeNames = [
        "Royal Flush",
        "Straight Flush",
        "Four of a Kind",
        "Full House",
        "Flush",
        "Straight",
        "Three of a Kind",
        "Two Pair",
        "Jacks or Better"
    ]
    private let allOutcomeNames = [
        "Royal Flush",
        "Straight Flush",
        "Four of a Kind",
        "Full House",
        "Flush",
        "Straight",
        "Three of a Kind",
        "Two Pair",
        "Jacks or Better",
        "No Pay"
    ]
    // Precomputed from the canonical discard-all scenario in `canonicalScenario(for: .discardAll)`.
    // This removes the 1,533,939-combination cold-start enumeration on first use.
    private let discardAllTemplateProbabilities: [String: Double] = [
        "Royal Flush": 0.000001955749,
        "Straight Flush": 0.000010430662,
        "Four of a Kind": 0.000224259244,
        "Full House": 0.001384670446,
        "Flush": 0.001837752349,
        "Straight": 0.003680068112,
        "Three of a Kind": 0.020536670624,
        "Two Pair": 0.046808901788,
        "Jacks or Better": 0.139280636323,
        "No Pay": 0.786234654703
    ]

    private enum TemplateKind: String {
        case discardAll
        case singleCard
        case lowPair
        case highPair
        case twoPair
        case threeOfAKind
        case fourToFlushGeneric
        case fourToRoyal
        case fourToStraightFlush
    }

    private struct TemplateKey: Hashable {
        let kind: TemplateKind
        /// Optional variant discriminator (for example, held rank).
        let variant: Int
    }
    
    init(paytable: Paytable = .defaultPaytable) {
        var cards: [Card] = []
        for suit in Suit.allCases {
            for rank in Rank.allCases {
                cards.append(Card(suit: suit, rank: rank))
            }
        }
        self.allCards = cards
        self.paytable = paytable
    }

    static func prewarmResources() {
        _ = sharedSubsetAggregateTable
        _ = sharedPrecomputedLookup
    }

    /// Clears the internal EV cache (used by tests)
    func clearCache() {
        evCache.removeAll()
        templateCache.removeAll()
        // Hand.evEvaluationCache is private, so we can't clear it directly
        // The cache will automatically limit itself to evCacheLimit entries
    }

    func setPaytable(_ paytable: Paytable) {
        guard self.paytable != paytable else { return }
        self.paytable = paytable
        clearCache()
    }

    func findOptimalHold(for hand: [Card]) throws -> (hold: [Bool], expectedValue: Double) {
        let result = try analyzeHand(for: hand)
        return (hold: result.hold, expectedValue: result.expectedValue)
    }

    /// Analyzes a hand and returns the optimal hold along with any computed EVs per hold mask.
    /// - Returns: The optimal hold, its EV, and a dictionary of computed EVs keyed by hold mask.
    func analyzeHand(for hand: [Card]) throws -> (hold: [Bool], expectedValue: Double, evByMask: [Int: Double]) {
        guard hand.count == 5 else { throw ExpectedValueError.invalidHandSize }
        logEngineStatusIfNeeded()

        if Self.sharedSubsetAggregateTable != nil {
            var bestMask = 0
            var bestEV = -Double.greatestFiniteMagnitude
            var evByMask: [Int: Double] = [:]

            for mask in 0..<32 {
                let hold = convertToBooleanArray(value: mask, width: 5)
                let ev = try calculateExpectedValue(for: hand, heldCards: hold)
                evByMask[mask] = ev
                if ev > bestEV {
                    bestEV = ev
                    bestMask = mask
                }
            }

            return (
                hold: convertToBooleanArray(value: bestMask, width: 5),
                expectedValue: bestEV,
                evByMask: evByMask
            )
        }

        if paytable.id == Paytable.nineFive.id,
           let lookup = Self.sharedPrecomputedLookup,
           let record = lookup.lookup(hand: hand) {
            #if DEBUG
            lookupHitCount += 1
            if lookupHitCount == 1 || lookupHitCount % 25 == 0 {
                print("[EV] Lookup hit count: \(lookupHitCount) (fallbacks: \(fallbackCount))")
            }
            #endif
            let mask = PrecomputedLookupTable.holdMask(from: record.hold)
            return (hold: record.hold, expectedValue: record.expectedValue, evByMask: [mask: record.expectedValue])
        }
        #if DEBUG
        fallbackCount += 1
        if fallbackCount == 1 || fallbackCount % 10 == 0 {
            print("[EV] Runtime fallback count: \(fallbackCount) (lookup hits: \(lookupHitCount))")
        }
        #endif
        
        var bestHold: [Bool] = [false, false, false, false, false]
        var bestEV: Double = -1.0
        var evByMask: [Int: Double] = [:]

        // 1. Calculate Discard All (Draw 5) first as our baseline
        let discardAllEV = expectedValue(from: discardAllTemplateProbabilities, betMultiplier: 5)
        bestEV = discardAllEV
        evByMask[0] = discardAllEV
        
        for i in 1..<32 { // Start from 1 because we already handled 0 (discard all)
            let holdCombination = convertToBooleanArray(value: i, width: 5)

            let ev = try calculateExpectedValue(for: hand, heldCards: holdCombination)
            evByMask[i] = ev

            if ev > bestEV {
                bestEV = ev
                bestHold = holdCombination
            }
        }
        return (hold: bestHold, expectedValue: bestEV, evByMask: evByMask)
    }

    func calculateExpectedValueForUserChoice(for hand: [Card], userHold: [Bool]) throws -> Double {
        return try calculateExpectedValue(for: hand, heldCards: userHold)
    }

    func calculateExpectedValue(for hand: [Card], heldCards: [Bool]) throws -> Double {
        logEngineStatusIfNeeded()
        if let counts = exactCountsFromAggregate(hand: hand, heldCards: heldCards) {
            return expectedValueFromCounts(counts, betMultiplier: 5)
        }

        if paytable.id == Paytable.nineFive.id,
           let lookup = Self.sharedPrecomputedLookup,
           let record = lookup.lookup(hand: hand),
           record.hold == heldCards {
            return record.expectedValue
        }

        // Cache by exact hand + exact hold mask to ensure mathematically exact EVs.
        let cacheKey = generateExactCacheKey(hand: hand, heldCards: heldCards)
        if let cached = evCache[cacheKey] { return cached }

        let heldCardsArray = hand.indices.compactMap { heldCards[$0] ? hand[$0] : nil }
        let drawCount = 5 - heldCardsArray.count
        
        if drawCount == 5 { return expectedValue(from: discardAllTemplateProbabilities, betMultiplier: 5) }
        if drawCount == 0 {
            let final = Hand(cards: heldCardsArray)
            let payout = Double(paytable.payoutsByName[final.name] ?? 0)
            return payout * 5.0
        }

        let ev: Double
        if let key = templateKey(for: heldCardsArray, drawCount: drawCount) {
            let probs = templateProbabilities(for: key)
            ev = expectedValue(from: probs, betMultiplier: 5)
        } else {
            let handSet = Set(hand)
            let deck = allCards.filter { !handSet.contains($0) }
            ev = runControlledBruteForce(held: heldCardsArray, deck: deck, drawCount: drawCount)
        }
        evCache[cacheKey] = ev
        return ev
    }

    private func generateExactCacheKey(hand: [Card], heldCards: [Bool]) -> String {
        let handKey = hand.map { "\($0.rank.value)\($0.suit.symbol)" }.joined(separator: ",")
        let holdKey = heldCards.map { $0 ? "1" : "0" }.joined()
        return "\(handKey)|\(holdKey)"
    }

    private func convertToBooleanArray(value: Int, width: Int) -> [Bool] {
        var result: [Bool] = Array(repeating: false, count: width)
        for i in 0..<width {
            if (value & (1 << i)) != 0 { result[width - 1 - i] = true }
        }
        return result
    }

    private func runControlledBruteForce(held: [Card], deck: [Card], drawCount: Int) -> Double {
        var totalPayout = 0.0
        guard let totalCombos = combinationCounts[drawCount] else { return 0.0 }
        
        let deckCount = deck.count
        switch drawCount {
        case 1:
            for i in 0..<deckCount {
                totalPayout += Double(Hand.evaluateHandForEVCached(held + [deck[i]])) * 5.0
            }
        case 2:
            // Pre-allocate array to avoid repeated allocations
            var cards = held
            cards.reserveCapacity(held.count + 2)
            cards.append(contentsOf: [Card](repeating: Card(suit: .hearts, rank: .two), count: 2))
            
            for i in 0..<deckCount {
                cards[held.count] = deck[i]
                for j in (i+1)..<deckCount {
                    cards[held.count + 1] = deck[j]
                    totalPayout += Double(Hand.evaluateHandForEVCached(cards)) * 5.0
                }
            }
        case 3:
            // Pre-allocate array to avoid repeated allocations
            var cards = held
            cards.reserveCapacity(held.count + 3)
            cards.append(contentsOf: [Card](repeating: Card(suit: .hearts, rank: .two), count: 3))

            for i in 0..<deckCount {
                cards[held.count] = deck[i]
                for j in (i+1)..<deckCount {
                    cards[held.count + 1] = deck[j]
                    for k in (j+1)..<deckCount {
                        cards[held.count + 2] = deck[k]
                        totalPayout += Double(Hand.evaluateHandForEVCached(cards)) * 5.0
                    }
                }
            }
        case 4:
            // Pre-allocate array to avoid repeated allocations
            var cards = held
            cards.reserveCapacity(held.count + 4)
            cards.append(contentsOf: [Card](repeating: Card(suit: .hearts, rank: .two), count: 4))

            for i in 0..<deckCount {
                cards[held.count] = deck[i]
                for j in (i+1)..<deckCount {
                    cards[held.count + 1] = deck[j]
                    for k in (j+1)..<deckCount {
                        cards[held.count + 2] = deck[k]
                        for l in (k+1)..<deckCount {
                            cards[held.count + 3] = deck[l]
                            totalPayout += Double(Hand.evaluateHandForEVCached(cards)) * 5.0
                        }
                    }
                }
            }
        default: break
        }
        return totalPayout / totalCombos
    }

    /// Returns a breakdown of possible final hand names, their probabilities,
    /// and their contribution to expected payout (using a bet multiplier).
    func distributionFor(hand: [Card], heldCards: [Bool], betMultiplier: Int = 5) throws -> [(name: String, probability: Double, contribution: Double)] {
        guard hand.count == 5 else { throw ExpectedValueError.invalidHandSize }

        if let counts = exactCountsFromAggregate(hand: hand, heldCards: heldCards) {
            let total = Double(counts.reduce(0, +))
            guard total > 0 else { return [] }
            var results: [(name: String, probability: Double, contribution: Double)] = []
            for (idx, name) in allOutcomeNames.enumerated() {
                let c = counts[idx]
                if c == 0 { continue }
                let prob = Double(c) / total
                let payout = paytable.payoutsByName[name] ?? 0
                let contribution = prob * Double(payout) * Double(betMultiplier)
                results.append((name: name, probability: prob, contribution: contribution))
            }
            results.sort { outcomeOrder[$0.name] ?? Int.max < outcomeOrder[$1.name] ?? Int.max }
            return results
        }

        // Fast path: use precomputed frequencies when this is the optimal hold from the lookup table.
        if paytable.id == Paytable.nineFive.id,
           let lookup = Self.sharedPrecomputedLookup,
           let record = lookup.lookup(hand: hand),
           record.hold == heldCards,
           let winningFrequencies = record.winningFrequencies,
           winningFrequencies.count == winningOutcomeNames.count {
            let drawCount = 5 - heldCards.filter { $0 }.count
            let totalCombos = Double(nChooseK(47, drawCount))
            guard totalCombos > 0 else { return [] }

            var results: [(name: String, probability: Double, contribution: Double)] = []
            var winningTotal: UInt32 = 0
            for (index, name) in winningOutcomeNames.enumerated() {
                let freq = winningFrequencies[index]
                winningTotal += freq
                if freq == 0 { continue }
                let prob = Double(freq) / totalCombos
                let payout = paytable.payoutsByName[name] ?? 0
                let contribution = prob * Double(payout) * Double(betMultiplier)
                results.append((name: name, probability: prob, contribution: contribution))
            }

            let noPayFreq = max(0, Int(totalCombos.rounded()) - Int(winningTotal))
            if noPayFreq > 0 {
                results.append((name: "No Pay", probability: Double(noPayFreq) / totalCombos, contribution: 0.0))
            }

            results.sort { outcomeOrder[$0.name] ?? Int.max < outcomeOrder[$1.name] ?? Int.max }
            return results
        }

        let held = hand.indices.compactMap { heldCards[$0] ? hand[$0] : nil }
        let drawCount = 5 - held.count

        // Special cases
        if drawCount == 0 {
            let final = Hand(cards: held)
            let prob = 1.0
            let payout = Double(paytable.payoutsByName[final.name] ?? 0)
            let contribution = payout * Double(betMultiplier) * prob
            return [(final.name, prob, contribution)]
        }

        if let key = templateKey(for: held, drawCount: drawCount) {
            let probs = templateProbabilities(for: key)
            var fastResults: [(name: String, probability: Double, contribution: Double)] = []
            for (name, prob) in probs where prob > 0 {
                let payout = paytable.payoutsByName[name] ?? 0
                let contribution = prob * Double(payout) * Double(betMultiplier)
                fastResults.append((name: name, probability: prob, contribution: contribution))
            }
            fastResults.sort { outcomeOrder[$0.name] ?? Int.max < outcomeOrder[$1.name] ?? Int.max }
            return fastResults
        }

        // Fallback: exact enumeration for patterns without a template.
        return bruteForceDistributionFor(hand: hand, heldCards: heldCards, betMultiplier: betMultiplier)
    }

    /// Exact distribution via full combination enumeration.
    private func bruteForceDistributionFor(
        hand: [Card],
        heldCards: [Bool],
        betMultiplier: Int
    ) -> [(name: String, probability: Double, contribution: Double)] {
        let held = hand.indices.compactMap { heldCards[$0] ? hand[$0] : nil }
        let drawCount = 5 - held.count
        let handSet = Set(hand)
        let deck = allCards.filter { !handSet.contains($0) }

        // Use same combination counts as runControlledBruteForce
        let counts: [Int: Double] = [1: 47, 2: 1081, 3: 16215, 4: 178365, 5: 1533939]
        guard let totalCombos = counts[drawCount] else { return [] }

        var tally: [String: Int] = [:]

        let deckCount = deck.count
        switch drawCount {
        case 1:
            for i in 0..<deckCount {
                let h = Hand(cards: held + [deck[i]])
                tally[h.name, default: 0] += 1
            }
        case 2:
            for i in 0..<deckCount {
                let c1 = deck[i]
                for j in (i+1)..<deckCount {
                    let h = Hand(cards: held + [c1, deck[j]])
                    tally[h.name, default: 0] += 1
                }
            }
        case 3:
            for i in 0..<deckCount {
                let c1 = deck[i]
                for j in (i+1)..<deckCount {
                    let c2 = deck[j]
                    for k in (j+1)..<deckCount {
                        let h = Hand(cards: held + [c1, c2, deck[k]])
                        tally[h.name, default: 0] += 1
                    }
                }
            }
        case 4:
            for i in 0..<deckCount {
                let c1 = deck[i]
                for j in (i+1)..<deckCount {
                    let c2 = deck[j]
                    for k in (j+1)..<deckCount {
                        let c3 = deck[k]
                        for l in (k+1)..<deckCount {
                            let h = Hand(cards: held + [c1, c2, c3, deck[l]])
                            tally[h.name, default: 0] += 1
                        }
                    }
                }
            }
        case 5:
            for i in 0..<deckCount {
                let c1 = deck[i]
                for j in (i+1)..<deckCount {
                    let c2 = deck[j]
                    for k in (j+1)..<deckCount {
                        let c3 = deck[k]
                        for l in (k+1)..<deckCount {
                            let c4 = deck[l]
                            for m in (l+1)..<deckCount {
                                let c5 = deck[m]
                                let h = Hand(cards: [c1, c2, c3, c4, c5])
                                tally[h.name, default: 0] += 1
                            }
                        }
                    }
                }
            }
        default:
            break
        }

        // Convert tally into sorted results
        var results: [(name: String, probability: Double, contribution: Double)] = []
        for (name, count) in tally {
            let prob = Double(count) / totalCombos
            let payout = paytable.payoutsByName[name] ?? 0
            let contribution = prob * Double(payout) * Double(betMultiplier)
            results.append((name: name, probability: prob, contribution: contribution))
        }
        
        // Sort by hand rank (from best to worst)
        results.sort { outcomeOrder[$0.name] ?? Int.max < outcomeOrder[$1.name] ?? Int.max }
        return results
    }

    /// Returns a matching template for the held cards if one is supported by the
    /// fast template library; otherwise returns nil to force exact enumeration.
    private func templateKey(for held: [Card], drawCount: Int) -> TemplateKey? {
        if drawCount == 5 { return TemplateKey(kind: .discardAll, variant: 0) }
        if drawCount == 0 { return nil }

        let rankCounts = Hand.rankCounts(held)
        let counts = rankCounts.values.sorted(by: >)

        if held.count == 1 {
            return TemplateKey(kind: .singleCard, variant: held[0].rank.value)
        }

        if held.count == 2 && counts == [2] {
            let pairRank = rankCounts.first?.key ?? .two
            let isHighPair = pairRank.value >= Rank.jack.value
            return TemplateKey(kind: isHighPair ? .highPair : .lowPair, variant: 0)
        }

        if held.count == 3 && counts == [3] {
            return TemplateKey(kind: .threeOfAKind, variant: 0)
        }

        if held.count == 4 && counts == [2, 2] {
            return TemplateKey(kind: .twoPair, variant: 0)
        }

        if held.count == 4 && Hand.isFlush(held) {
            let rankValues = Set(held.map { $0.rank.value })
            let royalSet: Set<Int> = [10, 11, 12, 13, 14]
            if rankValues.isSubset(of: royalSet) {
                return TemplateKey(kind: .fourToRoyal, variant: 0)
            }

            let sorted = held.map { $0.rank.value }.sorted()
            let isNearStraightFlush = isFourToStraightFlush(sorted)
            return TemplateKey(kind: isNearStraightFlush ? .fourToStraightFlush : .fourToFlushGeneric, variant: 0)
        }

        return nil
    }

    private func isFourToStraightFlush(_ sorted: [Int]) -> Bool {
        guard sorted.count == 4 else { return false }
        // Allow one inside/outside gap over 4-card span; include wheel-like A234.
        if sorted == [2, 3, 4, 14] { return true }
        let span = sorted[3] - sorted[0]
        return span <= 4
    }

    private func expectedValue(from probabilities: [String: Double], betMultiplier: Int) -> Double {
        probabilities.reduce(0.0) { partial, entry in
            let payout = Double(paytable.payoutsByName[entry.key] ?? 0)
            return partial + (entry.value * payout * Double(betMultiplier))
        }
    }

    /// Loads cached template weights or computes them once using exact enumeration
    /// on canonical hands for each template.
    private func templateProbabilities(for key: TemplateKey) -> [String: Double] {
        if let cached = templateCache[key] {
            return cached
        }

        if key.kind == .discardAll {
            templateCache[key] = discardAllTemplateProbabilities
            return discardAllTemplateProbabilities
        }

        let scenario = canonicalScenario(for: key)
        let exact = bruteForceDistributionFor(
            hand: scenario.hand,
            heldCards: scenario.heldMask,
            betMultiplier: 1
        )
        var probs: [String: Double] = [:]
        for item in exact {
            probs[item.name] = item.probability
        }
        templateCache[key] = probs
        return probs
    }

    private func canonicalScenario(for key: TemplateKey) -> (hand: [Card], heldMask: [Bool]) {
        switch key.kind {
        case .discardAll:
            return (
                hand: [
                    Card(suit: .hearts, rank: .two),
                    Card(suit: .diamonds, rank: .five),
                    Card(suit: .clubs, rank: .seven),
                    Card(suit: .spades, rank: .nine),
                    Card(suit: .hearts, rank: .jack)
                ],
                heldMask: [false, false, false, false, false]
            )
        case .singleCard:
            let rank = rankForTemplateValue(key.variant)
            return (
                hand: [
                    Card(suit: .hearts, rank: rank),
                    Card(suit: .diamonds, rank: .two),
                    Card(suit: .clubs, rank: .five),
                    Card(suit: .spades, rank: .eight),
                    Card(suit: .diamonds, rank: .queen)
                ],
                heldMask: [true, false, false, false, false]
            )
        case .lowPair:
            return (
                hand: [
                    Card(suit: .hearts, rank: .five),
                    Card(suit: .spades, rank: .five),
                    Card(suit: .diamonds, rank: .king),
                    Card(suit: .clubs, rank: .three),
                    Card(suit: .spades, rank: .nine)
                ],
                heldMask: [true, true, false, false, false]
            )
        case .highPair:
            return (
                hand: [
                    Card(suit: .hearts, rank: .jack),
                    Card(suit: .spades, rank: .jack),
                    Card(suit: .diamonds, rank: .four),
                    Card(suit: .clubs, rank: .seven),
                    Card(suit: .spades, rank: .nine)
                ],
                heldMask: [true, true, false, false, false]
            )
        case .threeOfAKind:
            return (
                hand: [
                    Card(suit: .hearts, rank: .seven),
                    Card(suit: .spades, rank: .seven),
                    Card(suit: .diamonds, rank: .seven),
                    Card(suit: .clubs, rank: .queen),
                    Card(suit: .spades, rank: .two)
                ],
                heldMask: [true, true, true, false, false]
            )
        case .twoPair:
            return (
                hand: [
                    Card(suit: .hearts, rank: .jack),
                    Card(suit: .spades, rank: .jack),
                    Card(suit: .diamonds, rank: .four),
                    Card(suit: .clubs, rank: .four),
                    Card(suit: .spades, rank: .nine)
                ],
                heldMask: [true, true, true, true, false]
            )
        case .fourToRoyal:
            return (
                hand: [
                    Card(suit: .hearts, rank: .ten),
                    Card(suit: .hearts, rank: .jack),
                    Card(suit: .hearts, rank: .queen),
                    Card(suit: .hearts, rank: .king),
                    Card(suit: .clubs, rank: .three)
                ],
                heldMask: [true, true, true, true, false]
            )
        case .fourToStraightFlush:
            return (
                hand: [
                    Card(suit: .hearts, rank: .five),
                    Card(suit: .hearts, rank: .six),
                    Card(suit: .hearts, rank: .seven),
                    Card(suit: .hearts, rank: .eight),
                    Card(suit: .clubs, rank: .king)
                ],
                heldMask: [true, true, true, true, false]
            )
        case .fourToFlushGeneric:
            return (
                hand: [
                    Card(suit: .hearts, rank: .two),
                    Card(suit: .hearts, rank: .five),
                    Card(suit: .hearts, rank: .nine),
                    Card(suit: .hearts, rank: .king),
                    Card(suit: .clubs, rank: .three)
                ],
                heldMask: [true, true, true, true, false]
            )
        }
    }

    private func rankForTemplateValue(_ value: Int) -> Rank {
        switch value {
        case 2: return .two
        case 3: return .three
        case 4: return .four
        case 5: return .five
        case 6: return .six
        case 7: return .seven
        case 8: return .eight
        case 9: return .nine
        case 10: return .ten
        case 11: return .jack
        case 12: return .queen
        case 13: return .king
        default: return .ace
        }
    }

    private func nChooseK(_ n: Int, _ k: Int) -> Int {
        if k < 0 || n < 0 || k > n { return 0 }
        if k == 0 || k == n { return 1 }
        let kk = min(k, n - k)
        if kk == 0 { return 1 }
        var result = 1
        for i in 1...kk {
            result = (result * (n - kk + i)) / i
        }
        return result
    }

    private func exactCountsFromAggregate(hand: [Card], heldCards: [Bool]) -> [UInt32]? {
        guard let aggregate = Self.sharedSubsetAggregateTable, hand.count == 5, heldCards.count == 5 else { return nil }

        var heldIndices: [Int] = []
        var discardIndices: [Int] = []
        heldIndices.reserveCapacity(5)
        discardIndices.reserveCapacity(5)

        for i in 0..<5 {
            let deckIdx = SubsetAggregateTable.deckIndex(for: hand[i])
            if heldCards[i] {
                heldIndices.append(deckIdx)
            } else {
                discardIndices.append(deckIdx)
            }
        }

        let drawCount = discardIndices.count
        let totalCombos = aggregate.combinations47Choose(drawCount)
        if totalCombos <= 0 { return nil }

        var signed = Array(repeating: Int64(0), count: 9)
        let dCount = discardIndices.count
        let subsetLimit = 1 << dCount

        for sub in 0..<subsetLimit {
            var merged = heldIndices
            if dCount > 0 {
                for j in 0..<dCount where (sub & (1 << j)) != 0 {
                    merged.append(discardIndices[j])
                }
            }
            merged.sort()

            let freq = aggregate.aggregateWinningFreq(forSortedIndices: merged)
            let sign: Int64 = (sub.nonzeroBitCount % 2 == 0) ? 1 : -1
            for i in 0..<9 {
                signed[i] += sign * Int64(freq[i])
            }
        }

        var out = Array(repeating: UInt32(0), count: 10)
        var wins: Int64 = 0
        for i in 0..<9 {
            let v = max(0, signed[i])
            out[i] = UInt32(v)
            wins += v
        }
        out[9] = UInt32(max(0, Int64(totalCombos) - wins))
        return out
    }

    private func expectedValueFromCounts(_ counts: [UInt32], betMultiplier: Int) -> Double {
        let total = Double(counts.reduce(0, +))
        guard total > 0 else { return 0 }
        var weighted = 0.0
        for (idx, name) in allOutcomeNames.enumerated() {
            let payout = Double(paytable.payoutsByName[name] ?? 0)
            weighted += Double(counts[idx]) * payout
        }
        return (weighted / total) * Double(betMultiplier)
    }

    private func logEngineStatusIfNeeded() {
        #if DEBUG
        Self.engineLogLock.lock()
        defer { Self.engineLogLock.unlock() }
        if Self.didLogEngineStatus { return }
        Self.didLogEngineStatus = true

        if let subsetAggregateTable = Self.sharedSubsetAggregateTable {
            print("[EV] Subset aggregate table loaded: \(subsetAggregateTable.loadedResource)")
            print("[EV] Active engine: paytable-agnostic aggregate (exact, instant)")
        } else {
            print("[EV] Subset aggregate table NOT loaded.")
            if let precomputedLookup = Self.sharedPrecomputedLookup {
                print("[EV] Precomputed lookup table loaded: \(precomputedLookup.loadedResource)")
                print("[EV] Active engine: 9/5 strategy lookup (optimal hold only)")
            } else {
                print("[EV] No precomputed table loaded. Active engine: runtime calculation fallback")
            }
        }
        #endif
    }
}
