import Foundation
import Darwin

private let totalHands = 2_598_960
private let strategyRecordSize = 4 + 1 + 4 + (9 * 4) // handIndex + holdMask + EV + 9 frequency counts
private let agnosticRecordSize = 4 + (32 * 10 * 4) // handIndex + (32 holds * 10 outcomes * UInt32)
private let possibilitiesPerCanonicalSolve: Int64 = 2_598_960
private let estimatedCanonicalClasses: Int64 = 134_459
private let estimatedTotalCalculations: Int64 = estimatedCanonicalClasses * possibilitiesPerCanonicalSolve

private let outcomePayouts: [Int] = [800, 50, 25, 9, 5, 4, 3, 2, 1]
private let betMultiplier = 5.0
private struct Config {
    let outputPath: String
    let checkpointPath: String
    let threads: Int
    let checkpointEvery: Int
    let fresh: Bool
    let mode: OutputMode
}

private enum OutputMode: String {
    case strategy
    case agnostic
    case aggregate
}

private struct Checkpoint: Codable {
    let nextHandIndex: Int
    let writtenRecords: Int
    let calculationsDone: Int64?
    let updatedAtUnix: Int64
}

private struct CanonicalResult {
    let canonicalHoldMask: UInt8
    let totalEV: Float32
    let winningFrequencies: [UInt32] // 9 elements, Royal ... Jacks or Better
}

private struct Canonicalization {
    let key: String
    let canonicalHand: [Card]
    let originalIndexForCanonicalPos: [Int] // canonicalPos -> originalPos
}

private struct BatchResult {
    let start: Int
    let count: Int
    let data: Data
}

private struct SubsetAggregate {
    var winningFreq: [UInt32] // 9 elements (Royal...JoB)
}

private enum GenError: Error, CustomStringConvertible {
    case invalidArgs(String)
    case io(String)
    case checkpoint(String)

    var description: String {
        switch self {
        case .invalidArgs(let message): return "Invalid arguments: \(message)"
        case .io(let message): return "I/O error: \(message)"
        case .checkpoint(let message): return "Checkpoint error: \(message)"
        }
    }
}

private final class Locked<T> {
    private var value: T
    private let lock = NSLock()

    init(_ value: T) {
        self.value = value
    }

    func withLock<R>(_ body: (inout T) -> R) -> R {
        lock.lock()
        defer { lock.unlock() }
        return body(&value)
    }
}

private final class CanonicalStore {
    private let lock = NSLock()
    private var cache: [String: CanonicalResult] = [:]

    func result(for key: String) -> CanonicalResult? {
        lock.lock()
        defer { lock.unlock() }
        return cache[key]
    }

    func insert(_ value: CanonicalResult, for key: String) {
        lock.lock()
        cache[key] = value
        lock.unlock()
    }

    func count() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return cache.count
    }
}

private final class CanonicalAgnosticStore {
    private let lock = NSLock()
    private var cache: [String: [[UInt32]]] = [:] // canonicalMask -> 10 frequencies

    func result(for key: String) -> [[UInt32]]? {
        lock.lock()
        defer { lock.unlock() }
        return cache[key]
    }

    func insert(_ value: [[UInt32]], for key: String) {
        lock.lock()
        cache[key] = value
        lock.unlock()
    }

    func count() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return cache.count
    }
}

private final class SubsetAggregateStore {
    private var freqByK: [[UInt32]] = Array(repeating: [], count: 6) // flattened: rank*9 + outcome

    init(choose: [[Int]]) {
        for k in 0...5 {
            let size = choose[52][k]
            freqByK[k] = Array(repeating: 0, count: size * 9)
        }
    }

    func addSubset(indices: [Int], winningIndex: Int?, choose: [[Int]]) {
        let k = indices.count
        let rank = rankSubset(indices: indices, choose: choose)
        if let winningIndex {
            freqByK[k][rank * 9 + winningIndex] &+= 1
        }
    }

    func aggregate(for indices: [Int], choose: [[Int]]) -> SubsetAggregate {
        let k = indices.count
        let rank = rankSubset(indices: indices, choose: choose)
        let base = rank * 9
        let freq = Array(freqByK[k][base..<(base + 9)])
        return SubsetAggregate(winningFreq: freq)
    }

    func flattenedFrequencies(forSubsetSize k: Int) -> [UInt32] {
        return freqByK[k]
    }
}

private var stopRequested: sig_atomic_t = 0
private let suitPermutations: [[Int]] = permutations([0, 1, 2, 3])
private let subsetMasksByLength: [[UInt8]] = {
    var groups = Array(repeating: [UInt8](), count: 6)
    for m in 0..<32 {
        let len = m.nonzeroBitCount
        groups[len].append(UInt8(m))
    }
    return groups
}()

private final class ProgressPrinter {
    private let lock = NSLock()
    private var lastLength = 0

    private func terminalWidth() -> Int {
        var w = winsize()
        if ioctl(STDOUT_FILENO, TIOCGWINSZ, &w) == 0, w.ws_col > 0 {
            return Int(w.ws_col)
        }
        return 120
    }

