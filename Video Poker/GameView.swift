//
//  GameView.swift
//  Video Poker
//
//  Created by Britt McEachern on 1/20/26.
//

import SwiftUI
import UIKit

/// The main game view that displays the video poker interface
///
/// This view represents the primary interface for the Jacks or Better
/// video poker strategy trainer. It displays the player's hand, allows
/// card selection, shows game statistics, and provides expected value
/// comparisons to help players learn optimal strategy.
///
/// This view has been optimized to show a loading indicator during
/// heavy calculations and disable UI elements to prevent race conditions.
struct GameView: View {
    @Environment(\.dismiss) private var dismiss
    /// The game manager that handles game logic
    @StateObject private var gameManager: GameManager
    @State private var userCardSectionHeight: CGFloat = 140
    @State private var optimalCardSectionHeight: CGFloat = 160
    @State private var isEVExpanded: Bool = false
    @State private var evBreakdownContentHeight: CGFloat = 0
    
    /// Computed property to access game state from game manager
    private var gameState: GameState? {
        gameManager.gameState
    }
    
    /// Computed property to access statistics from game manager
    private var statistics: PlayerStatistics {
        gameManager.statistics
    }

    // Layout constants for EV breakdown grid alignment.
    private let evRowSpacing: CGFloat = 4
    private let evNameToOddsSpacing: CGFloat = 4
    private let evOddsToEVSpacing: CGFloat = 8
    private let evBetweenGroupsSpacing: CGFloat = 12
    private let statisticsHeight: CGFloat = 60
    private let userCardsRowHeight: CGFloat = 140
    private let optimalCardsRowHeight: CGFloat = 140
    private let individualCardPadding: CGFloat = 5
    private let cardGroupPadding: CGFloat = 10
    private let defaultCardAreaHeight: CGFloat = 140
    private let defaultOptimalSectionHeight: CGFloat = 160
    private let outcomeNameColumnWidth: CGFloat = 124
    private let evInfoHeight: CGFloat = 60
    private let evAnchorGap: CGFloat = 10
    private let buttonTopBuffer: CGFloat = 10
    private let actionButtonHeight: CGFloat = 60
    
    /// Computed property to determine if optimal indicators should be shown on current hand
    /// Only show optimal on current hand if:
    /// 1. We're showing optimal strategy AND
    /// 2. We're NOT showing the separate optimal hand display (to avoid redundancy)
    private var shouldShowOptimalOnCurrentHand: Bool {
        guard let gameState = gameState else { return false }
        return gameManager.showOptimalStrategy && !(gameState.stage == .result && !gameManager.isCorrectChoice)
    }

    private var shouldShowEVPanel: Bool {
        guard let gameState = gameState else { return false }
        return gameState.stage == .result
    }

    private var shouldShowOptimalSelection: Bool {
        guard let gameState = gameState else { return false }
        return gameState.stage == .result && !gameManager.isCorrectChoice
    }

    init(mode: PlayMode = .justPlay) {
        _gameManager = StateObject(wrappedValue: GameManager(mode: mode))
    }
    
