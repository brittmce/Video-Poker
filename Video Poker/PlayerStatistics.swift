import Foundation
import Combine

/// Tracks player statistics for the video poker strategy trainer
class PlayerStatistics: ObservableObject {
    /// The total number of hands played
    @Published var handsPlayed: Int
    
    /// The number of correct decisions made by the player
    @Published var correctDecisions: Int
    
    /// The total expected value of player choices
    @Published var totalPlayerEV: Double
    
    /// The total expected value of optimal plays
    @Published var totalOptimalEV: Double
    
    /// The total expected value missed by player's suboptimal choices
    @Published var totalMissedEV: Double
    
    /// Creates a new player statistics tracker with default values
    init() {
        self.handsPlayed = 0
        self.correctDecisions = 0
        self.totalPlayerEV = 0.0
        self.totalOptimalEV = 0.0
        self.totalMissedEV = 0.0
    }
    
    /// Creates a player statistics tracker with specified values
    /// - Parameters:
    ///   - handsPlayed: The number of hands played
    ///   - correctDecisions: The number of correct decisions
    ///   - totalPlayerEV: The total expected value of player choices
    ///   - totalOptimalEV: The total expected value of optimal plays
    init(handsPlayed: Int, correctDecisions: Int, totalPlayerEV: Double, totalOptimalEV: Double) {
        self.handsPlayed = handsPlayed
        self.correctDecisions = correctDecisions
        self.totalPlayerEV = totalPlayerEV
        self.totalOptimalEV = totalOptimalEV
        self.totalMissedEV = 0.0
    }
    
    /// Calculates the player's strategy accuracy as a percentage
    /// - Returns: The percentage of correct decisions, or 0 if no hands have been played
    var accuracyPercentage: Double {
        guard handsPlayed > 0 else { return 0.0 }
        return Double(correctDecisions) / Double(handsPlayed) * 100.0
    }
    
    /// Calculates the player's expected value ratio compared to optimal play
    /// - Returns: The ratio of player EV to optimal EV, or 0 if no hands have been played
    var evRatio: Double {
        guard totalOptimalEV > 0 else { return 0.0 }
        return totalPlayerEV / totalOptimalEV
    }
    
    /// Records a new hand result
    /// - Parameters:
    ///   - playerEV: The expected value of the player's choice
    ///   - optimalEV: The expected value of the optimal play
    ///   - isCorrect: Whether the player's decision was correct
    func recordHand(playerEV: Double, optimalEV: Double, isCorrect: Bool) {
        handsPlayed += 1
        totalPlayerEV += playerEV
        totalOptimalEV += optimalEV
        
        if isCorrect {
            correctDecisions += 1
        }
        
        // Calculate and add missed EV (difference between optimal and player EV)
        let missedEV = optimalEV - playerEV
        totalMissedEV += missedEV
    }
    
    /// Resets all statistics to zero
    func reset() {
        handsPlayed = 0
        correctDecisions = 0
        totalPlayerEV = 0.0
        totalOptimalEV = 0.0
        totalMissedEV = 0.0
    }
}