    private func fitToTerminal(_ line: String) -> String {
        let width = max(20, terminalWidth() - 1)
        if line.count <= width { return line }
        if width <= 3 { return String(line.prefix(width)) }
        return String(line.prefix(width - 3)) + "..."
    }

    func update(_ line: String) {
        lock.lock()
        defer { lock.unlock() }
        let visible = fitToTerminal(line)
        let padding = max(0, lastLength - visible.count)
        let padded = visible + String(repeating: " ", count: padding)
        fputs("\r\(padded)", stdout)
        fflush(stdout)
        lastLength = max(lastLength, visible.count)
    }

    func finishLine() {
        lock.lock()
        defer { lock.unlock() }
        fputs("\n", stdout)
        fflush(stdout)
        lastLength = 0
    }
}

private func defaultThreadCount() -> Int {
    let cores = max(1, ProcessInfo.processInfo.activeProcessorCount)
    let half = max(1, cores / 2)
    return min(4, half)
}

private func parseArgs(_ args: [String]) throws -> Config {
    var outputPath: String?
    var checkpointPath: String?
    var threads = defaultThreadCount()
    var checkpointEvery = 10_000
    var fresh = false
    var mode: OutputMode = .strategy

    var i = 1
    while i < args.count {
        switch args[i] {
        case "--output":
            i += 1
            guard i < args.count else { throw GenError.invalidArgs("--output requires a path") }
            outputPath = args[i]
        case "--checkpoint":
            i += 1
            guard i < args.count else { throw GenError.invalidArgs("--checkpoint requires a path") }
            checkpointPath = args[i]
        case "--threads":
            i += 1
            guard i < args.count, let t = Int(args[i]), t > 0 else {
                throw GenError.invalidArgs("--threads requires a positive integer")
            }
            threads = t
        case "--checkpoint-every":
            i += 1
            guard i < args.count, let n = Int(args[i]), n > 0 else {
                throw GenError.invalidArgs("--checkpoint-every requires a positive integer")
            }
            checkpointEvery = n
        case "--fresh":
            fresh = true
        case "--mode":
            i += 1
            guard i < args.count, let parsed = OutputMode(rawValue: args[i]) else {
                throw GenError.invalidArgs("--mode requires one of: strategy, agnostic, aggregate")
            }
            mode = parsed
        case "--help", "-h":
            printUsageAndExit()
        default:
            throw GenError.invalidArgs("Unknown argument: \(args[i])")
        }
        i += 1
    }

    guard let out = outputPath else {
        throw GenError.invalidArgs("Missing required flag --output [path]")
    }
    guard let checkpoint = checkpointPath else {
        throw GenError.invalidArgs("Missing required flag --checkpoint [path]")
    }

    return Config(
        outputPath: out,
        checkpointPath: checkpoint,
        threads: threads,
        checkpointEvery: checkpointEvery,
        fresh: fresh,
        mode: mode
    )
}

private func printUsageAndExit() -> Never {
    print(
        """
        lookup-gen:
          --output [path]
          --checkpoint [path]
          --threads [number]           Default: min(4, half of available cores)
          --checkpoint-every [number]  Default: 10000
          --fresh                      Start from zero (delete prior output/checkpoint)
          --mode [strategy|agnostic|aggregate]   Default: strategy
        """
    )
    exit(0)
}

private func makeDeck() -> [Card] {
    var cards: [Card] = []
    cards.reserveCapacity(52)
    for suit in Suit.allCases {
        for rank in Rank.allCases {
            cards.append(Card(suit: suit, rank: rank))
        }
    }
    return cards
}

private func saveCheckpoint(path: String, nextHandIndex: Int, writtenRecords: Int, calculationsDone: Int64) throws {
    let cp = Checkpoint(
        nextHandIndex: nextHandIndex,
        writtenRecords: writtenRecords,
        calculationsDone: calculationsDone,
        updatedAtUnix: Int64(Date().timeIntervalSince1970)
    )
    let data = try JSONEncoder().encode(cp)
    try data.write(to: URL(fileURLWithPath: path), options: .atomic)
}

private func loadCheckpoint(path: String) throws -> Checkpoint {
    let url = URL(fileURLWithPath: path)
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(Checkpoint.self, from: data)
}

private func openOutput(path: String, resume: Bool) throws -> FileHandle {
    let fm = FileManager.default
    if !fm.fileExists(atPath: path) {
        fm.createFile(atPath: path, contents: nil)
    }
    guard let handle = FileHandle(forUpdatingAtPath: path) else {
        throw GenError.io("Unable to open output file: \(path)")
    }
    if resume {
        try handle.seekToEnd()
    } else {
        try handle.truncate(atOffset: 0)
        try handle.seek(toOffset: 0)
    }
    return handle
}

private func appendLE<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
    var v = value.littleEndian
    withUnsafeBytes(of: &v) { bytes in
        data.append(contentsOf: bytes)
    }
}