    var body: some View {
        ZStack {
            Color.green
                .ignoresSafeArea()

            GeometryReader { geometry in
                let expandedMaxHeight = maxExpandedEVHeight(in: geometry)
                let contentWidth = max(240, geometry.size.width - 32)

                VStack(spacing: 0) {
                    cardAreaView(availableWidth: contentWidth)
                        .readHeight { userCardSectionHeight = $0 }

                    Group {
                        if shouldShowOptimalSelection {
                            Color.clear
                                .frame(height: evAnchorGap)
                            originalHandOptimalView(availableWidth: contentWidth)
                                .readHeight { optimalCardSectionHeight = $0 }
                        }
                    }

                    if shouldShowEVPanel {
                        Color.clear
                            .frame(height: evAnchorGap)
                        evPanelView(
                            maxExpandedHeight: expandedMaxHeight,
                            availableWidth: max(220, contentWidth - 32)
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal)
                .disabled(gameManager.isCalculating)
            }

            if gameManager.showFeedback {
                feedbackOverlay
            }

            if gameManager.isCalculating {
                loadingOverlay
            }
        }
        .navigationBarBackButtonHidden(true)
        .safeAreaInset(edge: .top) {
            VStack(spacing: 6) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.3))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }

                statisticsView
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal)
            .padding(.top, 4)
            .padding(.bottom, 0)
        }
        .safeAreaInset(edge: .bottom) {
            actionButton
                .padding(.horizontal)
                .padding(.top, buttonTopBuffer)
                .padding(.bottom, 6)
        }
        .onDisappear {
            gameManager.resetTrainingProgress()
        }
    }

    private func maxExpandedEVHeight(in geometry: GeometryProxy) -> CGFloat {
        let topReserved = geometry.safeAreaInsets.top + 4 + statisticsHeight
        let bottomReserved = actionButtonHeight + buttonTopBuffer + max(6, geometry.safeAreaInsets.bottom)
        let anchorHeight: CGFloat

        if shouldShowOptimalSelection {
            anchorHeight = max(userCardSectionHeight, defaultCardAreaHeight) +
                evAnchorGap +
                max(optimalCardSectionHeight, defaultOptimalSectionHeight) +
                evAnchorGap
        } else {
            anchorHeight = max(userCardSectionHeight, defaultCardAreaHeight) + evAnchorGap
        }

        let available = geometry.size.height - topReserved - bottomReserved - anchorHeight
        return max(evInfoHeight, available)
    }
    
    /// Card area with five card positions
    private func cardAreaView(availableWidth: CGFloat) -> some View {
        let layout = cardRowLayout(
            availableWidth: availableWidth,
            preferredRowHeight: userCardsRowHeight
        )

        return HStack(spacing: layout.spacing) {
            ForEach(0..<5, id: \.self) { index in
                if let gameState = gameState {
                    CardView(
                        card: gameState.currentHand[index],
                        isHeld: gameState.heldCards[index],
                        isOptimallyHeld: shouldShowOptimalOnCurrentHand && gameState.optimalHolds[index],
                        onTap: {
                            handleCardTap(at: index)
                        }
                    )
                    .frame(width: layout.cardWidth, height: layout.cardHeight)
                    .padding(individualCardPadding)
                } else {
                    // Placeholder card view if gameState is not initialized
                    // Show card back when no hand has been dealt yet
                    CardView(
                        card: nil,
                        isHeld: false,
                        isOptimallyHeld: false,
                        onTap: {
                            handleCardTap(at: index)
                        }
                    )
                    .frame(width: layout.cardWidth, height: layout.cardHeight)
                    .padding(individualCardPadding)
                }
            }
        }
        .frame(height: layout.cardHeight + (individualCardPadding * 2))
        .frame(maxWidth: .infinity)
        .padding(cardGroupPadding)
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
    }
    
    /// Card area showing the original hand with optimal selections highlighted
    private func originalHandOptimalView(availableWidth: CGFloat) -> some View {
        let layout = cardRowLayout(
            availableWidth: availableWidth,
            preferredRowHeight: optimalCardsRowHeight
        )

        return VStack(spacing: 0) {  // Remove all spacing between elements
            Text("Optimal Selection")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.vertical, -2)
             
            HStack(spacing: layout.spacing) {
                ForEach(0..<5, id: \.self) { index in
                    if let gameState = gameState {
                        CardView(
                            card: gameState.originalHand[index],
                            isHeld: false, // Original hand cards are never "held" in the traditional sense
                            isOptimallyHeld: gameState.optimalHolds[index], // Show optimal selection
                            onTap: {
                                // No action for original hand cards
                            }
                        )
                        .frame(width: layout.cardWidth, height: layout.cardHeight)
                        .padding(individualCardPadding)
                    }
                }
            }
            .frame(height: layout.cardHeight + (individualCardPadding * 2))
            .frame(maxWidth: .infinity)
        }
        .padding(cardGroupPadding)
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
    }
    
    /// Statistics display area
    private var statisticsView: some View {
        HStack {
            statisticItem(title: "Hands", value: gameManager.handsStatValue)
            Spacer()
            statisticItem(title: "Correct", value: "\(statistics.correctDecisions)")
            Spacer()
            statisticItem(title: "Percent", value: String(format: "%.1f%%", statistics.accuracyPercentage))
            Spacer()
            statisticItem(title: "Missed EV", value: String(format: "%.2f", statistics.totalMissedEV))
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .frame(height: statisticsHeight) // Fixed height to prevent shrinking
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
    
    /// Individual statistic item
    /// - Parameters:
    ///   - title: The title of the statistic
    ///   - value: The value of the statistic
    /// - Returns: A view representing a single statistic item
    private func statisticItem(title: String, value: String) -> some View {
        VStack {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .shadow(color: .black, radius: 1, x: 0, y: 1)
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .shadow(color: .black, radius: 1, x: 0, y: 1)
                .minimumScaleFactor(0.5)
        }
    }
    
    private func evPanelView(maxExpandedHeight: CGFloat, availableWidth: CGFloat) -> some View {
        let combinedItems = getCombinedOutcomeBreakdown()
        let combinedTotals: (userProb: Double, userEV: Double, optimalProb: Double, optimalEV: Double) = {
            guard let gameState = gameState else {
                return (userProb: 0.0, userEV: 0.0, optimalProb: 0.0, optimalEV: 0.0)
            }
            return (
                userProb: 1.0,
                userEV: gameState.playerEV,
                optimalProb: gameManager.isCorrectChoice ? 0.0 : 1.0,
                optimalEV: gameState.optimalEV
            )
        }()
        let evLayout = evTableLayout(
            for: availableWidth,
            items: combinedItems,
            totals: combinedTotals
        )
        let headlineSize = min(32, max(18, evLayout.fontSize + 10))
        let summarySize = min(24, max(14, evLayout.fontSize + 4))
        let headlineFont = Font.system(size: headlineSize, weight: .bold)
        let summaryFont = Font.system(size: summarySize, weight: .semibold)

        return VStack(alignment: .leading, spacing: 6) {
            if let gameState = gameState {
                Text(isEVExpanded ? "Expected Value Breakdown" : "Expected Value")
                    .font(headlineFont)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .center)

                if isEVExpanded {
                    let tableContent = evBreakdownTable(
                        items: combinedItems,
                        totals: combinedTotals,
                        layout: evLayout
                    )
                        .readHeight { evBreakdownContentHeight = $0 }

                    if evBreakdownContentHeight > maxExpandedHeight {
                        ScrollView(.vertical, showsIndicators: true) {
                            tableContent
                        }
                        .frame(maxHeight: maxExpandedHeight)
                    } else {
                        tableContent
                    }

                    HStack {
                        Spacer()
                        expandToggleButton(font: evLayout.font)
                        Spacer()
                    }
                } else {
                    HStack {
                        Text("Optimal Selection")
                            .font(summaryFont)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Your Choice")
                            .font(summaryFont)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    HStack {
                        Text(String(format: "%.2f", gameState.optimalEV))
                            .font(summaryFont)
                            .foregroundColor(.yellow)
                            .monospacedDigit()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(String(format: "%.2f", gameState.playerEV))
                            .font(summaryFont)
                            .foregroundColor(.white)
                            .monospacedDigit()
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    HStack {
                        Spacer()
                        expandToggleButton(font: evLayout.font)
                        Spacer()
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .frame(minHeight: evInfoHeight, alignment: .top)
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }

    private func expandToggleButton(font: Font) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isEVExpanded.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                Text(isEVExpanded ? "Collapse" : "Expand")
                Image(systemName: isEVExpanded ? "chevron.up" : "chevron.down")
            }
            .font(font)
            .fontWeight(.semibold)
            .foregroundColor(.yellow)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.25))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func evBreakdownTable(
        items combinedItems: [CombinedOutcomeData],
        totals combinedTotals: (userProb: Double, userEV: Double, optimalProb: Double, optimalEV: Double),
        layout: EVTableLayout
    ) -> some View {
        let showDualColumns = !gameManager.isCorrectChoice
        let singleColumnLeadingOffset = layout.oddsWidth + evOddsToEVSpacing + layout.evWidth + evBetweenGroupsSpacing

        return VStack(alignment: .leading, spacing: evRowSpacing) {
            if showDualColumns {
                HStack(spacing: 0) {
                    Text("")
                        .frame(width: layout.nameWidth, alignment: .leading)
                    Spacer()
                        .frame(width: evNameToOddsSpacing)
                    Text("Optimal")
                        .font(layout.font)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .frame(width: layout.oddsWidth + evOddsToEVSpacing + layout.evWidth, alignment: .trailing)
                    Spacer()
                        .frame(width: evBetweenGroupsSpacing)
                    Text("Your Choice")
                        .font(layout.font)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .frame(width: layout.oddsWidth + evOddsToEVSpacing + layout.evWidth, alignment: .trailing)
                }
            }

            HStack(spacing: 0) {
                if !showDualColumns {
                    Spacer()
                        .frame(width: singleColumnLeadingOffset)
                }
                Text("")
                    .font(layout.font)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(width: layout.nameWidth, alignment: .leading)
                Spacer()
                    .frame(width: evNameToOddsSpacing)
                Text("Odds")
                    .font(layout.font)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(width: layout.oddsWidth, alignment: .trailing)
                Spacer()
                    .frame(width: evOddsToEVSpacing)
                Text("EV")
                    .font(layout.font)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .frame(width: layout.evWidth, alignment: .trailing)
                if showDualColumns {
                    Spacer()
                        .frame(width: evBetweenGroupsSpacing)
                    Text("Odds")
                        .font(layout.font)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .frame(width: layout.oddsWidth, alignment: .trailing)
                    Spacer()
                        .frame(width: evOddsToEVSpacing)
                    Text("EV")
                        .font(layout.font)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .frame(width: layout.evWidth, alignment: .trailing)
                }
            }

            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(height: 1)

            ForEach(combinedItems, id: \.name) { item in
                HStack(spacing: 0) {
                    if !showDualColumns {
                        Spacer()
                            .frame(width: singleColumnLeadingOffset)
                    }
                    Text(item.name)
                        .font(layout.font)
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .frame(width: layout.nameWidth, alignment: .leading)
                    Spacer()
                        .frame(width: evNameToOddsSpacing)
                    if showDualColumns {
                        Text(String(format: "%.2f%%", item.optimalProbability * 100.0))
                            .font(layout.font)
                            .foregroundColor(.yellow)
                            .monospacedDigit()
                            .lineLimit(1)
                            .frame(width: layout.oddsWidth, alignment: .trailing)
                        Spacer()
                            .frame(width: evOddsToEVSpacing)
                        Text(String(format: "%.2f", item.optimalContribution))
                            .font(layout.font)
                            .foregroundColor(.yellow)
                            .monospacedDigit()
                            .lineLimit(1)
                            .frame(width: layout.evWidth, alignment: .trailing)
                        Spacer()
                            .frame(width: evBetweenGroupsSpacing)
                        Text(String(format: "%.2f%%", item.userProbability * 100.0))
                            .font(layout.font)
                            .foregroundColor(.white)
                            .monospacedDigit()
                            .lineLimit(1)
                            .frame(width: layout.oddsWidth, alignment: .trailing)
                        Spacer()
                            .frame(width: evOddsToEVSpacing)
                        Text(String(format: "%.2f", item.userContribution))
                            .font(layout.font)
                            .foregroundColor(.white)
                            .monospacedDigit()
                            .lineLimit(1)
                            .frame(width: layout.evWidth, alignment: .trailing)
                    } else {
                        Text(String(format: "%.2f%%", item.userProbability * 100.0))
                            .font(layout.font)
                            .foregroundColor(.white)
                            .monospacedDigit()
                            .lineLimit(1)
                            .frame(width: layout.oddsWidth, alignment: .trailing)
                        Spacer()
                            .frame(width: evOddsToEVSpacing)
                        Text(String(format: "%.2f", item.userContribution))
                            .font(layout.font)
                            .foregroundColor(.white)
                            .monospacedDigit()
                            .lineLimit(1)
                            .frame(width: layout.evWidth, alignment: .trailing)
                    }
                }
            }

            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(height: 1)

            HStack(spacing: 0) {
                if !showDualColumns {
                    Spacer()
                        .frame(width: singleColumnLeadingOffset)
                }
                Text("Totals")
                    .font(layout.font)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(width: layout.nameWidth, alignment: .leading)
                Spacer()
                    .frame(width: evNameToOddsSpacing)
                if showDualColumns {
                    Text(String(format: "%.0f%%", combinedTotals.optimalProb * 100.0))
                        .font(layout.font)
                        .fontWeight(.medium)
                        .foregroundColor(.yellow)
                        .monospacedDigit()
                        .lineLimit(1)
                        .frame(width: layout.oddsWidth, alignment: .trailing)
                    Spacer()
                        .frame(width: evOddsToEVSpacing)
                    Text(String(format: "%.2f", combinedTotals.optimalEV))
                        .font(layout.font)
                        .fontWeight(.medium)
                        .foregroundColor(.yellow)
                        .monospacedDigit()
                        .lineLimit(1)
                        .frame(width: layout.evWidth, alignment: .trailing)
                    Spacer()
                        .frame(width: evBetweenGroupsSpacing)
                    Text(String(format: "%.0f%%", combinedTotals.userProb * 100.0))
                        .font(layout.font)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .monospacedDigit()
                        .lineLimit(1)
                        .frame(width: layout.oddsWidth, alignment: .trailing)
                    Spacer()
                        .frame(width: evOddsToEVSpacing)
                    Text(String(format: "%.2f", combinedTotals.userEV))
                        .font(layout.font)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .monospacedDigit()
                        .lineLimit(1)
                        .frame(width: layout.evWidth, alignment: .trailing)
                } else {
                    Text(String(format: "%.0f%%", combinedTotals.userProb * 100.0))
                        .font(layout.font)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .monospacedDigit()
                        .lineLimit(1)
                        .frame(width: layout.oddsWidth, alignment: .trailing)
                    Spacer()
                        .frame(width: evOddsToEVSpacing)
                    Text(String(format: "%.2f", combinedTotals.userEV))
                        .font(layout.font)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .monospacedDigit()
                        .lineLimit(1)
                        .frame(width: layout.evWidth, alignment: .trailing)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    /// Action button that changes based on game state
    private var actionButton: some View {
        Button(action: handleActionButtonTap) {
            Text(buttonText)
                .font(.title2)
                .fontWeight(.black)
                .foregroundColor(.white)
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
                .background(buttonBackgroundColor)
                .cornerRadius(12)
                .shadow(color: .black, radius: 3, x: 0, y: 3)
        }
        .disabled(isButtonDisabled)
        .opacity(isButtonDisabled ? 0.6 : 1.0)
        .frame(height: actionButtonHeight) // Fixed height to maintain consistent positioning
    }
    
    /// Computed property for button text based on game state
    private var buttonText: String {
        // If no hand has been dealt yet, show "Deal"
        guard let gameState = gameState else {
            return "Deal"
        }

        // If we're showing the result, allow dealing a new hand
        if gameState.stage == .result {
            return "Deal"
        }

        // Otherwise, after a hand exists show "Draw" so the user can draw
        return "Draw"
    }
    
    /// Computed property for button background color based on game state
    private var buttonBackgroundColor: Color {
        // If no hand has been dealt yet, use blue for "Deal"
        guard let gameState = gameState else {
            return Color.blue
        }
        
        // Otherwise, use blue for "Deal" and orange for "Draw"
        return gameState.stage == .deal ? Color.blue : Color.orange
    }
    
    /// Computed property for button disabled state
    private var isButtonDisabled: Bool {
        // The action button should only be disabled when calculations are in progress.
        // Allow the user to Draw even when no cards are held (to replace all cards).
        return false
    }
    
    /// Feedback overlay for correct/wrong choices
    private var feedbackOverlay: some View {
        GeometryReader { geometry in
            VStack {
                HStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: gameManager.isCorrectChoice ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(gameManager.isCorrectChoice ? "Correct Choice" : "Not Optimal")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        Capsule()
                            .fill(gameManager.isCorrectChoice ? Color.green : Color.red)
                    )
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 4)
                }
                .padding(.horizontal, 24)
                .padding(.top, geometry.safeAreaInsets.top + statisticsHeight + 18)
                Spacer()
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .allowsHitTesting(false)
            .animation(.spring(response: 0.28, dampingFraction: 0.9), value: gameManager.showFeedback)
        }
    }
    
    /// Loading overlay with spinner
    private var loadingOverlay: some View {
        GeometryReader { geometry in
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(2)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        
                        Text("Calculating...")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .padding(30)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(15)
                    Spacer()
                }
                Spacer()
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
    
    /// Handle card tap gesture
    /// - Parameter index: The index of the card that was tapped
    private func handleCardTap(at index: Int) {
        gameManager.toggleHold(for: index)
    }
    
    /// Handle action button tap
    private func handleActionButtonTap() {
        // If no hand has been dealt yet, start a new hand
        if gameState == nil {
            isEVExpanded = false
            gameManager.showFeedback = false
            gameManager.showOptimalStrategy = false
            gameManager.startNewHand()
            return
        }
        
        // Otherwise, handle the action based on current stage
        if gameState?.stage == .result {
            isEVExpanded = false
            gameManager.showFeedback = false
            gameManager.showOptimalStrategy = false
        }
        gameManager.handleActionButtonPress()
    }
    
    /// Struct to hold combined outcome data for side-by-side display
    private struct CombinedOutcomeData: Identifiable {
        let id = UUID()
        let name: String
        let userProbability: Double
        let userContribution: Double
        let optimalProbability: Double
        let optimalContribution: Double
    }

    private struct EVTableLayout {
        let fontSize: CGFloat
        let nameWidth: CGFloat
        let oddsWidth: CGFloat
        let evWidth: CGFloat

        var font: Font {
            .system(size: fontSize, weight: .regular)
        }
    }

    private struct CardRowLayout {
        let spacing: CGFloat
        let cardWidth: CGFloat
        let cardHeight: CGFloat
    }

    private func cardRowLayout(availableWidth: CGFloat, preferredRowHeight: CGFloat) -> CardRowLayout {
        let innerWidth = max(180, availableWidth - (cardGroupPadding * 2))
        let usableCardWidth = max(120, innerWidth - ((individualCardPadding * 2) * 5))
        let preferredCardWidth = preferredRowHeight * (2.0 / 3.0)
        let minSpacing: CGFloat = 2
        let maxSpacing: CGFloat = 10

        let tentativeSpacing = (usableCardWidth - (preferredCardWidth * 5.0)) / 4.0
        let spacing = min(maxSpacing, max(minSpacing, tentativeSpacing))
        let fittedWidth = floor((usableCardWidth - (spacing * 4.0)) / 5.0)
        let cardWidth = max(40, min(preferredCardWidth, fittedWidth))
        let cardHeight = cardWidth * 1.5

        return CardRowLayout(spacing: spacing, cardWidth: cardWidth, cardHeight: cardHeight)
    }

    private func evTableLayout(
        for availableWidth: CGFloat,
        items: [CombinedOutcomeData],
        totals: (userProb: Double, userEV: Double, optimalProb: Double, optimalEV: Double)
    ) -> EVTableLayout {
        let horizontalGaps = evNameToOddsSpacing + evOddsToEVSpacing + evBetweenGroupsSpacing + evOddsToEVSpacing
        let usableWidth = max(220, availableWidth - 2)
        let maxFont: CGFloat = 37
        let minFont: CGFloat = 6
        let step: CGFloat = 0.5

        var selected = EVTableLayout(fontSize: minFont, nameWidth: 120, oddsWidth: 56, evWidth: 40)
        var fontSize = maxFont

        while fontSize >= minFont {
            let regular = UIFont.systemFont(ofSize: fontSize, weight: .regular)
            let medium = UIFont.systemFont(ofSize: fontSize, weight: .medium)
            let semibold = UIFont.systemFont(ofSize: fontSize, weight: .semibold)
            let regularMono = UIFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .regular)
            let mediumMono = UIFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .medium)

            var maxName = max(
                textWidth("EV Breakdown:", font: medium),
                textWidth("Totals", font: medium)
            )

            for item in items {
                maxName = max(maxName, textWidth(item.name, font: regular))
            }

            let oddsStrings = items.flatMap {
                [String(format: "%.2f%%", $0.optimalProbability * 100.0),
                 String(format: "%.2f%%", $0.userProbability * 100.0)]
            } + [
                "Odds",
                String(format: "%.0f%%", totals.optimalProb * 100.0),
                String(format: "%.0f%%", totals.userProb * 100.0)
            ]

            let evStrings = items.flatMap {
                [String(format: "%.2f", $0.optimalContribution),
                 String(format: "%.2f", $0.userContribution)]
            } + [
                "EV",
                String(format: "%.2f", totals.optimalEV),
                String(format: "%.2f", totals.userEV)
            ]

            var maxOdds = oddsStrings.map { textWidth($0, font: regularMono) }.max() ?? 0
            var maxEV = evStrings.map { textWidth($0, font: mediumMono) }.max() ?? 0

            // Group headers must fully fit and remain right-aligned over EV columns.
            let yourChoiceWidth = textWidth("Your Choice", font: semibold)
            let optimalWidth = textWidth("Optimal", font: semibold)
            let groupSpan = max(maxOdds + evOddsToEVSpacing + maxEV, yourChoiceWidth, optimalWidth)
            if maxOdds + evOddsToEVSpacing + maxEV < groupSpan {
                maxOdds += groupSpan - (maxOdds + evOddsToEVSpacing + maxEV)
            }

            // Breathing room to avoid clipping/truncation at exact-fit boundaries.
            maxName += 4
            maxOdds += 8
            maxEV += 10

            let total = maxName + maxOdds + maxEV + maxOdds + maxEV + horizontalGaps
            if total <= usableWidth {
                selected = EVTableLayout(
                    fontSize: fontSize,
                    nameWidth: maxName,
                    oddsWidth: maxOdds,
                    evWidth: maxEV
                )
                break
            }

            fontSize -= step
        }

        return selected
    }

    private func textWidth(_ text: String, font: UIFont) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: font]).width
    }
    
    /// Combines user and optimal outcome breakdowns for side-by-side display
    /// - Returns: Array of CombinedOutcomeData sorted by hand rank
    private func getCombinedOutcomeBreakdown() -> [CombinedOutcomeData] {
        guard let gameState = gameState else { return [] }
        
        // Get user's breakdown (already computed)
        let userBreakdown = gameState.outcomeBreakdown
        
        // Optimal breakdown is computed in the background and cached in game state
        let optimalBreakdown = gameState.optimalOutcomeBreakdown
        
        // Combine the breakdowns
        let handOrder: [String: Int] = [
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
        
        // Create a set of all unique outcome names
        let allNames = Set(userBreakdown.map { $0.name } + optimalBreakdown.map { $0.name })
        
        // Create combined data
        var combined: [CombinedOutcomeData] = []
        for name in allNames.sorted(by: { handOrder[$0] ?? Int.max < handOrder[$1] ?? Int.max }) {
            let userItem = userBreakdown.first { $0.name == name }
            let optimalItem = optimalBreakdown.first { $0.name == name }
            let userProb = userItem?.probability ?? 0.0
            let optimalProb = optimalItem?.probability ?? 0.0
            if userProb > 0.0 || optimalProb > 0.0 {
                combined.append(CombinedOutcomeData(
                    name: name,
                    userProbability: userProb,
                    userContribution: userItem?.contribution ?? 0.0,
                    optimalProbability: optimalProb,
                    optimalContribution: optimalItem?.contribution ?? 0.0
                ))
            }
        }
        
        return combined
    }
}

private struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private extension View {
    func readHeight(_ onChange: @escaping (CGFloat) -> Void) -> some View {
        background(
            GeometryReader { geometry in
                Color.clear
                    .preference(key: HeightPreferenceKey.self, value: geometry.size.height)
            }
        )
        .onPreferenceChange(HeightPreferenceKey.self, perform: onChange)
    }
}

// MARK: - Previews

#Preview {
    GameView()
}
