import Foundation

/// Loads and serves optimal-hold lookup records from a precomputed binary file.
///
/// Supported file formats:
/// - Legacy (5 bytes/hand): [holdMask:UInt8][ev:Float32]
/// - Strategy (45 bytes/hand): [handIndex:UInt32][holdMask:UInt8][ev:Float32][wins:UInt32 * 9]
struct PrecomputedLookupTable {
    static let totalHands = 2_598_960
    private static let legacyRecordSize = 5
    private static let strategyRecordSize = 45
    private static let legacyExpectedBytes = totalHands * legacyRecordSize
    private static let strategyExpectedBytes = totalHands * strategyRecordSize

    struct Record {
        let hold: [Bool]
        let expectedValue: Double
        let winningFrequencies: [UInt32]? // Royal ... Jacks or Better
    }

    private enum Format {
        case legacy
        case strategy
    }

    private let data: Data
    private let format: Format
    let loadedResource: String

    init?(resourceName: String? = nil, extension ext: String = "bin") {
        let candidates: [String]
        if let explicit = resourceName {
            candidates = [explicit]
        } else {
            candidates = ["jacks_or_better_9_5_strategy", "jacks_or_better_9_5"]
        }

        var loadedData: Data?
        var loadedFormat: Format?
        var loadedResourceName: String?

        for name in candidates {
            guard let url = Bundle.main.url(forResource: name, withExtension: ext),
                  let bytes = try? Data(contentsOf: url, options: .mappedIfSafe) else {
                continue
            }
            if bytes.count >= Self.strategyExpectedBytes {
                loadedData = bytes
                loadedFormat = .strategy
                loadedResourceName = "\(name).\(ext)"
                break
            }
            if bytes.count >= Self.legacyExpectedBytes {
                loadedData = bytes
                loadedFormat = .legacy
                loadedResourceName = "\(name).\(ext)"
                break
            }
        }

        guard let loadedData, let loadedFormat, let loadedResourceName else {
            return nil
        }

        self.data = loadedData
        self.format = loadedFormat
        self.loadedResource = loadedResourceName
    }

    func lookup(hand: [Card]) -> Record? {
        guard hand.count == 5 else { return nil }
        let indexed = hand.enumerated().map { (originalPos: $0.offset, deckIndex: Self.deckIndex(for: $0.element)) }
        let sortedByDeck = indexed.sorted { $0.deckIndex < $1.deckIndex }
        let sortedDeckIndices = sortedByDeck.map { $0.deckIndex }
        guard let comboIndex = Self.combinationIndex(forSortedDeckIndices: sortedDeckIndices) else {
            return nil
        }
        let sortedToOriginal = sortedByDeck.map { $0.originalPos } // sortedPos -> originalPos

        switch format {
        case .legacy:
            let byteOffset = comboIndex * Self.legacyRecordSize
            guard byteOffset + Self.legacyRecordSize <= data.count else { return nil }
            let holdMask = data[byteOffset]
            let evBits = readUInt32LE(at: byteOffset + 1)
            let ev = Float32(bitPattern: evBits)
            let storedHeld = Self.heldArray(from: holdMask)
            return Record(
                hold: remapHeldToOriginal(storedHeld, sortedToOriginal: sortedToOriginal),
                expectedValue: Double(ev),
                winningFrequencies: nil
            )

        case .strategy:
            let byteOffset = comboIndex * Self.strategyRecordSize
            guard byteOffset + Self.strategyRecordSize <= data.count else { return nil }

            let holdMask = data[byteOffset + 4]
            let evBits = readUInt32LE(at: byteOffset + 5)
            let ev = Float32(bitPattern: evBits)
            var freqs: [UInt32] = []
            freqs.reserveCapacity(9)
            var cursor = byteOffset + 9
            for _ in 0..<9 {
                freqs.append(readUInt32LE(at: cursor))
                cursor += 4
            }
            let storedHeld = Self.heldArray(from: holdMask)
            return Record(
                hold: remapHeldToOriginal(storedHeld, sortedToOriginal: sortedToOriginal),
                expectedValue: Double(ev),
                winningFrequencies: freqs
            )
        }
    }

    nonisolated static func holdMask(from held: [Bool]) -> Int {
        var mask = 0
        for i in 0..<held.count {
            if held[held.count - 1 - i] {
                mask |= (1 << i)
            }
        }
        return mask
    }

    private nonisolated static func heldArray(from mask: UInt8) -> [Bool] {
        var held = Array(repeating: false, count: 5)
        for i in 0..<5 {
            held[4 - i] = (mask & UInt8(1 << i)) != 0
        }
        return held
    }

    /// 0-based deck index used by generator:
    /// suit order: hearts, diamonds, clubs, spades
    /// rank order: two...ace
    private nonisolated static func deckIndex(for card: Card) -> Int {
        let suitBase: Int
        switch card.suit {
        case .hearts: suitBase = 0
        case .diamonds: suitBase = 13
        case .clubs: suitBase = 26
        case .spades: suitBase = 39
        }
        return suitBase + rankOffset(for: card.rank)
    }

    /// Maps a sorted 5-combination of deck indices to the lexicographic rank
    /// used by the generator's nested loops.
    private nonisolated static func combinationIndex(forSortedDeckIndices indices: [Int]) -> Int? {
        guard indices.count == 5 else { return nil }
        guard indices[0] < indices[1],
              indices[1] < indices[2],
              indices[2] < indices[3],
              indices[3] < indices[4] else { return nil }
        guard indices[0] >= 0, indices[4] < 52 else { return nil }

        var rank = 0
        var start = 0
        var remaining = 5

        for p in 0..<5 {
            let current = indices[p]
            if current < start { return nil }
            if current > 51 { return nil }
            if 52 - current < remaining { return nil }

            if current > start {
                for v in start..<current {
                    rank += nChooseK(51 - v, remaining - 1)
                }
            }
            start = current + 1
            remaining -= 1
        }
        return rank
    }

    private nonisolated static func nChooseK(_ n: Int, _ k: Int) -> Int {
        if k < 0 || n < 0 || k > n { return 0 }
        if k == 0 || k == n { return 1 }
        let kk = min(k, n - k)
        var result = 1
        if kk == 0 { return 1 }
        for i in 1...kk {
            result = (result * (n - kk + i)) / i
        }
        return result
    }

    private nonisolated static func rankOffset(for rank: Rank) -> Int {
        switch rank {
        case .two: return 0
        case .three: return 1
        case .four: return 2
        case .five: return 3
        case .six: return 4
        case .seven: return 5
        case .eight: return 6
        case .nine: return 7
        case .ten: return 8
        case .jack: return 9
        case .queen: return 10
        case .king: return 11
        case .ace: return 12
        }
    }

    private func readUInt32LE(at offset: Int) -> UInt32 {
        let b0 = UInt32(data[offset])
        let b1 = UInt32(data[offset + 1]) << 8
        let b2 = UInt32(data[offset + 2]) << 16
        let b3 = UInt32(data[offset + 3]) << 24
        return b0 | b1 | b2 | b3
    }

    private func remapHeldToOriginal(_ storedHeld: [Bool], sortedToOriginal: [Int]) -> [Bool] {
        var originalHeld = Array(repeating: false, count: 5)
        for sortedPos in 0..<min(storedHeld.count, sortedToOriginal.count) {
            originalHeld[sortedToOriginal[sortedPos]] = storedHeld[sortedPos]
        }
        return originalHeld
    }
}