private func appendFloat32LE(_ value: Float32, to data: inout Data) {
    var bits = value.bitPattern.littleEndian
    withUnsafeBytes(of: &bits) { bytes in
        data.append(contentsOf: bytes)
    }
}

private func rankCombination(_ indices: [Int], n: Int = 52, k: Int = 5) -> Int {
    var rank = 0
    var start = 0
    var remaining = k

    for p in 0..<k {
        let current = indices[p]
        if current > start {
            for v in start..<current {
                rank += nChooseK(n - v - 1, remaining - 1)
            }
        }
        start = current + 1
        remaining -= 1
    }
    return rank
}

private func unrankCombination(_ rank: Int, n: Int = 52, k: Int = 5) -> [Int] {
    var rem = rank
    var result: [Int] = []
    result.reserveCapacity(k)
    var start = 0

    for pos in 0..<k {
        let remaining = k - pos
        var chosen = start
        while chosen <= n - remaining {
            let count = nChooseK(n - chosen - 1, remaining - 1)
            if rem < count {
                break
            }
            rem -= count
            chosen += 1
        }
        result.append(chosen)
        start = chosen + 1
    }
    return result
}

private func nChooseK(_ n: Int, _ k: Int) -> Int {
    if k < 0 || n < 0 || k > n { return 0 }
    if k == 0 || k == n { return 1 }
    let kk = min(k, n - k)
    var result = 1
    for i in 1...kk {
        result = (result * (n - kk + i)) / i
    }
    return result
}

private func suitIndex(_ suit: Suit) -> Int {
    switch suit {
    case .hearts: return 0
    case .diamonds: return 1
    case .clubs: return 2
    case .spades: return 3
    }
}

private func suitForIndex(_ index: Int) -> Suit {
    switch index {
    case 0: return .hearts
    case 1: return .diamonds
    case 2: return .clubs
    default: return .spades
    }
}

private func deckIndex(for card: Card) -> Int {
    let suitBase: Int
    switch card.suit {
    case .hearts: suitBase = 0
    case .diamonds: suitBase = 13
    case .clubs: suitBase = 26
    case .spades: suitBase = 39
    }
    return suitBase + (card.rank.value - 2)
}

private func buildChooseTable(maxN: Int, maxK: Int) -> [[Int]] {
    var choose = Array(repeating: Array(repeating: 0, count: maxK + 1), count: maxN + 1)
    for n in 0...maxN {
        choose[n][0] = 1
        if n <= maxK { choose[n][n] = 1 }
    }
    if maxN >= 1 {
        for n in 1...maxN {
            let upperK = min(n - 1, maxK)
            if upperK >= 1 {
                for k in 1...upperK {
                    choose[n][k] = choose[n - 1][k - 1] + choose[n - 1][k]
                }
            }
        }
    }
    return choose
}

private func rankSubset(indices: [Int], choose: [[Int]]) -> Int {
    let k = indices.count
    if k == 0 { return 0 }

    var rank = 0
    var start = 0
    var remaining = k
    for p in 0..<k {
        let current = indices[p]
        if current > start {
            for v in start..<current {
                rank += choose[52 - v - 1][remaining - 1]
            }
        }
        start = current + 1
        remaining -= 1
    }
    return rank
}

