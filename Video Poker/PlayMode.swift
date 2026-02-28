import Foundation

enum TrainingDifficulty: String, CaseIterable, Identifiable {
    case beginner
    case intermediate
    case advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        }
    }

    var subtitle: String {
        switch self {
        case .beginner:
            return "Basic strategy patterns and obvious holds."
        case .intermediate:
            return "Hands with two plausible choices."
        case .advanced:
            return "Subtle, high-skill strategy decisions."
        }
    }
}

enum PlayMode {
    case justPlay
    case training(TrainingDifficulty)
}

