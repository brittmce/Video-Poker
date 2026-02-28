import Foundation

struct Paytable: Equatable {
    let id: String
    let displayName: String
    let returnPercentageText: String
    let payoutsByName: [String: Int]

    static let selectionStorageKey = "selected_paytable_id"

    static let fullPay96 = Paytable(
        id: "job_9_6_800",
        displayName: "9/6 (Full Pay, 99.54%)",
        returnPercentageText: "99.54%",
        payoutsByName: [
            "Royal Flush": 800,
            "Straight Flush": 50,
            "Four of a Kind": 25,
            "Full House": 9,
            "Flush": 6,
            "Straight": 4,
            "Three of a Kind": 3,
            "Two Pair": 2,
            "Jacks or Better": 1,
            "No Pay": 0
        ]
    )

    static let nineSix500 = Paytable(
        id: "job_9_6_500",
        displayName: "9/6 (98.88%)",
        returnPercentageText: "98.88%",
        payoutsByName: [
            "Royal Flush": 500,
            "Straight Flush": 50,
            "Four of a Kind": 25,
            "Full House": 9,
            "Flush": 6,
            "Straight": 4,
            "Three of a Kind": 3,
            "Two Pair": 2,
            "Jacks or Better": 1,
            "No Pay": 0
        ]
    )

    static let nineFive = Paytable(
        id: "job_9_5",
        displayName: "9/5 (98.45%)",
        returnPercentageText: "98.45%",
        payoutsByName: [
            "Royal Flush": 800,
            "Straight Flush": 50,
            "Four of a Kind": 25,
            "Full House": 9,
            "Flush": 5,
            "Straight": 4,
            "Three of a Kind": 3,
            "Two Pair": 2,
            "Jacks or Better": 1,
            "No Pay": 0
        ]
    )

    static let eightSix = Paytable(
        id: "job_8_6",
        displayName: "8/6 (98.39%)",
        returnPercentageText: "98.39%",
        payoutsByName: [
            "Royal Flush": 800,
            "Straight Flush": 50,
            "Four of a Kind": 25,
            "Full House": 8,
            "Flush": 6,
            "Straight": 4,
            "Three of a Kind": 3,
            "Two Pair": 2,
            "Jacks or Better": 1,
            "No Pay": 0
        ]
    )

    static let eightFive = Paytable(
        id: "job_8_5",
        displayName: "8/5 (97.30%)",
        returnPercentageText: "97.30%",
        payoutsByName: [
            "Royal Flush": 800,
            "Straight Flush": 50,
            "Four of a Kind": 25,
            "Full House": 8,
            "Flush": 5,
            "Straight": 4,
            "Three of a Kind": 3,
            "Two Pair": 2,
            "Jacks or Better": 1,
            "No Pay": 0
        ]
    )

    static let sevenFive = Paytable(
        id: "job_7_5",
        displayName: "7/5 (96.15%)",
        returnPercentageText: "96.15%",
        payoutsByName: [
            "Royal Flush": 800,
            "Straight Flush": 50,
            "Four of a Kind": 25,
            "Full House": 7,
            "Flush": 5,
            "Straight": 4,
            "Three of a Kind": 3,
            "Two Pair": 2,
            "Jacks or Better": 1,
            "No Pay": 0
        ]
    )

    static let sixFive = Paytable(
        id: "job_6_5",
        displayName: "6/5 (95.00%)",
        returnPercentageText: "95.00%",
        payoutsByName: [
            "Royal Flush": 800,
            "Straight Flush": 50,
            "Four of a Kind": 25,
            "Full House": 6,
            "Flush": 5,
            "Straight": 4,
            "Three of a Kind": 3,
            "Two Pair": 2,
            "Jacks or Better": 1,
            "No Pay": 0
        ]
    )

    static let allOptions: [Paytable] = [
        fullPay96,
        nineSix500,
        nineFive,
        eightSix,
        eightFive,
        sevenFive,
        sixFive
    ]

    static let defaultPaytable: Paytable = fullPay96

    static func byID(_ id: String?) -> Paytable {
        guard let id else { return defaultPaytable }
        return allOptions.first(where: { $0.id == id }) ?? defaultPaytable
    }

    var payoutColumn: [Int] {
        [
            payoutsByName["Royal Flush"] ?? 0,
            payoutsByName["Straight Flush"] ?? 0,
            payoutsByName["Four of a Kind"] ?? 0,
            payoutsByName["Full House"] ?? 0,
            payoutsByName["Flush"] ?? 0,
            payoutsByName["Straight"] ?? 0,
            payoutsByName["Three of a Kind"] ?? 0,
            payoutsByName["Two Pair"] ?? 0,
            payoutsByName["Jacks or Better"] ?? 0
        ]
    }

    static let handDisplayOrder: [String] = [
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

    /// Returns payouts for 1,2,3,4,5 coins for a given hand.
    /// Royal Flush uses standard video-poker max-coin behavior.
    func payoutsForCoins(handName: String) -> [Int] {
        if handName == "Royal Flush" {
            let royalPerCoinAtMax = payoutsByName["Royal Flush"] ?? 800
            if royalPerCoinAtMax >= 800 {
                return [250, 500, 750, 1000, 4000]
            } else if royalPerCoinAtMax >= 500 {
                return [250, 500, 750, 1000, 2500]
            } else {
                return [royalPerCoinAtMax, royalPerCoinAtMax * 2, royalPerCoinAtMax * 3, royalPerCoinAtMax * 4, royalPerCoinAtMax * 5]
            }
        }

        let base = payoutsByName[handName] ?? 0
        return [base, base * 2, base * 3, base * 4, base * 5]
    }

    /// Brief guidance on where this paytable is typically found.
    var commonLocationSummary: String {
        switch id {
        case "job_9_6_800":
            return "9/6 Full Pay (800-coin royal) is the premium Jacks or Better schedule. It is now uncommon on high-traffic casino floors and is more often found in selective banks, limit rooms, or promotional setups."
        case "job_9_6_500":
            return "9/6 with a 500-coin max royal keeps strong full house/flush values. This version is often seen where casinos offer better base-game return but cap top-end royal value."
        case "job_9_5":
            return "9/5 is a common floor schedule in major Strip markets and many regional casinos. It balances playable return with higher casino hold versus full-pay games."
        case "job_8_6":
            return "8/6 appears at many off-Strip and regional properties. It is usually positioned as a mid-tier option between 9/5 and lower-pay schedules."
        case "job_8_5":
            return "8/5 is widely used across mainstream casino floors in both tourist and local markets. It is one of the most common modern low-to-mid return Jacks or Better schedules."
        case "job_7_5":
            return "7/5 is commonly found on high-traffic machines, lower denominations, and convenience placements where stronger paytables are limited."
        case "job_6_5":
            return "6/5 is generally a low-return schedule often found in convenience-heavy locations, casual floor placements, or machines aimed at infrequent players."
        default:
            return "Paytable availability varies by market, denomination, and machine placement."
        }
    }
}
