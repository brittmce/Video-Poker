import Foundation

/// Paytable-agnostic subset aggregate table.
/// Stores winning outcome frequencies (Royal...JoB) for every subset of size 0...5.
struct SubsetAggregateTable {
    private static let magic = Array("VPAGG1\0".utf8)
    private static let version: UInt32 = 1

    private let choose: [[Int]]
    private let freqsByK: [[UInt32]] // flattened by [subsetRank * 9 + outcomeIndex]

    let loadedResource: String

    init?(resourceName: String = "jacks_or_better_subset_aggregate", extension ext: String = "bin") {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: ext),
              let data = try? Data(contentsOf: url, options: .mappedIfSafe) else {
            return nil
        }

        var cursor = 0
        func readU32() -> UInt32? {
            guard cursor + 4 <= data.count else { return nil }
            let b0 = UInt32(data[cursor])
            let b1 = UInt32(data[cursor + 1]) << 8
            let b2 = UInt32(data[cursor + 2]) << 16
            let b3 = UInt32(data[cursor + 3]) << 24
            cursor += 4
            return b0 | b1 | b2 | b3
        }

        guard data.count >= Self.magic.count + 8 else { return nil }
        let magicBytes = Array(data[0..<Self.magic.count])
        guard magicBytes == Self.magic else { return nil }
        cursor = Self.magic.count

        guard let fileVersion = readU32(), fileVersion == Self.version else { return nil }
        guard let maxK = readU32(), maxK == 5 else { return nil }

        let choose = SubsetAggregateTable.buildChooseTable(maxN: 52, maxK: 5)
        var freqsByK = Array(repeating: [UInt32](), count: 6)

        for k in 0...5 {
            guard let subsetCountU32 = readU32() else { return nil }
            let subsetCount = Int(subsetCountU32)
            guard subsetCount == choose[52][k] else { return nil }

            let valueCount = subsetCount * 9
            var arr = Array(repeating: UInt32(0), count: valueCount)
            for i in 0..<valueCount {
                guard let v = readU32() else { return nil }
                arr[i] = v
            }
            freqsByK[k] = arr
        }

        self.choose = choose
        self.freqsByK = freqsByK
        self.loadedResource = "\(resourceName).\(ext)"
    }

    /// Returns 9 winning outcome counts for a sorted subset of deck indices.
    func aggregateWinningFreq(forSortedIndices indices: [Int]) -> [UInt32] {
        let k = indices.count
        let rank = SubsetAggregateTable.rankSubset(indices: indices, choose: choose)
        let flat = freqsByK[k]
        let base = rank * 9
        return Array(flat[base..<(base + 9)])
    }

    func combinations47Choose(_ k: Int) -> Int {
        choose[47][k]
    }

    static func deckIndex(for card: Card) -> Int {
        let suitBase: Int
        switch card.suit {
        case .hearts: suitBase = 0
        case .diamonds: suitBase = 13
        case .clubs: suitBase = 26
        case .spades: suitBase = 39
        }
        return suitBase + (card.rank.value - 2)
    }

    private static func buildChooseTable(maxN: Int, maxK: Int) -> [[Int]] {
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

    private static func rankSubset(indices: [Int], choose: [[Int]]) -> Int {
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
}