private func rankForValue(_ value: Int) -> Rank {
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

private func canonicalize(_ hand: [Card]) -> Canonicalization {
    var bestKey: String?
    var bestHand: [Card] = []
    var bestMapping: [Int] = []

    for perm in suitPermutations {
        var transformed: [(rank: Int, suit: Int, original: Int)] = []
        transformed.reserveCapacity(5)
        for (idx, card) in hand.enumerated() {
            transformed.append((rank: card.rank.value, suit: perm[suitIndex(card.suit)], original: idx))
        }

        transformed.sort {
            if $0.rank != $1.rank { return $0.rank < $1.rank }
            if $0.suit != $1.suit { return $0.suit < $1.suit }
            return $0.original < $1.original
        }

        let key = transformed.map { "\($0.rank)-\($0.suit)" }.joined(separator: "|")
        if bestKey == nil || key < bestKey! {
            bestKey = key
            bestHand = transformed.map { Card(suit: suitForIndex($0.suit), rank: rankForValue($0.rank)) }
            bestMapping = transformed.map { $0.original }
        }
    }

    return Canonicalization(
        key: bestKey ?? "",
        canonicalHand: bestHand,
        originalIndexForCanonicalPos: bestMapping
    )
}

private func holdMask(from held: [Bool]) -> UInt8 {
    var mask = 0
    for i in 0..<held.count {
        if held[held.count - 1 - i] {
            mask |= (1 << i)
        }
    }
    return UInt8(mask)
}

private func heldArray(from mask: UInt8) -> [Bool] {
    var held = Array(repeating: false, count: 5)
    for i in 0..<5 {
        held[4 - i] = (mask & UInt8(1 << i)) != 0
    }
    return held
}

private func remapMaskToOriginal(canonicalMask: UInt8, canonicalToOriginal: [Int]) -> UInt8 {
    let canonicalHeld = heldArray(from: canonicalMask)
    var originalHeld = Array(repeating: false, count: 5)
    for cPos in 0..<5 {
        originalHeld[canonicalToOriginal[cPos]] = canonicalHeld[cPos]
    }
    return holdMask(from: originalHeld)
}

/// Returns index in 9-element winning frequency array (Royal ... JoB), or nil for No Pay.
private func winningIndex(forPayout payout: Int) -> Int? {
    switch payout {
    case 800: return 0
    case 50: return 1
    case 25: return 2
    case 9: return 3
    case 5: return 4
    case 4: return 5
    case 3: return 6
    case 2: return 7
    case 1: return 8
    default: return nil
    }
}

private func solveHandOptimal(_ hand: [Card], deck: [Card]) -> CanonicalResult {
    let handSet = Set(hand)
    let remainingDeck = deck.filter { !handSet.contains($0) } // 47 cards

    var bestMask: UInt8 = 0
    var bestEV: Double = -1.0
    var bestFreq = Array(repeating: UInt32(0), count: 9)

    for mask in 0..<32 {
        let held = heldArray(from: UInt8(mask))
        let heldCards = hand.indices.compactMap { held[$0] ? hand[$0] : nil }
        let drawCount = 5 - heldCards.count

        var frequencies = Array(repeating: UInt32(0), count: 9)
        var totalPayout = 0.0
        let deckCount = remainingDeck.count

        switch drawCount {
        case 0:
            let payout = Hand.evaluateHandForEV(heldCards)
            if let idx = winningIndex(forPayout: payout) {
                frequencies[idx] += 1
            }
            totalPayout = Double(payout) * betMultiplier
        case 1:
            for i in 0..<deckCount {
                let cards = heldCards + [remainingDeck[i]]
                let payout = Hand.evaluateHandForEV(cards)
                if let idx = winningIndex(forPayout: payout) {
                    frequencies[idx] += 1
                }
                totalPayout += Double(payout) * betMultiplier
            }
        case 2:
            var cards = heldCards
            cards.append(contentsOf: [Card](repeating: Card(suit: .hearts, rank: .two), count: 2))
            for i in 0..<deckCount {
                cards[heldCards.count] = remainingDeck[i]
                for j in (i + 1)..<deckCount {
                    cards[heldCards.count + 1] = remainingDeck[j]
                    let payout = Hand.evaluateHandForEV(cards)
                    if let idx = winningIndex(forPayout: payout) {
                        frequencies[idx] += 1
                    }
                    totalPayout += Double(payout) * betMultiplier
                }
            }
        case 3:
            var cards = heldCards
            cards.append(contentsOf: [Card](repeating: Card(suit: .hearts, rank: .two), count: 3))
            for i in 0..<deckCount {
                cards[heldCards.count] = remainingDeck[i]
                for j in (i + 1)..<deckCount {
                    cards[heldCards.count + 1] = remainingDeck[j]
                    for k in (j + 1)..<deckCount {
                        cards[heldCards.count + 2] = remainingDeck[k]
                        let payout = Hand.evaluateHandForEV(cards)
                        if let idx = winningIndex(forPayout: payout) {
                            frequencies[idx] += 1
                        }
                        totalPayout += Double(payout) * betMultiplier
                    }
                }
            }
        case 4:
            var cards = heldCards
            cards.append(contentsOf: [Card](repeating: Card(suit: .hearts, rank: .two), count: 4))
            for i in 0..<deckCount {
                cards[heldCards.count] = remainingDeck[i]
                for j in (i + 1)..<deckCount {
                    cards[heldCards.count + 1] = remainingDeck[j]
                    for k in (j + 1)..<deckCount {
                        cards[heldCards.count + 2] = remainingDeck[k]
                        for l in (k + 1)..<deckCount {
                            cards[heldCards.count + 3] = remainingDeck[l]
                            let payout = Hand.evaluateHandForEV(cards)
                            if let idx = winningIndex(forPayout: payout) {
                                frequencies[idx] += 1
                            }
                            totalPayout += Double(payout) * betMultiplier
                        }
                    }
                }
            }
        default: // drawCount == 5
            for i in 0..<deckCount {
                let c1 = remainingDeck[i]
                for j in (i + 1)..<deckCount {
                    let c2 = remainingDeck[j]
                    for k in (j + 1)..<deckCount {
                        let c3 = remainingDeck[k]
                        for l in (k + 1)..<deckCount {
                            let c4 = remainingDeck[l]
                            for m in (l + 1)..<deckCount {
                                let c5 = remainingDeck[m]
                                let payout = Hand.evaluateHandForEV([c1, c2, c3, c4, c5])
                                if let idx = winningIndex(forPayout: payout) {
                                    frequencies[idx] += 1
                                }
                                totalPayout += Double(payout) * betMultiplier
                            }
                        }
                    }
                }
            }
        }

        let totalCombos = Double(nChooseK(47, drawCount))
        let ev = totalPayout / totalCombos
        if ev > bestEV {
            bestEV = ev
            bestMask = UInt8(mask)
            bestFreq = frequencies
        }
    }

    return CanonicalResult(
        canonicalHoldMask: bestMask,
        totalEV: Float32(bestEV),
        winningFrequencies: bestFreq
    )
}

private func solveHandOptimalWithInclusionExclusion(
    sortedHandIndices: [Int],
    choose: [[Int]],
    subsetStore: SubsetAggregateStore
) -> CanonicalResult {
    var bestMask: UInt8 = 0
    var bestEV: Double = -Double.greatestFiniteMagnitude
    var bestFreq = Array(repeating: UInt32(0), count: 9)

    for mask in 0..<32 {
        let held = heldArray(from: UInt8(mask))
        var heldIndices: [Int] = []
        var discardedIndices: [Int] = []
        heldIndices.reserveCapacity(5)
        discardedIndices.reserveCapacity(5)

        for i in 0..<5 {
            if held[i] {
                heldIndices.append(sortedHandIndices[i])
            } else {
                discardedIndices.append(sortedHandIndices[i])
            }
        }

        let drawCount = discardedIndices.count
        let denominator = choose[47][drawCount]
        if denominator == 0 { continue }

        var freqSigned = Array(repeating: Int64(0), count: 9)
        let dCount = discardedIndices.count
        let subsetLimit = 1 << dCount

        for sub in 0..<subsetLimit {
            var merged: [Int] = []
            merged.reserveCapacity(heldIndices.count + dCount)
            merged.append(contentsOf: heldIndices)

            if dCount > 0 {
                for j in 0..<dCount {
                    if (sub & (1 << j)) != 0 {
                        merged.append(discardedIndices[j])
                    }
                }
            }
            merged.sort()

            let agg = subsetStore.aggregate(for: merged, choose: choose)
            let sign: Int64 = (sub.nonzeroBitCount % 2 == 0) ? 1 : -1
            for i in 0..<9 {
                freqSigned[i] += sign * Int64(agg.winningFreq[i])
            }
        }

        let payouts = outcomePayouts
        var weighted: Int64 = 0
        for i in 0..<9 {
            let c = max(0, freqSigned[i])
            weighted += c * Int64(payouts[i])
        }
        let ev = (Double(weighted) * betMultiplier) / Double(denominator)
        if ev > bestEV {
            bestEV = ev
            bestMask = UInt8(mask)
            for i in 0..<9 {
                bestFreq[i] = UInt32(max(0, freqSigned[i]))
            }
        }
    }

    return CanonicalResult(
        canonicalHoldMask: bestMask,
        totalEV: Float32(bestEV),
        winningFrequencies: bestFreq
    )
}

private func solveAllHoldFrequenciesWithInclusionExclusion(
    sortedHandIndices: [Int],
    choose: [[Int]],
    subsetStore: SubsetAggregateStore
) -> [[UInt32]] {
    var byMask = Array(repeating: Array(repeating: UInt32(0), count: 10), count: 32)

    for mask in 0..<32 {
        let held = heldArray(from: UInt8(mask))
        var heldIndices: [Int] = []
        var discardedIndices: [Int] = []
        heldIndices.reserveCapacity(5)
        discardedIndices.reserveCapacity(5)

        for i in 0..<5 {
            if held[i] {
                heldIndices.append(sortedHandIndices[i])
            } else {
                discardedIndices.append(sortedHandIndices[i])
            }
        }

        let drawCount = discardedIndices.count
        let denominator = choose[47][drawCount]
        if denominator == 0 { continue }

        var freqSigned = Array(repeating: Int64(0), count: 9)
        let dCount = discardedIndices.count
        let subsetLimit = 1 << dCount

        for sub in 0..<subsetLimit {
            var merged: [Int] = []
            merged.reserveCapacity(heldIndices.count + dCount)
            merged.append(contentsOf: heldIndices)
            if dCount > 0 {
                for j in 0..<dCount {
                    if (sub & (1 << j)) != 0 {
                        merged.append(discardedIndices[j])
                    }
                }
            }
            merged.sort()
            let agg = subsetStore.aggregate(for: merged, choose: choose)
            let sign: Int64 = (sub.nonzeroBitCount % 2 == 0) ? 1 : -1
            for i in 0..<9 {
                freqSigned[i] += sign * Int64(agg.winningFreq[i])
            }
        }

        var winsTotal: Int64 = 0
        for i in 0..<9 {
            let value = max(0, freqSigned[i])
            byMask[mask][i] = UInt32(value)
            winsTotal += value
        }
        byMask[mask][9] = UInt32(max(0, Int64(denominator) - winsTotal))
    }

    return byMask
}

private func buildSubsetAggregateStore(deck: [Card], choose: [[Int]], progressEvery: Int = 200_000) -> SubsetAggregateStore {
    let store = SubsetAggregateStore(choose: choose)
    let n = deck.count
    var processed = 0
    let start = Date()
    let progressPrinter = ProgressPrinter()

    for a in 0..<n {
        for b in (a + 1)..<n {
            for c in (b + 1)..<n {
                for d in (c + 1)..<n {
                    for e in (d + 1)..<n {
                        let cards = [deck[a], deck[b], deck[c], deck[d], deck[e]]
                        let payout = Hand.evaluateHandForEV(cards)
                        let winIdx = winningIndex(forPayout: payout)
                        let handIndices = [a, b, c, d, e]

                        for len in 0...5 {
                            for mask in subsetMasksByLength[len] {
                                if len == 0 {
                                    store.addSubset(indices: [], winningIndex: winIdx, choose: choose)
                                    continue
                                }

                                var subset: [Int] = []
                                subset.reserveCapacity(len)
                                for i in 0..<5 {
                                    if (mask & UInt8(1 << i)) != 0 {
                                        subset.append(handIndices[i])
                                    }
                                }
                                store.addSubset(indices: subset, winningIndex: winIdx, choose: choose)
                            }
                        }

                        processed += 1
                        if processed % progressEvery == 0 {
                            let elapsed = Date().timeIntervalSince(start)
                            let rate = elapsed > 0 ? Double(processed) / elapsed : 0
                            let pct = (Double(processed) / Double(totalHands)) * 100.0
                            let remaining = rate > 0 ? Double(totalHands - processed) / rate : 0
                            let line = "Precompute subsets: \(formatWithCommas(Int64(processed))) / \(formatWithCommas(Int64(totalHands))) hands (\(String(format: "%.2f", pct))%), \(formatWithCommas(Int64(max(0, rate.rounded())))) hands/s, \(formatDuration(remaining)) remaining"
                            progressPrinter.update(line)
                        }
                    }
                }
            }
        }
    }

    progressPrinter.finishLine()
    return store
}

private func writeAggregateTable(path: String, subsetStore: SubsetAggregateStore, choose: [[Int]]) throws {
    let url = URL(fileURLWithPath: path)
    var data = Data()
    data.append(contentsOf: Array("VPAGG1\0".utf8)) // 7 bytes + null
    appendLE(UInt32(1), to: &data) // version
    appendLE(UInt32(5), to: &data) // max subset size

    for k in 0...5 {
        let subsetCount = choose[52][k]
        appendLE(UInt32(subsetCount), to: &data)
        let freqs = subsetStore.flattenedFrequencies(forSubsetSize: k)
        data.reserveCapacity(data.count + (freqs.count * 4))
        for f in freqs {
            appendLE(f, to: &data)
        }
    }

    try data.write(to: url, options: .atomic)
}

private func buildBatch(
    start: Int,
    count: Int,
    mode: OutputMode,
    deck: [Card],
    choose: [[Int]],
    subsetStore: SubsetAggregateStore,
    strategyStore: CanonicalStore,
    agnosticStore: CanonicalAgnosticStore,
    calculations: Locked<Int64>
) -> BatchResult {
    let recordSize = (mode == .strategy) ? strategyRecordSize : agnosticRecordSize
    var data = Data(capacity: count * recordSize)
    var calculationsIncrement: Int64 = 0

    for offset in 0..<count {
        let handIndex = start + offset
        let combo = unrankCombination(handIndex)
        let hand = combo.map { deck[$0] }
        let canon = canonicalize(hand)
        appendLE(UInt32(handIndex), to: &data)

        switch mode {
        case .strategy:
            let solved: CanonicalResult
            if let cached = strategyStore.result(for: canon.key) {
                solved = cached
            } else {
                let canonicalIndices = canon.canonicalHand.map(deckIndex(for:)).sorted()
                let computed = solveHandOptimalWithInclusionExclusion(
                    sortedHandIndices: canonicalIndices,
                    choose: choose,
                    subsetStore: subsetStore
                )
                strategyStore.insert(computed, for: canon.key)
                calculationsIncrement += possibilitiesPerCanonicalSolve
                solved = computed
            }

            let maskOriginal = remapMaskToOriginal(
                canonicalMask: solved.canonicalHoldMask,
                canonicalToOriginal: canon.originalIndexForCanonicalPos
            )
            data.append(maskOriginal)
            appendFloat32LE(solved.totalEV, to: &data)
            for freq in solved.winningFrequencies {
                appendLE(freq, to: &data)
            }

        case .agnostic:
            let canonicalAll: [[UInt32]]
            if let cached = agnosticStore.result(for: canon.key) {
                canonicalAll = cached
            } else {
                let canonicalIndices = canon.canonicalHand.map(deckIndex(for:)).sorted()
                let computed = solveAllHoldFrequenciesWithInclusionExclusion(
                    sortedHandIndices: canonicalIndices,
                    choose: choose,
                    subsetStore: subsetStore
                )
                agnosticStore.insert(computed, for: canon.key)
                calculationsIncrement += possibilitiesPerCanonicalSolve
                canonicalAll = computed
            }

            var originalAll = Array(repeating: Array(repeating: UInt32(0), count: 10), count: 32)
            for canonicalMask in 0..<32 {
                let originalMask = Int(
                    remapMaskToOriginal(
                        canonicalMask: UInt8(canonicalMask),
                        canonicalToOriginal: canon.originalIndexForCanonicalPos
                    )
                )
                originalAll[originalMask] = canonicalAll[canonicalMask]
            }

            for mask in 0..<32 {
                for outcome in 0..<10 {
                    appendLE(originalAll[mask][outcome], to: &data)
                }
            }

        case .aggregate:
            break
        }
    }

    if calculationsIncrement > 0 {
        calculations.withLock { $0 += calculationsIncrement }
    }

    return BatchResult(start: start, count: count, data: data)
}

private func runGenerator() throws {
    signal(SIGINT) { _ in stopRequested = 1 }
    signal(SIGTERM) { _ in stopRequested = 1 }

    let config = try parseArgs(CommandLine.arguments)
    let deck = makeDeck()
    let choose = buildChooseTable(maxN: 52, maxK: 5)
    print("Building subset aggregate tables...")
    let subsetStore = buildSubsetAggregateStore(deck: deck, choose: choose)

    if config.mode == .aggregate {
        print("Writing aggregate table...")
        try writeAggregateTable(path: config.outputPath, subsetStore: subsetStore, choose: choose)
        if FileManager.default.fileExists(atPath: config.checkpointPath) {
            try? FileManager.default.removeItem(atPath: config.checkpointPath)
        }
        print("Done. Aggregate table written to \(config.outputPath)")
        return
    }

    let fm = FileManager.default
    let outputDir = (config.outputPath as NSString).deletingLastPathComponent
    let checkpointDir = (config.checkpointPath as NSString).deletingLastPathComponent
    try fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
    try fm.createDirectory(atPath: checkpointDir, withIntermediateDirectories: true)

    if config.fresh {
        if fm.fileExists(atPath: config.checkpointPath) {
            try fm.removeItem(atPath: config.checkpointPath)
        }
        if fm.fileExists(atPath: config.outputPath) {
            try fm.removeItem(atPath: config.outputPath)
        }
    }

    var resume = false
    var startIndex = 0
    var startCalculations: Int64 = 0
    if fm.fileExists(atPath: config.checkpointPath) {
        let cp = try loadCheckpoint(path: config.checkpointPath)
        startIndex = cp.nextHandIndex
        startCalculations = cp.calculationsDone ?? 0
        resume = true
    }

    let handle = try openOutput(path: config.outputPath, resume: resume)
    defer { try? handle.close() }

    if resume {
        print("Resuming from hand index \(startIndex)")
    } else {
        print("Starting new generation")
    }
    print("Mode: \(config.mode.rawValue)")
    print("Threads: \(config.threads)")
    print("Output: \(config.outputPath)")
    print("Checkpoint: \(config.checkpointPath)")
    let assignLock = Locked(startIndex)
    let writtenCount = Locked(startIndex)
    let calculationsDone = Locked(startCalculations)
    let keepPrinting = Locked(true)
    let writeLock = NSLock()
    var nextWrite = startIndex
    var pending: [Int: BatchResult] = [:]
    var nextCheckpoint = ((startIndex / config.checkpointEvery) + 1) * config.checkpointEvery
    let strategyStore = CanonicalStore()
    let agnosticStore = CanonicalAgnosticStore()
    let startTime = Date()
    let progressPrinter = ProgressPrinter()

    let renderProgress: (_ currentCalc: Int64, _ handsDone: Int, _ etaOverride: TimeInterval?) -> Void = { currentCalc, handsDone, etaOverride in
        let pct = totalHands > 0
            ? (Double(handsDone) / Double(totalHands)) * 100.0
            : 0.0
        let elapsed = Date().timeIntervalSince(startTime)
        let handsRate = elapsed > 0 ? (Double(handsDone - startIndex) / elapsed) : 0.0
        let handsRateInt = Int64(max(0, handsRate.rounded()))
        let remainingHands = max(0, totalHands - handsDone)
        let eta = etaOverride ?? (handsRate > 0 ? (Double(remainingHands) / handsRate) : 0)
        let calcRate = elapsed > 0 ? (Double(currentCalc - startCalculations) / elapsed) : 0.0
        let calcRateInt = Int64(max(0, calcRate.rounded()))
        let line = "\(formatWithCommas(Int64(handsDone))) / \(formatWithCommas(Int64(totalHands))) hands complete (\(String(format: "%.2f", pct))%), \(formatWithCommas(handsRateInt)) hands/s, \(formatDuration(elapsed)) elapsed, \(formatDuration(eta)) remaining | \(formatWithCommas(calcRateInt)) calculations/s"
        progressPrinter.update(line)
    }
    renderProgress(startCalculations, startIndex, 0)

    let progressQueue = DispatchQueue(label: "lookup.gen.progress", qos: .utility)
    progressQueue.async {
        while keepPrinting.withLock({ $0 }) {
            Thread.sleep(forTimeInterval: 1.0)
            if !keepPrinting.withLock({ $0 }) { break }
            if stopRequested != 0 { break }
            let currentCalc = calculationsDone.withLock { $0 }
            let handsWritten = writtenCount.withLock { $0 }
            let handsAssigned = assignLock.withLock { $0 }
            let handsDone = max(handsWritten, handsAssigned)
            renderProgress(currentCalc, handsDone, nil)
        }
    }

    let group = DispatchGroup()
    let workerQueue = DispatchQueue(label: "lookup.gen.workers", qos: .userInitiated, attributes: .concurrent)
    // Moderate batch size keeps progress responsive while preserving throughput.
    let batchSize = 64

    for _ in 0..<config.threads {
        group.enter()
        workerQueue.async {
            defer { group.leave() }
            while true {
                if stopRequested != 0 { return }

                let batchStart: Int = assignLock.withLock { next in
                    if next >= totalHands { return -1 }
                    let s = next
                    next += batchSize
                    return s
                }
                if batchStart < 0 { return }

                let count = min(batchSize, totalHands - batchStart)
                let result = buildBatch(
                    start: batchStart,
                    count: count,
                    mode: config.mode,
                    deck: deck,
                    choose: choose,
                    subsetStore: subsetStore,
                    strategyStore: strategyStore,
                    agnosticStore: agnosticStore,
                    calculations: calculationsDone
                )

                writeLock.lock()
                pending[result.start] = result

                while let ready = pending[nextWrite] {
                    do {
                        try handle.write(contentsOf: ready.data)
                    } catch {
                        fputs("\nWrite error: \(error)\n", stderr)
                        stopRequested = 1
                        break
                    }

                    nextWrite += ready.count
                    writtenCount.withLock { $0 = nextWrite }
                    pending.removeValue(forKey: ready.start)

                    if nextWrite >= nextCheckpoint {
                        do {
                            let calcNow = calculationsDone.withLock { $0 }
                            try saveCheckpoint(
                                path: config.checkpointPath,
                                nextHandIndex: nextWrite,
                                writtenRecords: nextWrite,
                                calculationsDone: calcNow
                            )
                        } catch {
                            fputs("\nCheckpoint error: \(error)\n", stderr)
                        }
                        nextCheckpoint += config.checkpointEvery
                    }
                }
                writeLock.unlock()
            }
        }
    }

    group.wait()

    writeLock.lock()
    while let ready = pending[nextWrite] {
        try handle.write(contentsOf: ready.data)
        nextWrite += ready.count
        writtenCount.withLock { $0 = nextWrite }
        pending.removeValue(forKey: ready.start)
    }
    writeLock.unlock()

    if stopRequested != 0 {
        keepPrinting.withLock { $0 = false }
        let calcNow = calculationsDone.withLock { $0 }
        try saveCheckpoint(
            path: config.checkpointPath,
            nextHandIndex: nextWrite,
            writtenRecords: nextWrite,
            calculationsDone: calcNow
        )
        progressPrinter.finishLine()
        print("Stopped. Resume with the same --checkpoint and --output flags.")
        return
    }

    if fm.fileExists(atPath: config.checkpointPath) {
        try fm.removeItem(atPath: config.checkpointPath)
    }

    keepPrinting.withLock { $0 = false }
    let calcNow = calculationsDone.withLock { $0 }
    let handsDone = writtenCount.withLock { $0 }
    let elapsed = Date().timeIntervalSince(startTime)
    renderProgress(calcNow, handsDone, 0)
    progressPrinter.finishLine()
    let solvedCount = (config.mode == .strategy) ? strategyStore.count() : agnosticStore.count()
    print("Done in \(formatDuration(elapsed)). Canonical classes solved: \(solvedCount)")
}

private func formatWithCommas(_ value: Int64) -> String {
    let sign = value < 0 ? "-" : ""
    let digits = String(abs(value))
    if digits.count <= 3 { return sign + digits }

    var out = ""
    out.reserveCapacity(digits.count + (digits.count / 3))
    let chars = Array(digits)
    for i in 0..<chars.count {
        out.append(chars[i])
        let remain = chars.count - i - 1
        if remain > 0 && remain % 3 == 0 {
            out.append(",")
        }
    }
    return sign + out
}

private func formatDuration(_ seconds: TimeInterval) -> String {
    let total = max(0, Int(seconds.rounded()))
    let h = total / 3600
    let m = (total % 3600) / 60
    let s = total % 60
    return String(format: "%02d:%02d:%02d", h, m, s)
}

private func permutations(_ items: [Int]) -> [[Int]] {
    if items.count <= 1 { return [items] }
    var result: [[Int]] = []
    for (i, item) in items.enumerated() {
        var rest = items
        rest.remove(at: i)
        for suffix in permutations(rest) {
            result.append([item] + suffix)
        }
    }
    return result
}

do {
    try runGenerator()
} catch {
    fputs("Error: \(error)\n", stderr)
    exit(1)
}
